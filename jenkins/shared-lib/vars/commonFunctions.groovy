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
    def servicePaths = services.findAll { it.path }.collect { it.path }.join(',')
    
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
    def deployedServices = []

    echo "========================================="
    echo "Deploying services to ${environment}"
    echo "Namespace: ${namespace}"
    echo "========================================="

    ensureNamespace(namespace)

    echo "Step 1: Applying ConfigMap for ${environment}..."
    applyConfigMap(environment, namespace)

    def deployListInOrder = [
        commonVars.getCoreServices(),
        commonVars.getMonitoringServices()
    ]

    deployListInOrder.each { group ->
        group.each { service ->
            if (changedServices.contains(service.name)) {
                deployServiceWithTracking(service, environment, namespace, registry, imageTag, deployedServices)
            }
        }
    }

    echo "Step 4: Deploying business services..."
    def businessServices = commonVars.getBusinessServices()
    def businessStages = [:]
    businessServices.each { service ->
        if (changedServices.contains(service.name)) {
            def svc = service
            businessStages["Deploy ${svc.name}"] = {
                deployServiceWithTracking(svc, environment, namespace, registry, imageTag, deployedServices)
            }
        }
    }
    if (!businessStages.isEmpty()) {
        parallel businessStages
    }

    if (!deployedServices.isEmpty()) {
        env.SUCCESSFUL_DEPLOYS = deployedServices.join(',')
        echo "Services deployed successfully: ${env.SUCCESSFUL_DEPLOYS}"
    } else {
        env.SUCCESSFUL_DEPLOYS = ''
        echo "No services were deployed in this stage."
    }
}

def ensureNamespace(namespace) {
    sh """
        kubectl --kubeconfig="\${KCFG}" get ns ${namespace} >/dev/null 2>&1 || \
        kubectl --kubeconfig="\${KCFG}" create namespace ${namespace}
    """
}

def applyConfigMap(environment, namespace) {
    def configMapFile = "k8s/base/02-configmap-${environment}.yaml"
    
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

/**
 * Get Terraform output value
 * @param envNamespace Environment namespace (staging/prod)
 * @param outputName Name of the Terraform output
 * @return Output value as string
 */
def getTerraformOutput(envNamespace, outputName) {
    return sh(
        script: """
            cd infra/terraform/environments/${envNamespace}
            terraform output -raw ${outputName} 2>/dev/null || echo ""
        """,
        returnStdout: true
    ).trim()
}

/**
 * Get all monitoring-related outputs from Terraform
 * @param envNamespace Environment namespace (staging/prod)
 * @return Map with monitoring outputs
 */
def getMonitoringOutputs(envNamespace) {
    // Obtener outputs básicos de Terraform
    def resourceGroupName = getTerraformOutput(envNamespace, 'resource_group_name')
    def terraformQueryEndpoint = getTerraformOutput(envNamespace, 'prometheus_query_endpoint')
    def terraformIngestionEndpoint = getTerraformOutput(envNamespace, 'prometheus_ingestion_endpoint')
    
    // Intentar obtener el nombre del workspace desde Terraform
    // Si no está disponible como output directo, extraerlo del endpoint o usar el ID
    def prometheusWsName = getTerraformOutput(envNamespace, 'prometheus_workspace_name')
    
    // Si el nombre no está disponible, intentar extraerlo del endpoint o usar el ID
    if (!prometheusWsName || prometheusWsName.isEmpty()) {
        // Intentar extraer el nombre del endpoint de Terraform
        if (terraformQueryEndpoint && terraformQueryEndpoint.contains('prometheus.monitor.azure.com')) {
            def match = terraformQueryEndpoint =~ /https:\/\/([^.]+)\./
            if (match) {
                prometheusWsName = match[0][1]
                echo "Extracted workspace name from endpoint: ${prometheusWsName}"
            }
        }
        
        // Si aún no tenemos el nombre, intentar obtenerlo desde el workspace ID
        if (!prometheusWsName || prometheusWsName.isEmpty()) {
            def workspaceId = getTerraformOutput(envNamespace, 'prometheus_workspace_id')
            if (workspaceId && workspaceId.contains('/accounts/')) {
                def parts = workspaceId.split('/')
                def accountIndex = parts.findIndexOf { it == 'accounts' }
                if (accountIndex >= 0 && accountIndex < parts.size() - 1) {
                    prometheusWsName = parts[accountIndex + 1]
                    echo "Extracted workspace name from ID: ${prometheusWsName}"
                }
            }
        }
    }
    
    // Obtener el endpoint real desde Azure CLI (incluye el sufijo aleatorio)
    // Azure agrega un sufijo aleatorio al nombre del workspace en el endpoint
    def realQueryEndpoint = terraformQueryEndpoint
    def realIngestionEndpoint = terraformIngestionEndpoint
    
    if (prometheusWsName && !prometheusWsName.isEmpty() && resourceGroupName && !resourceGroupName.isEmpty()) {
        try {
            echo "Obtaining real Prometheus endpoint from Azure (includes random suffix)..."
            echo "  Workspace: ${prometheusWsName}"
            echo "  Resource Group: ${resourceGroupName}"
            
            // Get query endpoint
            def azureQueryEndpoint = sh(
                script: """
                    az monitor account show \
                        --name "${prometheusWsName}" \
                        --resource-group "${resourceGroupName}" \
                        --query "metrics.prometheusQueryEndpoint" \
                        -o tsv 2>/dev/null || echo ""
                """,
                returnStdout: true
            ).trim()
            
            // Get ingestion endpoint (may be different)
            def azureIngestionEndpoint = sh(
                script: """
                    az monitor account show \
                        --name "${prometheusWsName}" \
                        --resource-group "${resourceGroupName}" \
                        --query "metrics.prometheusIngestionEndpoint" \
                        -o tsv 2>/dev/null || echo ""
                """,
                returnStdout: true
            ).trim()
            
            if (azureQueryEndpoint && azureQueryEndpoint.length() > 0 && azureQueryEndpoint.startsWith('https://')) {
                echo "✓ Found real Prometheus query endpoint: ${azureQueryEndpoint}"
                realQueryEndpoint = azureQueryEndpoint
            }
            
            // For ingestion, Azure Monitor Workspace requires using Data Collection Endpoint (DCE) with Data Collection Rule (DCR)
            // The format is: {DCE_ENDPOINT}/dataCollectionRules/{DCR_ID}/streams/Microsoft-PrometheusMetrics/api/v1/write?api-version=2021-11-01-preview
            // First, try to get DCE endpoint and DCR ID from Azure CLI
            def dceName = sh(
                script: """
                    az monitor data-collection endpoint list \
                        --resource-group "${resourceGroupName}" \
                        --query "[?contains(name, 'prom-dce')].name" \
                        -o tsv 2>/dev/null | head -1 || echo ""
                """,
                returnStdout: true
            ).trim()
            
            if (dceName && !dceName.isEmpty()) {
                echo "Found DCE: ${dceName}"
                
                // Get DCE endpoint
                def dceEndpoint = sh(
                    script: """
                        az monitor data-collection endpoint show \
                            --name "${dceName}" \
                            --resource-group "${resourceGroupName}" \
                            --query "logsIngestion.endpoint" \
                            -o tsv 2>/dev/null || echo ""
                    """,
                    returnStdout: true
                ).trim()
                
                // Get DCR name first
                def dcrName = sh(
                    script: """
                        az monitor data-collection rule list \
                            --resource-group "${resourceGroupName}" \
                            --query "[?contains(name, 'prom-dcr')].name" \
                            -o tsv 2>/dev/null | head -1 || echo ""
                    """,
                    returnStdout: true
                ).trim()
                
                // Get DCR immutable ID (required by Azure, not the name)
                def dcrImmutableId = ""
                if (dcrName && !dcrName.isEmpty()) {
                    dcrImmutableId = sh(
                        script: """
                            az monitor data-collection rule show \
                                --name "${dcrName}" \
                                --resource-group "${resourceGroupName}" \
                                --query "immutableId" \
                                -o tsv 2>/dev/null || echo ""
                        """,
                        returnStdout: true
                    ).trim()
                }
                
                if (dceEndpoint && !dceEndpoint.isEmpty() && dcrImmutableId && !dcrImmutableId.isEmpty()) {
                    // Azure requires the immutable ID (not the name) in the path
                    // Format: {DCE_ENDPOINT}/dataCollectionRules/{DCR_IMMUTABLE_ID}/streams/Microsoft-PrometheusMetrics/api/v1/write?api-version=2021-11-01-preview
                    realIngestionEndpoint = "${dceEndpoint}/dataCollectionRules/${dcrImmutableId}/streams/Microsoft-PrometheusMetrics/api/v1/write?api-version=2021-11-01-preview"
                    echo "✓ Constructed Prometheus ingestion endpoint using DCE/DCR: ${realIngestionEndpoint}"
                    echo "  DCE Endpoint: ${dceEndpoint}"
                    echo "  DCR Name: ${dcrName}"
                    echo "  DCR Immutable ID: ${dcrImmutableId}"
                } else {
                    echo "⚠ DCE endpoint or DCR ID not found, falling back to workspace endpoint"
                    if (azureQueryEndpoint && azureQueryEndpoint.length() > 0) {
                        realIngestionEndpoint = azureQueryEndpoint
                        echo "  Using query endpoint as fallback: ${realIngestionEndpoint}"
                    }
                }
            } else {
                echo "⚠ DCE not found, using workspace endpoint as fallback"
                if (azureQueryEndpoint && azureQueryEndpoint.length() > 0) {
                    realIngestionEndpoint = azureQueryEndpoint
                    echo "  Using query endpoint: ${realIngestionEndpoint}"
                }
            }
        } catch (Exception e) {
            echo "⚠ Error getting endpoint from Azure CLI: ${e.getMessage()}"
            echo "  Using Terraform output as fallback"
        }
    } else {
        echo "⚠ Cannot get endpoint from Azure CLI: missing workspace name or resource group"
        echo "  Workspace name: ${prometheusWsName ?: 'empty'}"
        echo "  Resource group: ${resourceGroupName ?: 'empty'}"
        echo "  Using Terraform output as fallback"
    }
    
    // Validar que el endpoint de ingestion tenga el query parameter completo
    if (realIngestionEndpoint && realIngestionEndpoint.contains("dataCollectionRules") && !realIngestionEndpoint.contains("api-version=2021-11-01-preview")) {
        echo "⚠ WARNING: Ingestion endpoint missing api-version query parameter, adding it..."
        if (realIngestionEndpoint.contains("?")) {
            realIngestionEndpoint = "${realIngestionEndpoint}&api-version=2021-11-01-preview"
        } else {
            realIngestionEndpoint = "${realIngestionEndpoint}?api-version=2021-11-01-preview"
        }
    }
    
    // Validar formato del endpoint antes de retornar
    if (realIngestionEndpoint && realIngestionEndpoint.contains("dataCollectionRules")) {
        if (!realIngestionEndpoint.contains("api-version=2021-11-01-preview")) {
            echo "⚠ ERROR: Ingestion endpoint is missing required query parameter: api-version=2021-11-01-preview"
            echo "  Endpoint: ${realIngestionEndpoint}"
        } else {
            echo "✓ Ingestion endpoint validated: contains required query parameter"
        }
    }
    
    return [
        prometheusIngestionEndpoint: realIngestionEndpoint,
        prometheusQueryEndpoint: realQueryEndpoint,
        grafanaEndpoint: getTerraformOutput(envNamespace, 'grafana_endpoint'),
        grafanaName: getTerraformOutput(envNamespace, 'grafana_name')
    ]
}

/**
 * Assign Monitoring Metrics Publisher role to Service Principal on DCR
 * This is required for Prometheus Agent to send metrics to Azure Monitor Workspace
 * @param namespace Kubernetes namespace (staging/prod)
 * @param clientId Azure AD Service Principal Client ID
 */
def assignDcrPermissions(namespace, clientId) {
    echo "========================================="
    echo "Assigning DCR Permissions"
    echo "========================================="
        echo "Namespace: ${namespace}"
    echo "Client ID: ${clientId}"
    echo "========================================="
    
    def resourceGroupName = getTerraformOutput(namespace, 'resource_group_name')
    if (!resourceGroupName || resourceGroupName.isEmpty()) {
        error("Cannot assign DCR permissions: resource_group_name not found in Terraform outputs")
}
    
    // Get Object ID (Principal ID) from Client ID
    def objectId = sh(
        script: """
            az ad sp show --id "${clientId}" --query "id" -o tsv 2>/dev/null || echo ""
        """,
        returnStdout: true
    ).trim()
    
    if (!objectId || objectId.isEmpty()) {
        error("Cannot assign DCR permissions: Could not get Object ID from Client ID ${clientId}")
    }
    
    echo "Object ID (Principal ID): ${objectId}"
    
    // Get DCR ID
    def dcrName = sh(
        script: """
            az monitor data-collection rule list \
                --resource-group "${resourceGroupName}" \
                --query "[?contains(name, 'prom-dcr')].name" \
                -o tsv 2>/dev/null | head -1 || echo ""
        """,
        returnStdout: true
    ).trim()
    
    if (!dcrName || dcrName.isEmpty()) {
        error("Cannot assign DCR permissions: DCR not found in resource group ${resourceGroupName}")
    }
    
    def dcrId = sh(
        script: """
            az monitor data-collection rule show \
                --name "${dcrName}" \
                --resource-group "${resourceGroupName}" \
                --query "id" \
                -o tsv 2>/dev/null || echo ""
        """,
        returnStdout: true
    ).trim()
    
    echo "DCR: ${dcrName}"
    echo "DCR ID: ${dcrId}"
    
    // Check if role assignment already exists
    def existingAssignment = sh(
        script: """
            az role assignment list \
                --scope "${dcrId}" \
                --assignee "${objectId}" \
                --query "[?roleDefinitionName=='Monitoring Metrics Publisher'].id" \
                -o tsv 2>/dev/null || echo ""
        """,
        returnStdout: true
    ).trim()
    
    if (existingAssignment && !existingAssignment.isEmpty()) {
        echo "✓ Role 'Monitoring Metrics Publisher' already assigned"
        echo "  Assignment ID: ${existingAssignment}"
    } else {
        // Create role assignment
        echo "Assigning role 'Monitoring Metrics Publisher'..."
        def assignmentId = sh(
            script: """
                az role assignment create \
                    --scope "${dcrId}" \
                    --role "Monitoring Metrics Publisher" \
                    --assignee "${objectId}" \
                    --query "id" \
                    -o tsv 2>/dev/null || echo ""
            """,
            returnStdout: true
        ).trim()
        
        if (assignmentId && !assignmentId.isEmpty()) {
            echo "✓ Role assigned successfully"
            echo "  Assignment ID: ${assignmentId}"
        } else {
            error("Failed to assign role 'Monitoring Metrics Publisher' to Service Principal")
        }
    }
    
    echo ""
    echo "⚠️ Note: Permissions may take 5-10 minutes to propagate in Azure"
    echo "========================================="
}

/**
 * Save monitoring outputs to file for later use
 * @param envNamespace Environment namespace
 * @param outputs Map with monitoring outputs
 */
def saveMonitoringOutputs(envNamespace, outputs) {
    def outputFile = "${env.WORKSPACE}/.monitoring-${envNamespace}.env"
    sh """
        echo "PROMETHEUS_INGESTION_ENDPOINT=${outputs.prometheusIngestionEndpoint}" > "${outputFile}"
        echo "PROMETHEUS_QUERY_ENDPOINT=${outputs.prometheusQueryEndpoint}" >> "${outputFile}"
        echo "GRAFANA_ENDPOINT=${outputs.grafanaEndpoint}" >> "${outputFile}"
        echo "GRAFANA_NAME=${outputs.grafanaName}" >> "${outputFile}"
    """
    return outputFile
}

/**
 * Load monitoring outputs from file
 * @param envNamespace Environment namespace
 * @return Map with monitoring outputs
 */
def loadMonitoringOutputs(envNamespace) {
    def outputFile = "${env.WORKSPACE}/.monitoring-${envNamespace}.env"
    if (!fileExists(outputFile)) {
        echo "Warning: Monitoring outputs file not found: ${outputFile}"
        return [:]
    }
    
    def ingestionEndpoint = sh(
        script: "grep PROMETHEUS_INGESTION_ENDPOINT '${outputFile}'",
        returnStdout: true
    ).trim()
    
    def queryEndpoint = sh(
        script: "grep PROMETHEUS_QUERY_ENDPOINT '${outputFile}' | cut -d= -f2",
        returnStdout: true
    ).trim()
    
    def grafanaEndpoint = sh(
        script: "grep GRAFANA_ENDPOINT '${outputFile}' | cut -d= -f2",
        returnStdout: true
    ).trim()
    
    def grafanaName = sh(
        script: "grep GRAFANA_NAME '${outputFile}' | cut -d= -f2",
        returnStdout: true
    ).trim()
    
    return [
        prometheusIngestionEndpoint: ingestionEndpoint,
        prometheusQueryEndpoint: queryEndpoint,
        grafanaEndpoint: grafanaEndpoint,
        grafanaName: grafanaName
    ]
}

/**
 * Retrieves all relevant logging outputs from Terraform.
 * @param envNamespace The environment namespace.
 * @return A map containing elasticsearchEndpoint, elasticsearchInternalEndpoint, kibanaEndpoint, and logstashEndpoint.
 */
def getLoggingOutputs(envNamespace) {
    def workspaceId = getTerraformOutput(envNamespace, 'log_analytics_workspace_id')
    def customerId = getTerraformOutput(envNamespace, 'log_analytics_workspace_customer_id')
    def sharedKey = getTerraformOutput(envNamespace, 'log_analytics_workspace_primary_shared_key')
    
    // Validar que los outputs de Log Analytics no estén vacíos
    if (!workspaceId || workspaceId.isEmpty()) {
        echo "⚠ Warning: log_analytics_workspace_id is empty. Make sure Terraform has been applied."
    }
    if (!customerId || customerId.isEmpty()) {
        echo "⚠ Warning: log_analytics_workspace_customer_id is empty. Make sure Terraform has been applied."
    }
    if (!sharedKey || sharedKey.isEmpty()) {
        echo "⚠ Warning: log_analytics_workspace_primary_shared_key is empty. Make sure Terraform has been applied."
    }
    
    return [
        logAnalyticsWorkspaceId: workspaceId,
        logAnalyticsCustomerId: customerId,
        logAnalyticsSharedKey: sharedKey,
        elasticsearchEndpoint: getTerraformOutput(envNamespace, 'elasticsearch_endpoint'),
        elasticsearchInternalEndpoint: getTerraformOutput(envNamespace, 'elasticsearch_internal_endpoint'),
        kibanaEndpoint: getTerraformOutput(envNamespace, 'kibana_endpoint'),
        logstashEndpoint: getTerraformOutput(envNamespace, 'logstash_endpoint')
    ]
}

/**
 * Saves logging outputs to a file for later use.
 * @param envNamespace The environment namespace.
 * @param loggingOutputs A map containing the logging outputs.
 * @return The path to the file where outputs were saved.
 */
def saveLoggingOutputs(envNamespace, loggingOutputs) {
    def outputFile = "${env.WORKSPACE}/.logging-${envNamespace}.env"
    sh """
        echo "LOG_ANALYTICS_WORKSPACE_ID=${loggingOutputs.logAnalyticsWorkspaceId}" > "${outputFile}"
        echo "LOG_ANALYTICS_CUSTOMER_ID=${loggingOutputs.logAnalyticsCustomerId}" >> "${outputFile}"
        echo "LOG_ANALYTICS_SHARED_KEY=${loggingOutputs.logAnalyticsSharedKey}" >> "${outputFile}"
        echo "ELASTICSEARCH_ENDPOINT=${loggingOutputs.elasticsearchEndpoint}" >> "${outputFile}"
        echo "ELASTICSEARCH_INTERNAL_ENDPOINT=${loggingOutputs.elasticsearchInternalEndpoint}" >> "${outputFile}"
        echo "KIBANA_ENDPOINT=${loggingOutputs.kibanaEndpoint}" >> "${outputFile}"
        echo "LOGSTASH_ENDPOINT=${loggingOutputs.logstashEndpoint}" >> "${outputFile}"
    """
    return outputFile
}

/**
 * Loads logging outputs from a file.
 * @param envNamespace The environment namespace.
 * @return A map containing elasticsearchEndpoint, elasticsearchInternalEndpoint, kibanaEndpoint, and logstashEndpoint.
 */
def loadLoggingOutputs(envNamespace) {
    def outputFile = "${env.WORKSPACE}/.logging-${envNamespace}.env"
    if (!fileExists(outputFile)) {
        echo "Warning: Logging outputs file not found: ${outputFile}"
        return [:]
    }
    
    def logAnalyticsWorkspaceId = sh(
        script: "grep LOG_ANALYTICS_WORKSPACE_ID '${outputFile}' | cut -d= -f2",
        returnStdout: true
    ).trim()
    
    def logAnalyticsCustomerId = sh(
        script: "grep LOG_ANALYTICS_CUSTOMER_ID '${outputFile}' | cut -d= -f2",
        returnStdout: true
    ).trim()
    
    def logAnalyticsSharedKey = sh(
        script: "grep LOG_ANALYTICS_SHARED_KEY '${outputFile}' | cut -d= -f2",
        returnStdout: true
    ).trim()
    
    def elasticsearchEndpoint = sh(
        script: "grep ELASTICSEARCH_ENDPOINT '${outputFile}' | cut -d= -f2",
        returnStdout: true
    ).trim()
    
    def elasticsearchInternalEndpoint = sh(
        script: "grep ELASTICSEARCH_INTERNAL_ENDPOINT '${outputFile}' | cut -d= -f2",
        returnStdout: true
    ).trim()
    
    def kibanaEndpoint = sh(
        script: "grep KIBANA_ENDPOINT '${outputFile}' | cut -d= -f2",
        returnStdout: true
    ).trim()
    
    def logstashEndpoint = sh(
        script: "grep LOGSTASH_ENDPOINT '${outputFile}' | cut -d= -f2",
        returnStdout: true
    ).trim()
    
    return [
        logAnalyticsWorkspaceId: logAnalyticsWorkspaceId,
        logAnalyticsCustomerId: logAnalyticsCustomerId,
        logAnalyticsSharedKey: logAnalyticsSharedKey,
        elasticsearchEndpoint: elasticsearchEndpoint,
        elasticsearchInternalEndpoint: elasticsearchInternalEndpoint,
        kibanaEndpoint: kibanaEndpoint,
        logstashEndpoint: logstashEndpoint
    ]
}

/**
 * Deploy Filebeat to send logs to Elasticsearch
 * @param namespace Kubernetes namespace
 * @param environment Environment name (staging/prod)
 * @param logAnalyticsWorkspaceId Azure Log Analytics Workspace ID (for reference, not used directly)
 * @param logAnalyticsCustomerId Azure Log Analytics Customer ID (for reference, not used directly)
 * @param logAnalyticsSharedKey Azure Log Analytics Primary Shared Key (for reference, not used directly)
 */
def deployFilebeat(namespace, environment, logAnalyticsWorkspaceId, logAnalyticsCustomerId, logAnalyticsSharedKey) {
    echo "========================================="
    echo "Deploying Filebeat"
    echo "========================================="
    echo "Namespace: ${namespace}"
    echo "Environment: ${environment}"
    echo "========================================="
    
    // Load logging outputs to get Elasticsearch endpoint
    def loggingOutputs = loadLoggingOutputs(namespace)
    def elasticsearchEndpoint = loggingOutputs.elasticsearchEndpoint
    
    if (!elasticsearchEndpoint || elasticsearchEndpoint.isEmpty()) {
        error("ERROR: elasticsearch_endpoint is empty. Please run 'terraform apply' in infra/terraform/environments/${namespace} to create Elasticsearch.")
    }
    
    echo "Elasticsearch Endpoint: ${elasticsearchEndpoint}"
    echo "Note: Filebeat will send logs directly to Elasticsearch"
    
    sh """
        chmod +x jenkins/scripts/deploy/deploy-filebeat.sh
        export KCFG="\${KCFG:-}"
        jenkins/scripts/deploy/deploy-filebeat.sh "${namespace}" "${environment}" "${elasticsearchEndpoint}"
    """
    
    echo ""
    echo "✓ Filebeat deployed successfully"
    echo "  Logs are being sent to Elasticsearch"
    
    // Verify deployment
    echo ""
    echo "Verifying deployment..."
    sh """
        kubectl --kubeconfig="\${KCFG}" get daemonset -n "${namespace}" filebeat || true
        kubectl --kubeconfig="\${KCFG}" get pods -n "${namespace}" -l app=filebeat || true
    """
}

def rollbackServices(namespace, services, kubeconfigPath) {
    if (!services?.trim()) {
        echo "No services provided for rollback."
        return
    }
    if (!kubeconfigPath?.trim()) {
        echo "No kubeconfig path provided; rollback skipped."
        return
    }

    def serviceList = services.split(',').collect { it.trim() }.findAll { it }
    if (serviceList.isEmpty()) {
        echo "Service list empty after parsing; rollback skipped."
        return
    }

    sh """
        chmod +x jenkins/scripts/rollback-services.sh
        jenkins/scripts/rollback-services.sh \
            --kubeconfig "${kubeconfigPath}" \
            --namespace "${namespace}" \
            --services "${serviceList.join(',')}"
    """
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

def deployServiceWithTracking(serviceConfig, environment, namespace, registry, imageTag, deployedServicesRef) {
    deployService(serviceConfig, environment, namespace, registry, imageTag)
    deployedServicesRef << serviceConfig.name
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

def runAllTests(namespace, changedServices) {
    def commonVars = load 'jenkins/shared-lib/vars/commonVars.groovy'
    
    def stagingGatewayIP = getLoadBalancerIP('api-gateway', 'staging')
    def apiGatewayUrl = "http://${stagingGatewayIP}:8080"

    def integrationTests = []
    def e2eTests = []
    def performanceServices = ''

    def serviceList = changedServices.split(',')
    for (serviceName in serviceList) {
        def service = serviceName.trim()
        def serviceConfig = commonVars.getServiceConfig(service)
        if (serviceConfig?.testsIntegration) {
            integrationTests.addAll(serviceConfig.testsIntegration)
        }
        if (serviceConfig?.testsE2E) {
            e2eTests.addAll(serviceConfig.testsE2E)
        }
        performanceServices += service + ','
    }
    
    // Remove duplicates from e2eTests
    e2eTests = e2eTests.unique()
    
    // If no E2E tests found, use default
    if (e2eTests.isEmpty()) {
        e2eTests = ["e2e/test_user_flow.py"]
    }

    def testStages = [
        'Integration Tests': {
            runIntegrationTests(namespace, apiGatewayUrl, integrationTests)
        },
        'E2E Tests': {
            runE2ETests(namespace, apiGatewayUrl, e2eTests)
        },
        'Performance Tests': {
            runPerformanceTests(namespace, apiGatewayUrl, performanceServices)
        }
    ]

    parallel testStages
    
    // Security tests run after other tests (sequential to avoid resource conflicts)
    stage('Security Tests') {
        runSecurityTests(namespace, apiGatewayUrl, 'baseline', 'zap-reports')
    }
}

def runIntegrationTests(namespace, apiGatewayUrl, integrationTests) {
    sh """
        chmod +x jenkins/tests/integration-tests.sh
        export KCFG="\${KCFG}"
        jenkins/tests/integration-tests.sh "${namespace}" "${apiGatewayUrl}" "${integrationTests.join(',')}"
    """
}

def runE2ETests(namespace, apiGatewayUrl, e2eTests) {
    sh """
        chmod +x jenkins/tests/e2e-tests.sh
        export KCFG="\${KCFG}"
        jenkins/tests/e2e-tests.sh "${namespace}" "${apiGatewayUrl}" "${e2eTests.join(',')}"
    """
}

def runPerformanceTests(namespace, apiGatewayUrl, services='', users = '50', spawnRate = '10', runTime = '300s') {
    sh """
        chmod +x jenkins/tests/performance-tests.sh
        export KCFG="\${KCFG}"
        jenkins/tests/performance-tests.sh "${namespace}" "${apiGatewayUrl}" "${users}" "${spawnRate}" "${runTime}" "${services}"
    """
    
    archiveArtifacts artifacts: 'performance-report.html,performance-data*.csv', 
                     fingerprint: true, 
                     allowEmptyArchive: true
}

def runStressTests(namespace, apiGatewayUrl, users = '500', spawnRate = '50', runTime = '300s') {
    sh """
        chmod +x jenkins/tests/stress-tests.sh
        export KCFG="\${KCFG}"
        jenkins/tests/stress-tests.sh "${namespace}" "${apiGatewayUrl}" "${users}" "${spawnRate}" "${runTime}"
    """
    
    archiveArtifacts artifacts: 'stress-report.html,stress-data*.csv', 
                     fingerprint: true, 
                     allowEmptyArchive: true
}

def runSpikeTests(namespace, apiGatewayUrl, users = '200', spawnRate = '100', runTime = '120s') {
    sh """
        chmod +x jenkins/tests/spike-tests.sh
        export KCFG="\${KCFG}"
        jenkins/tests/spike-tests.sh "${namespace}" "${apiGatewayUrl}" "${users}" "${spawnRate}" "${runTime}"
    """
    
    archiveArtifacts artifacts: 'spike-report.html,spike-data*.csv', 
                     fingerprint: true, 
                     allowEmptyArchive: true
}

def runEnduranceTests(namespace, apiGatewayUrl, users = '100', spawnRate = '10', runTime = '1800s') {
    sh """
        chmod +x jenkins/tests/endurance-tests.sh
        export KCFG="\${KCFG}"
        jenkins/tests/endurance-tests.sh "${namespace}" "${apiGatewayUrl}" "${users}" "${spawnRate}" "${runTime}"
    """
    
    archiveArtifacts artifacts: 'endurance-report.html,endurance-data*.csv', 
                     fingerprint: true, 
                     allowEmptyArchive: true
}

def runSecurityTests(namespace, apiGatewayUrl, scanType = 'baseline', reportDir = 'zap-reports') {
    sh """
        chmod +x jenkins/tests/security-tests.sh
        export KCFG="\${KCFG}"
        jenkins/tests/security-tests.sh "${namespace}" "${apiGatewayUrl}" "${scanType}" "${reportDir}"
    """
    
    archiveArtifacts artifacts: 'zap-reports/**/*.html,zap-reports/**/*.json,zap-reports/**/*.xml', 
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

    def releaseNotesLink = env.BUILD_URL ? "${env.BUILD_URL}artifact/release_notes.md" : 'release_notes.md'
    def summary = "📦 Release ${releaseVersion} publicado"
    def details = "Notas: ${releaseNotesLink}\nServicios: ${env.CHANGED_SERVICES ?: 'N/A'}"
    sendNotification('info', summary, details, env.CHANGED_SERVICES, false)
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

def publishJavaCoverageReports(changedServices) {
    def serviceList = changedServices.split(',')
    
    for (serviceName in serviceList) {
        def service = serviceName.trim()
        def coverageReport = "${service}/target/site/jacoco/index.html"
        def coverageXml = "${service}/target/site/jacoco/jacoco.xml"
        
        if (fileExists(coverageReport)) {
            echo "Publishing coverage report for ${service}..."
            publishHTML([
                reportName: "${service} Coverage Report",
                reportDir: "${service}/target/site/jacoco",
                reportFiles: 'index.html',
                keepAll: true,
                alwaysLinkToLastBuild: true
            ])
        }
        
        if (fileExists(coverageXml)) {
            archiveArtifacts artifacts: "${service}/target/site/jacoco/**/*", 
                             fingerprint: true, 
                             allowEmptyArchive: true
        }
    }
}

def publishPythonCoverageReports() {
    // Publish integration test coverage
    if (fileExists('coverage-integration/index.html')) {
        publishHTML([
            reportName: 'Integration Tests Coverage',
            reportDir: 'coverage-integration',
            reportFiles: 'index.html',
            keepAll: true,
            alwaysLinkToLastBuild: true
        ])
        archiveArtifacts artifacts: 'coverage-integration/**/*,coverage-integration.xml,coverage-integration.json', 
                         fingerprint: true, 
                         allowEmptyArchive: true
    }
    
    // Publish E2E test coverage
    if (fileExists('coverage-e2e/index.html')) {
        publishHTML([
            reportName: 'E2E Tests Coverage',
            reportDir: 'coverage-e2e',
            reportFiles: 'index.html',
            keepAll: true,
            alwaysLinkToLastBuild: true
        ])
        archiveArtifacts artifacts: 'coverage-e2e/**/*,coverage-e2e.xml,coverage-e2e.json', 
                         fingerprint: true, 
                         allowEmptyArchive: true
    }
}

def generateConsolidatedCoverageReport(changedServices) {
    echo "Generating consolidated coverage report..."
    
    sh """
        chmod +x jenkins/scripts/generate-coverage-report.sh
        jenkins/scripts/generate-coverage-report.sh "${changedServices}"
    """
    
    if (fileExists('coverage-consolidated/index.html')) {
        publishHTML([
            reportName: 'Consolidated Coverage Report',
            reportDir: 'coverage-consolidated',
            reportFiles: 'index.html',
            keepAll: true,
            alwaysLinkToLastBuild: true
        ])
        archiveArtifacts artifacts: 'coverage-consolidated/**/*', 
                     fingerprint: true, 
                     allowEmptyArchive: true
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

def cleanSpace() {
    sh """
        docker system prune -af               # Necesita Docker group
        rm -rf /var/lib/jenkins/.cache/trivy/*
        rm -rf /var/lib/jenkins/.sonar/cache/*
        find /var/lib/jenkins/.m2/repository -type f -mtime +14 -delete
    """
}

/**
 * Deploy Prometheus Agent (lightweight) that sends metrics to Azure Monitor Workspace
 * @param namespace Kubernetes namespace
 * @param environment Environment name (staging/prod)
 * @param azureIngestionEndpoint Azure Monitor Workspace ingestion endpoint
 * @param azureClientId Azure AD client ID for authentication
 * @param azureTenantId Azure AD tenant ID
 * @param azureClientSecret Azure AD client secret
 */
def deployPrometheusAgent(namespace, environment, azureIngestionEndpoint, azureClientId, azureTenantId, azureClientSecret) {
    echo "========================================="
    echo "Deploying Prometheus Agent"
    echo "========================================="
    echo "Namespace: ${namespace}"
    echo "Environment: ${environment}"
    echo "Azure Ingestion Endpoint: ${azureIngestionEndpoint}"
    echo "========================================="
    
    sh """
        chmod +x jenkins/scripts/deploy/deploy-prometheus-agent.sh
        export KCFG="\${KCFG:-}"
        jenkins/scripts/deploy/deploy-prometheus-agent.sh \
            "${namespace}" \
            "${environment}" \
            "${azureIngestionEndpoint}" \
            "${azureClientId}" \
            "${azureTenantId}" \
            "${azureClientSecret}"
    """
    
    echo ""
    echo "✓ Prometheus Agent deployed successfully"
    echo "  Metrics are being sent to Azure Monitor Workspace"
    
    // Verify deployment
    echo ""
    echo "Verifying deployment..."
    sh """
        kubectl --kubeconfig="\${KCFG}" get pods -n "${namespace}" -l app=prometheus-agent || true
    """
}

/**
 * Get Grafana API Key from Jenkins credentials
 * Waits up to 10 minutes if credential is not found
 * @param namespace Kubernetes namespace (staging/prod)
 * @param grafanaName Grafana instance name (for error messages)
 * @return Grafana API key string
 */
def getGrafanaApiKey(namespace, grafanaName = '') {
    def credentialId = "GRAFANA_API_KEY_${namespace.toUpperCase()}"
    def grafanaApiKey = null
    
    // Intentar obtener la credencial específica del ambiente
    try {
        withCredentials([
            string(credentialsId: credentialId, variable: 'GRAFANA_API_KEY')
        ]) {
            grafanaApiKey = env.GRAFANA_API_KEY
            if (grafanaApiKey && grafanaApiKey.length() >= 20) {
                echo "✓ Using ${credentialId} from Jenkins credentials"
                return grafanaApiKey
            }
        }
    } catch (Exception e) {
        // Si no existe, esperar hasta que se configure
        echo ""
        echo "========================================="
        echo "⚠ Grafana API Key credential not found"
        echo "========================================="
        echo ""
        echo "Required credential ID: ${credentialId}"
        echo ""
        echo "Please configure the credential in Jenkins:"
        echo "  1. Jenkins → Manage Jenkins → Credentials"
        echo "  2. Add credential:"
        echo "     - Type: Secret text"
        echo "     - Secret: [Grafana Service Account Token]"
        echo "     - ID: ${credentialId}"
        echo "     - Description: Grafana API Key for ${namespace}"
        echo "  3. Save"
        echo ""
        if (grafanaName) {
            echo "To get the token:"
            echo "  Azure Portal → Azure Managed Grafana → ${grafanaName}"
            echo "  → Open Grafana → Administration → Service Accounts"
            echo "  → Create Service Account (Admin) → Generate Token"
            echo ""
        }
        echo "See: docs/MANUAL_GRAFANA_API_KEY.md"
        echo ""
        echo "Waiting for credential (max 10 minutes)..."
        echo ""
        
        // Esperar hasta que se configure la credencial
        def maxAttempts = 120 // 10 minutos (5 segundos por intento)
        def attempt = 0
        
        while (attempt < maxAttempts) {
            sleep(time: 5, unit: 'SECONDS')
            attempt++
            
            try {
                withCredentials([
                    string(credentialsId: credentialId, variable: 'GRAFANA_API_KEY')
                ]) {
                    grafanaApiKey = env.GRAFANA_API_KEY
                    if (grafanaApiKey && grafanaApiKey.length() >= 20) {
                        echo "✓ Credential ${credentialId} found! Continuing..."
                        return grafanaApiKey
                    }
                }
            } catch (Exception retryError) {
                if (attempt % 12 == 0) { // Mensaje cada minuto
                    echo "Still waiting... (${attempt * 5}s elapsed)"
                }
            }
        }
        
        error("Timeout: ${credentialId} not found after 10 minutes. Please configure the credential and rerun.")
    }
    
    // Validación final
    if (!grafanaApiKey || grafanaApiKey.length() < 20) {
        error("Invalid Grafana API key. Please verify the credential ${credentialId} in Jenkins.")
    }
    
    return grafanaApiKey
}

/**
 * Migrate Grafana dashboards to Azure Managed Grafana
 * @param grafanaEndpoint Azure Managed Grafana endpoint URL
 * @param grafanaApiKey API key for Azure Managed Grafana
 * @param prometheusQueryEndpoint Prometheus query endpoint for datasource configuration
 * @param dashboardsDir Directory containing dashboard JSON files
 */
def migrateGrafanaDashboards(grafanaEndpoint, grafanaApiKey, prometheusQueryEndpoint = '', dashboardsDir = 'k8s/monitoring/grafana-dashboards', environment = 'staging') {
    echo "========================================="
    echo "Migrating Grafana Dashboards"
    echo "========================================="
    echo "Grafana Endpoint: ${grafanaEndpoint}"
    echo "Dashboards Directory: ${dashboardsDir}"
    echo "========================================="
    
    // Validar que la API key tenga el formato correcto
    if (!grafanaApiKey || grafanaApiKey.isEmpty() || grafanaApiKey.length() < 20) {
        error("ERROR: Invalid Grafana API key provided. Key length: ${grafanaApiKey?.length() ?: 0}. Expected 20+ characters.")
    }
    
    // Verificar que no contenga texto de error
    if (grafanaApiKey.contains('Generating') || grafanaApiKey.contains('API key') || grafanaApiKey.contains('Error')) {
        error("ERROR: API key appears to contain error text instead of the actual key: ${grafanaApiKey.take(50)}...")
    }
    
    echo "API Key length: ${grafanaApiKey.length()} characters"
    echo "API Key preview: ${grafanaApiKey.take(10)}..."
    
    sh """
        chmod +x jenkins/scripts/migrate-grafana-dashboards.sh
        export AZURE_PROMETHEUS_QUERY_ENDPOINT="${prometheusQueryEndpoint}"
        jenkins/scripts/migrate-grafana-dashboards.sh \
            "${grafanaEndpoint}" \
            "${grafanaApiKey}" \
            "${dashboardsDir}" \
            "${environment}"
    """
    
    echo ""
    echo "✓ Dashboards migrated successfully"
    echo "  Access them at: ${grafanaEndpoint}"
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

/**
 * Verify and fix DCR stream configuration
 * Ensures the DCR has Microsoft-PrometheusMetrics stream configured
 * @param namespace Kubernetes namespace (staging/prod)
 */
def verifyAndFixDcrStream(namespace) {
    echo "========================================="
    echo "Verifying DCR Stream Configuration"
    echo "========================================="
    
    def resourceGroupName = getTerraformOutput(namespace, 'resource_group_name')
    if (!resourceGroupName || resourceGroupName.isEmpty()) {
        error("Cannot verify DCR stream: resource_group_name not found in Terraform outputs")
    }
    
    // Get DCR name
    def dcrName = sh(
        script: """
            az monitor data-collection rule list \
                --resource-group "${resourceGroupName}" \
                --query "[?contains(name, 'prom-dcr')].name" \
                -o tsv 2>/dev/null | head -1 || echo ""
        """,
        returnStdout: true
    ).trim()
    
    if (!dcrName || dcrName.isEmpty()) {
        echo "⚠ DCR not found, will be created by Terraform"
        return
    }
    
    echo "DCR: ${dcrName}"
    
    // Check if stream is configured in dataSources
    def hasStreamInDS = sh(
        script: """
            az monitor data-collection rule show \
                --name "${dcrName}" \
                --resource-group "${resourceGroupName}" \
                --query "dataSources.prometheusForwarder[0].streams[?@ == 'Microsoft-PrometheusMetrics']" \
                -o tsv 2>/dev/null || echo ""
        """,
        returnStdout: true
    ).trim()
    
    // Check if stream is configured in dataFlows
    def hasStreamInFlow = sh(
        script: """
            az monitor data-collection rule show \
                --name "${dcrName}" \
                --resource-group "${resourceGroupName}" \
                --query "dataFlows[0].streams[?@ == 'Microsoft-PrometheusMetrics']" \
                -o tsv 2>/dev/null || echo ""
        """,
        returnStdout: true
    ).trim()
    
    if (hasStreamInDS && hasStreamInFlow) {
        echo "✓ DCR has Microsoft-PrometheusMetrics stream configured correctly"
        return
    }
    
    echo "⚠ DCR is missing Microsoft-PrometheusMetrics stream"
    if (!hasStreamInDS) {
        echo "  - Missing in dataSources"
    }
    if (!hasStreamInFlow) {
        echo "  - Missing in dataFlows"
    }
    
    echo ""
    echo "Forcing Terraform to update the DCR..."
    echo "This will ensure the DCR has the correct stream configuration"
    
    // Force Terraform to refresh and apply
    def envDir = namespace == 'staging' ? 'staging' : 'prod'
    sh """
        cd infra/terraform/environments/${envDir}
        terraform refresh -var-file=${envDir}.tfvars || true
        terraform apply -var-file=${envDir}.tfvars -auto-approve -target=module.monitoring.azurerm_monitor_data_collection_rule.prometheus || {
            echo "Target apply failed, trying full apply..."
            terraform apply -var-file=${envDir}.tfvars -auto-approve || true
        }
    """
    
    // Wait for Azure to propagate changes (DCR updates can take time)
    echo "Waiting 15 seconds for Azure to propagate DCR changes..."
    sleep(15)
    
    // Verify again after apply with retries
    def hasStreamAfter = ""
    def maxRetries = 3
    def retryCount = 0
    
    while (retryCount < maxRetries && (!hasStreamAfter || hasStreamAfter.isEmpty())) {
        if (retryCount > 0) {
            echo "Retry ${retryCount}/${maxRetries}: Waiting 10 more seconds..."
            sleep(10)
        }
        
        hasStreamAfter = sh(
            script: """
                az monitor data-collection rule show \
                    --name "${dcrName}" \
                    --resource-group "${resourceGroupName}" \
                    --query "dataSources.prometheusForwarder[0].streams[?@ == 'Microsoft-PrometheusMetrics']" \
                    -o tsv 2>/dev/null || echo ""
            """,
            returnStdout: true
        ).trim()
        
        retryCount++
    }
    
    // Also verify dataFlows
    def hasStreamInFlowAfter = sh(
        script: """
            az monitor data-collection rule show \
                --name "${dcrName}" \
                --resource-group "${resourceGroupName}" \
                --query "dataFlows[0].streams[?@ == 'Microsoft-PrometheusMetrics']" \
                -o tsv 2>/dev/null || echo ""
        """,
        returnStdout: true
    ).trim()
    
    if (hasStreamAfter && hasStreamInFlowAfter) {
        echo "✓ DCR updated successfully with Microsoft-PrometheusMetrics stream"
        echo "  - Stream configured in dataSources: ✓"
        echo "  - Stream configured in dataFlows: ✓"
    } else {
        echo "⚠ DCR still missing stream after terraform apply"
        if (!hasStreamAfter) {
            echo "  - Missing in dataSources"
        }
        if (!hasStreamInFlowAfter) {
            echo "  - Missing in dataFlows"
        }
        echo "  This may require manual intervention or DCR recreation"
        echo "  Waiting additional 30 seconds for Azure propagation..."
        sleep(30)
    }
    
    echo "========================================="
}

return this