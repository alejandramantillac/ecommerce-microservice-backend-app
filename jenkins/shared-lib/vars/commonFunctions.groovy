#!/usr/bin/env groovy

import groovy.json.JsonOutput

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
    
    // PASO 0: Ensure namespace exists before applying resources
    ensureNamespace(namespace)

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

def ensureNamespace(namespace) {
    sh """
        kubectl --kubeconfig="\${KCFG}" get ns ${namespace} >/dev/null 2>&1 || \
        kubectl --kubeconfig="\${KCFG}" create namespace ${namespace}
    """
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

def getAndConfigureKubeConfigFromTerraform(envNamespace, armClientId, armClientSecret, armTenantId) {
    withCredentials([
        string(credentialsId: 'ARM_CLIENT_ID', variable: 'ARM_CLIENT_ID'),
        string(credentialsId: 'ARM_CLIENT_SECRET', variable: 'ARM_CLIENT_SECRET'),
        string(credentialsId: 'ARM_SUBSCRIPTION_ID', variable: 'ARM_SUBSCRIPTION_ID'),
        string(credentialsId: 'ARM_TENANT_ID', variable: 'ARM_TENANT_ID')
    ]) {
        sh """
            set -e
            mkdir -p \${WORKSPACE}/.kube
            cd infra/terraform/environments/${envNamespace}
            terraform init -input=false >/dev/null
            RG_NAME=\$(terraform output -raw resource_group_name)
            AKS_NAME=\$(terraform output -raw aks_cluster_name)
            az login --service-principal -u "\$ARM_CLIENT_ID" -p "\$ARM_CLIENT_SECRET" --tenant "\$ARM_TENANT_ID" >/dev/null
            az aks get-credentials --resource-group "\$RG_NAME" --name "\$AKS_NAME" --file "\${WORKSPACE}/.kube/security-${envNamespace}" --overwrite-existing
        """
    }
    return "${env.WORKSPACE}/.kube/security-${envNamespace}"
}

def collectPodImages(namespace, kubeconfigPath, reportDir) {
    def imageListFile = "${reportDir}/images.txt"
    withEnv([
        "SECURITY_NAMESPACE=${namespace}",
        "SECURITY_KUBECONFIG=${kubeconfigPath}",
        "SECURITY_REPORT_DIR=${reportDir}",
        "SECURITY_IMAGE_LIST=${imageListFile}"
    ]) {
        sh '''
            set -e
            mkdir -p "${SECURITY_REPORT_DIR}"
            kubectl --kubeconfig="${SECURITY_KUBECONFIG}" get pods -n "${SECURITY_NAMESPACE}" -o jsonpath='{..image}' \
                | tr ' ' '\n' | sort -u | grep -v '^$' > "${SECURITY_IMAGE_LIST}"

            if [ ! -s "${SECURITY_IMAGE_LIST}" ]; then
                echo "No images found in ${SECURITY_NAMESPACE} namespace." >&2
                exit 1
            fi
        '''
    }
    return imageListFile
}


def deployService(serviceConfig, environment, namespace, registry, imageTag) {
    def serviceName = serviceConfig.name
    def serviceConfigJson = JsonOutput.toJson(serviceConfig)
    
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
        chmod +x jenkins/tests/integration-tests.sh
        export KCFG="\${KCFG}"
        jenkins/tests/integration-tests.sh "${namespace}" "${apiGatewayUrl}"
    """
}

def runE2ETests(namespace, apiGatewayUrl) {
    sh """
        chmod +x jenkins/tests/e2e-tests.sh
        export KCFG="\${KCFG}"
        jenkins/tests/e2e-tests.sh "${namespace}" "${apiGatewayUrl}"
    """
}

def runPerformanceTests(namespace, apiGatewayUrl, users = '50', spawnRate = '10', runTime = '300s') {
    sh """
        chmod +x jenkins/tests/performance-tests.sh
        export KCFG="\${KCFG}"
        jenkins/tests/performance-tests.sh "${namespace}" "${apiGatewayUrl}" "${users}" "${spawnRate}" "${runTime}"
    """
    
    archiveArtifacts artifacts: 'performance-report.html,performance-data*.csv', 
                     fingerprint: true, 
                     allowEmptyArchive: true
}

def generateAndPublishRelease(releaseVersion, githubToken) {
    sh """
        chmod +x jenkins/scripts/generate-release-notes.sh
        export IMAGE_TAG="${env.IMAGE_TAG}"
        export K8S_NAMESPACE_PROD="${env.K8S_NAMESPACE_PROD}"
        export REGISTRY="${env.REGISTRY}"
        jenkins/scripts/generate-release-notes.sh "${releaseVersion}" "${githubToken}"
    """
    
    archiveArtifacts artifacts: 'release_notes.md,CHANGELOG.md', 
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

def notifyStart(environment, services) {
    def summary = "🚀 ${environment.toUpperCase()} pipeline started - ${env.JOB_NAME} #${env.BUILD_NUMBER}"
    def details = "Servicios a construir/desplegar: ${services ?: 'N/A'}"
    sendNotification('info', summary, details, services, false)
}

def notifySuccess(environment, services) {
    def summary = "✅ ${environment.toUpperCase()} pipeline succeeded - ${env.JOB_NAME} #${env.BUILD_NUMBER}"
    def details = "Servicios construidos/desplegados: ${services ?: 'N/A'}"
    sendNotification('info', summary, details, services, false)
}

def notifyWarning(environment, services) {
    def summary = "⚠ ${environment.toUpperCase()} pipeline finalizó con advertencias - ${env.JOB_NAME} #${env.BUILD_NUMBER}"
    def details = "Revisar la etapa: ${env.STAGE_NAME ?: 'N/A'} | Servicios: ${services ?: 'N/A'}"
    sendNotification('warning', summary, details, services, true)
}

def notifyFailure(environment, services) {
    def summary = "❌ ${environment.toUpperCase()} pipeline failed - ${env.JOB_NAME} #${env.BUILD_NUMBER}"
    def details = """Etapa: ${env.STAGE_NAME ?: 'N/A'}
Servicios afectados: ${services ?: 'N/A'}
Branch: ${env.GIT_BRANCH}
Commit: ${env.GIT_COMMIT_SHORT}"""
    sendNotification('error', summary, details, services, true)
}

def runSonarAnalyses(changedServices) {
    def commonVars = load 'jenkins/shared-lib/vars/commonVars.groovy'
    def serviceList = changedServices.split(',')

    for (serviceName in serviceList) {
        def service = serviceName.trim()

        def serviceConfig = commonVars.getServiceConfig(service)
        if (serviceConfig?.external) {
            echo "Skipping SonarCloud analysis for external service: ${service}"
            continue
        }

        echo "Starting SonarCloud analysis for ${service}..."
        sh """
            chmod +x jenkins/scan/sonar-service.sh
            jenkins/scan/sonar-service.sh "${service}"
        """
    }
}

// Función para generar el dashboard de seguridad
def generateSecurityDashboard(summaryJsonPath, dashboardOutputPath) {
    sh """
        python3 jenkins/scan/security-generate-dashboard.py \
            "${summaryJsonPath}" \
            "${dashboardOutputPath}"
    """
}

// Función para escanear las imágenes con Trivy
def scanImagesWithTrivy(imageListPath, reportDir, summaryCsvPath, summaryJsonPath, severity, statusPath = null) {
    def finalStatusPath = statusPath ?: "${reportDir}/summary-status.properties"
    sh """
        chmod +x jenkins/scan/security-scan-images.sh
        jenkins/scan/security-scan-images.sh \
            "${imageListPath}" \
            "${reportDir}" \
            "${summaryCsvPath}" \
            "${summaryJsonPath}" \
            "${severity}" \
            "${finalStatusPath}"
    """
    return finalStatusPath
}

def runTrivyScans(changedServices, registry, imageTag) {
    def commonVars = load 'jenkins/shared-lib/vars/commonVars.groovy'
    def serviceList = changedServices.split(',')
    def imagesFile = "trivy-images.txt"
    def reportDir = "trivy-reports/services"
    sh "mkdir -p ${reportDir}"

    // Escritura de imágenes a escanear en un archivo (una por línea)
    writeFile file: imagesFile, text: (
        serviceList.collect { serviceName ->
            def service = serviceName.trim()
            def serviceConfig = commonVars.getServiceConfig(service)
            if (serviceConfig?.external) {
                echo "Skipping Trivy scan for external service: ${service}"
                return null
            }
            echo "Adding image for Trivy scan: ${registry}/${service}:${imageTag}"
            return "${registry}/${service}:${imageTag}"
        }.findAll { it != null }.join('\n') + '\n'
    )

    def summaryCsvPath = "${reportDir}/summary.csv"
    def summaryJsonPath = "${reportDir}/summary.json"
    def severity = commonVars.getTrivySeverityThreshold()
    def statusPath = "${reportDir}/summary-status.properties"

    scanImagesWithTrivy(imagesFile, reportDir, summaryCsvPath, summaryJsonPath, severity, statusPath)

    archiveArtifacts artifacts: 'trivy-reports/**/*.json', fingerprint: true, allowEmptyArchive: true
}

def runZapSecurityScan(namespace, apiGatewayUrl, reportDir) {
    sh """
        chmod +x jenkins/tests/zap-security-scan.sh
        export KCFG="\${KCFG}"
        jenkins/tests/zap-security-scan.sh "${namespace}" "${apiGatewayUrl}" "${reportDir}"
    """
    
    // Archive ZAP reports
    archiveArtifacts artifacts: 'tests/zap-reports/**/*', fingerprint: true, allowEmptyArchive: true
}

def cleanSpace() {
    sh """
        docker system prune -af               # Necesita Docker group
        rm -rf /var/lib/jenkins/.cache/trivy/*
        rm -rf /var/lib/jenkins/.sonar/cache/*
        find /var/lib/jenkins/.m2/repository -type f -mtime +14 -delete
    """
}

def sendNotification(severity, summary, details, services, includeMentions = false) {
    echo "========================================="
    echo summary
    if (details) {
        echo details
    }
    echo "========================================="

    def commonVars = load 'jenkins/shared-lib/vars/commonVars.groovy'
    def notificationConfig = commonVars.getNotificationConfig()
    if (!notificationConfig?.enabled?.toBoolean()) {
        echo "Notifications are disabled. Skipping external alert."
        return
    }

    def logUrl = env.BUILD_URL ? "${env.BUILD_URL}console" : ''
    def pipelineUrl = env.RUN_DISPLAY_URL ?: env.BUILD_URL ?: ''
    def mentions = includeMentions ? collectOwnerMentions(services) : [slack: []]

    switch(notificationConfig.channel) {
        case 'slack':
            sendSlackNotification(notificationConfig.slack, severity, summary, details, services, logUrl, pipelineUrl, mentions.slack)
            break
        default:
            echo "Unknown notification channel '${notificationConfig.channel}'. Notification skipped."
    }
}

def sendSlackNotification(slackConfig, severity, summary, details, services, logUrl, pipelineUrl, mentions = []) {
    if (!slackConfig?.credentialId) {
        echo "Slack credential not configured. Skipping Slack notification."
        return
    }

    def colorPalette = [
        info: '#2EB67D',
        warning: '#ECB22E',
        error: '#E01E5A'
    ]
    def color = colorPalette[(severity ?: 'info') as String] ?: '#439FE0'
    def mentionText = mentions?.findAll { it }?.unique()?.join(' ') ?: ''
    def text = mentionText ? "${mentionText} ${summary}" : summary

    def fields = [
        [title: 'Pipeline', value: "${env.JOB_NAME} #${env.BUILD_NUMBER}", short: true],
        [title: 'Environment', value: env.TARGET_ENVIRONMENT ?: 'N/A', short: true]
    ]

    if (env.STAGE_NAME) {
        fields << [title: 'Stage', value: env.STAGE_NAME, short: true]
    }
    if (services) {
        fields << [title: 'Servicios', value: services, short: false]
    }
    if (details) {
        fields << [title: 'Detalles', value: details, short: false]
    }
    if (logUrl) {
        fields << [title: 'Logs', value: "<${logUrl}|Abrir consola>", short: false]
    }

    def payload = [
        text: text,
        username: slackConfig.username ?: 'Jenkins CI',
        icon_emoji: slackConfig.iconEmoji ?: ':rocket:',
        attachments: [[
            color: color,
            fields: fields
        ]]
    ]

    if (slackConfig.channel) {
        payload.channel = slackConfig.channel
    }

    def payloadJson = JsonOutput.toJson(payload)
    writeFile file: 'slack_payload.json', text: payloadJson

    withCredentials([string(credentialsId: slackConfig.credentialId, variable: 'SLACK_WEBHOOK_URL')]) {
        sh """
            curl -s -X POST -H 'Content-type: application/json' --data @slack_payload.json "$SLACK_WEBHOOK_URL" >/dev/null
        """
    }

    sh 'rm -f slack_payload.json'
}

def collectOwnerMentions(changedServices) {
    def mentions = [slack: []]
    if (!changedServices?.trim()) {
        return mentions
    }

    def serviceList = changedServices.split(',').collect { it.trim() }.findAll { it }
    def commonVars = load 'jenkins/shared-lib/vars/commonVars.groovy'
    def ownersMap = commonVars.getServiceCodeOwners()

    serviceList.each { service ->
        def owner = ownersMap.get(service)
        if (owner?.slack) {
            mentions.slack << owner.slack
        }
    }

    mentions.slack = mentions.slack.unique()
    return mentions
}

return this