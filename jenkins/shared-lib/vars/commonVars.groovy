#!/usr/bin/env groovy

/**
 * Shared variables for Jenkins pipelines
 * This library contains common configuration used across all environments
 */

def getServicesList() {
    return [ 'user-service', 'product-service', 'favourite-service', 'service-discovery', 'proxy-client', 'api-gateway' ]
}

def getRegistry() {
    return 'docker.io/alejandramantillac'
}

def getDockerHubCredential() {
    return 'dockerhub'
}

return this

