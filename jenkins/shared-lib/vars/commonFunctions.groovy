#!/usr/bin/env groovy

/**
 * Shared functions for Jenkins pipelines
 * This library contains common utility functions used across all environments
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
    def servicePaths = services.join(',')
    
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