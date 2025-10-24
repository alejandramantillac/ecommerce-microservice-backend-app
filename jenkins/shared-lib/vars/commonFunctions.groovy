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
    def buildStages = [:]
    def serviceList = changedServices.split(',')
    
    for (serviceName in serviceList) {
        def service = serviceName.trim()
        buildStages["Build ${service}"] = {
            buildService(service, registry, imageTag, latestTag)
        }
    }
    
    parallel buildStages
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
    
    // Deploy core services first (in order)
    def coreServices = commonVars.getCoreServices()
    for (service in coreServices) {
        if (changedServices.contains(service.name)) {
            deployService(service, environment, namespace, registry, imageTag)
        }
    }

    // Then deploy monitoring services
    def monitoringServices = commonVars.getMonitoringServices()
    for (service in monitoringServices) {
        if (changedServices.contains(service.name)) {
            deployService(service, environment, namespace, registry, imageTag)
        }
    }
    
    // Finally deploy business services in parallel
    def businessServices = commonVars.getBusinessServices()
    def businessDeployStages = [:]
    businessServices.each { service ->
        if (changedServices.contains(service.name)) {
            businessDeployStages["Deploy ${service.name}"] = {
                deployService(service, environment, namespace, registry, imageTag)
            }
        }
    }
    parallel businessDeployStages
    
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