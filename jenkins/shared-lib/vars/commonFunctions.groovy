#!/usr/bin/env groovy

/**
 * Shared functions for Jenkins pipelines
 */

def initializePipelineVariables() {
    env.DEPLOY_TIMESTAMP = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
    env.GIT_COMMIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
    env.GIT_BRANCH = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
}

def generateImageTag(branch, commit, suffix = '') {
    def sanitizedBranch = branch.replaceAll('/', '-').replaceAll('[^a-zA-Z0-9._-]', '_')
    def tag = "${sanitizedBranch}-${commit}"
    return suffix ? "${tag}-${suffix}" : tag
}

def printDeploymentInfo(environment, imageTag, namespace = null) {
    echo "========================================="
    echo "Deployment Configuration"
    echo "========================================="
    echo "Environment: ${environment}"
    echo "Image Tag: ${imageTag}"
    if (namespace) {
        echo "Namespace: ${namespace}"
    }
    echo "Branch: ${env.GIT_BRANCH}"
    echo "Commit: ${env.GIT_COMMIT_SHORT}"
    echo "Timestamp: ${env.DEPLOY_TIMESTAMP}"
    echo "========================================="
}

def detectChangedServices(services) {
    // Build service list as comma-separated paths
    def servicePaths = services.collect { it.path ?: it.name }.join(',')
    
    // Use the shell script to detect changes
    def changedServicesList = sh(
        script: """
            chmod +x jenkins/scripts/detect-changes.sh
            jenkins/scripts/detect-changes.sh "${servicePaths}"
        """,
        returnStdout: true
    ).trim()
    
    echo "Changed services detected: ${changedServicesList}"
    return changedServicesList
}

def buildServicesInParallel(changedServices, registry, imageTag, latestTag) {
    def commonVars = load 'jenkins/shared-lib/vars/commonVars.groovy'
    def buildStages = [:]
    def serviceList = changedServices.split(',')
    
    for (serviceName in serviceList) {
        def service = serviceName.trim()
        def serviceConfig = commonVars.getServiceConfig(service)
        
        // Skip external services (like zipkin)
        if (serviceConfig?.external) {
            echo "Skipping build for external service: ${service}"
            continue
        }
        
        buildStages["Build ${service}"] = {
            buildService(service, registry, imageTag, latestTag)
        }
    }
    
    if (!buildStages.isEmpty()) {
        parallel buildStages
    } else {
        echo "No services to build (all are external)"
    }
}

def buildService(serviceName, registry, imageTag, latestTag) {
    echo "Building ${serviceName}..."
    
    sh """
        chmod +x jenkins/scripts/build-service.sh
        jenkins/scripts/build-service.sh "${serviceName}" "${registry}" "${imageTag}" "${latestTag}"
    """
}

def pushDockerImages(registry, imageTag, latestTag, changedServices, dockerUser, dockerPass) {
    sh """
        chmod +x jenkins/scripts/push-images.sh
        jenkins/scripts/push-images.sh "${registry}" "${imageTag}" "${latestTag}" "${changedServices}" "${dockerUser}" "${dockerPass}"
    """
}

def deployToKubernetes(environment, namespace, registry, imageTag, changedServices) {
    def commonVars = load 'jenkins/shared-lib/vars/commonVars.groovy'
    def allServices = commonVars.getServicesList()
    
    echo "========================================="
    echo "Deploying services to ${environment}"
    echo "Namespace: ${namespace}"
    echo "========================================="
    
    // PASO 1: Apply ConfigMap first (services depend on it)
    echo "Step 1: Applying ConfigMap for ${environment}..."
    applyConfigMap(environment, namespace)
    
    // PASO 2: Deploy core services (in order)
    echo "Step 2: Deploying core services..."
    def coreServices = commonVars.getCoreServices()
    for (service in coreServices) {
        if (changedServices.contains(service.name)) {
            deployService(service, environment, namespace, registry, imageTag)
        }
    }

    // PASO 3: Deploy monitoring services
    echo "Step 3: Deploying monitoring services..."
    def monitoringServices = commonVars.getMonitoringServices()
    for (service in monitoringServices) {
        if (changedServices.contains(service.name)) {
            deployService(service, environment, namespace, registry, imageTag)
        }
    }
    
    // PASO 4: Deploy business services in parallel
    echo "Step 4: Deploying business services..."
    def businessServices = commonVars.getBusinessServices()
    def businessDeployStages = [:]
    businessServices.each { service ->
        if (changedServices.contains(service.name)) {
            businessDeployStages["Deploy ${service.name}"] = {
                deployService(service, environment, namespace, registry, imageTag)
            }
        }
    }
    
    if (!businessDeployStages.isEmpty()) {
        parallel businessDeployStages
    }
}

def applyConfigMap(environment, namespace) {
    def configMapFile = "k8s/02-configmap-${environment}.yaml"
    
    echo "Applying ConfigMap from: ${configMapFile}"
    
    sh """
        if [ -f "${configMapFile}" ]; then
            kubectl --kubeconfig="\${KCFG}" apply -f "${configMapFile}"
            echo "✓ ConfigMap applied successfully for ${environment}"
        else
            echo "⚠ Warning: ConfigMap file not found: ${configMapFile}"
            echo "Services may fail if they depend on ConfigMap values"
        fi
    """
}

def deployService(serviceConfig, environment, namespace, registry, imageTag) {
    def serviceName = serviceConfig.name
    def serviceConfigJson = groovy.json.JsonOutput.toJson(serviceConfig)
    
    echo "Deploying ${serviceName} to ${environment}..."
    
    sh """
        chmod +x jenkins/scripts/deploy-service.sh
        export KCFG="\${KCFG}"
        jenkins/scripts/deploy-service.sh \
            "${serviceName}" \
            "${namespace}" \
            "${registry}" \
            "${imageTag}" \
            "${environment}" \
            '${serviceConfigJson}'
    """
}

def getLoadBalancerIP(serviceName, namespace) {
    def ip = sh(
        script: """
            kubectl get svc ${serviceName} -n ${namespace} \
            --kubeconfig=\${KCFG} \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
        """,
        returnStdout: true
    ).trim()
    return ip
}

def runAllTests(namespace) {
    def stagingGatewayIP = getLoadBalancerIP('api-gateway', 'staging')
    def apiGatewayUrl = "http://${stagingGatewayIP}:8080"

    def testStages = [
        'Integration Tests': {
            runIntegrationTests(namespace, apiGatewayUrl)
        },
        'E2E Tests': {
            runE2ETests(namespace, apiGatewayUrl)
        },
        'Performance Tests': {
            runPerformanceTests(namespace, apiGatewayUrl)
        }
    ]

    parallel testStages
}

def runIntegrationTests(namespace, apiGatewayUrl) {
    sh """
        chmod +x jenkins/scripts/integration-tests.sh
        export KCFG="\${KCFG}"
        jenkins/scripts/integration-tests.sh "${namespace}" "${apiGatewayUrl}"
    """
}

def runE2ETests(namespace, apiGatewayUrl) {
    sh """
        chmod +x jenkins/scripts/e2e-tests.sh
        export KCFG="\${KCFG}"
        jenkins/scripts/e2e-tests.sh "${namespace}" "${apiGatewayUrl}"
    """
}

def runPerformanceTests(namespace, apiGatewayUrl, users = '50', spawnRate = '10', runTime = '300s') {
    sh """
        chmod +x jenkins/scripts/performance-tests.sh
        export KCFG="\${KCFG}"
        jenkins/scripts/performance-tests.sh "${namespace}" "${apiGatewayUrl}" "${users}" "${spawnRate}" "${runTime}"
    """
    
    archiveArtifacts artifacts: 'performance_report.html,performance_data*.csv', 
                     fingerprint: true, 
                     allowEmptyArchive: true
}

def publishAllTestResults(changedServices) {
    def serviceList = changedServices.split(',')
    
    for (serviceName in serviceList) {
        def service = serviceName.trim()
        def testResults = "${service}/target/surefire-reports/*.xml"
        if (fileExists("${service}/target/surefire-reports")) {
            junit testResults: testResults, allowEmptyResults: true
        }
    }
}

def notifySuccess(environment, services) {
    echo "========================================="
    echo "✓ ${environment.toUpperCase()} pipeline completed successfully"
    echo "Services: ${services}"
    echo "========================================="
}

def notifyFailure(environment, services) {
    echo "========================================="
    echo "✗ ${environment.toUpperCase()} pipeline failed"
    echo "Failed services: ${services}"
    echo "Check logs for details"
    echo "========================================="
}

return this