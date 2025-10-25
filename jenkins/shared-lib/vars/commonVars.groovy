#!/usr/bin/env groovy

/**
 * Shared variables for Jenkins pipelines
 * Single source of truth for all service configurations
 */

def getServicesList() {
    return [
        // ========================================
        // Business Services (ClusterIP)
        // ========================================
        [
            name: 'user-service',
            port: 8700,
            type: 'business',
            path: 'user-service',
            exposure: [
                dev: [type: 'ClusterIP'],
                staging: [type: 'ClusterIP'],
                prod: [type: 'ClusterIP']
            ],
            resources: [
                memRequest: '384Mi',
                memLimit: '512Mi',
                cpuRequest: '250m',
                cpuLimit: '500m'
            ],
            healthPath: '/user-service/actuator/health',
            replicas: [dev: 1, staging: 1, prod: 2]
        ],

        [
            name: 'product-service',
            port: 8500,
            type: 'business',
            path: 'product-service',
            exposure: [
                dev: [type: 'ClusterIP'],
                staging: [type: 'ClusterIP'],
                prod: [type: 'ClusterIP']
            ],
            resources: [
                memRequest: '384Mi',
                memLimit: '512Mi',
                cpuRequest: '250m',
                cpuLimit: '500m'
            ],
            healthPath: '/product-service/actuator/health',
            replicas: [dev: 1, staging: 1, prod: 2]
        ],

        [
            name: 'favourite-service',
            port: 8400,
            type: 'business',
            path: 'favourite-service',
            exposure: [
                dev: [type: 'ClusterIP'],
                staging: [type: 'ClusterIP'],
                prod: [type: 'ClusterIP']
            ],
            resources: [
                memRequest: '256Mi',
                memLimit: '384Mi',
                cpuRequest: '250m',
                cpuLimit: '500m'
            ],
            healthPath: '/favourite-service/actuator/health',
            replicas: [dev: 1, staging: 1, prod: 2]
        ],

        [
            name: 'proxy-client',
            port: 8900,
            type: 'business',
            path: 'proxy-client',
            exposure: [
                dev: [type: 'ClusterIP'],
                staging: [type: 'ClusterIP'],
                prod: [type: 'ClusterIP']
            ],
            resources: [
                memRequest: '384Mi',
                memLimit: '512Mi',
                cpuRequest: '250m',
                cpuLimit: '500m'
            ],
            healthPath: '/proxy-client/actuator/health',
            replicas: [dev: 1, staging: 1, prod: 2]
        ],

        // ========================================
        // Core Services (Exposed)
        // ========================================
        [
            name: 'service-discovery',
            port: 8761,
            type: 'core',
            path: 'service-discovery',
            exposure: [
                dev: [
                    type: 'NodePort',
                    nodePort: 30187
                ],
                staging: [
                    type: 'NodePort',
                    nodePort: 30187
                ],
                prod: [
                    type: 'NodePort',
                    nodePort: 30087
                ]
            ],
            resources: [
                memRequest: '384Mi',
                memLimit: '512Mi',
                cpuRequest: '250m',
                cpuLimit: '500m'
            ],
            healthPath: '/actuator/health',
            replicas: [dev: 1, staging: 1, prod: 1]  // Eureka no se debe escalar
        ],

        [
            name: 'api-gateway',
            port: 8080,
            type: 'core',
            path: 'api-gateway',
            exposure: [
                dev: [
                    type: 'NodePort',
                    nodePort: 30180
                ],
                staging: [
                    type: 'LoadBalancer',
                    externalPort: 9080,
                    nodePort: 30180
                ],
                prod: [
                    type: 'LoadBalancer',
                    externalPort: 8080,
                    nodePort: 30080
                ]
            ],
            resources: [
                memRequest: '384Mi',
                memLimit: '512Mi',
                cpuRequest: '250m',
                cpuLimit: '500m'
            ],
            healthPath: '/actuator/health',
            replicas: [dev: 1, staging: 1, prod: 3]
        ],

        // ========================================
        // Monitoring Services
        // ========================================
        [
            name: 'zipkin',
            port: 9411,
            type: 'monitoring',
            path: 'zipkin',
            external: true,
            exposure: [
                dev: [
                    type: 'NodePort',
                    nodePort: 30941
                ],
                staging: [
                    type: 'LoadBalancer',
                    nodePort: 30941
                ],
                prod: [
                    type: 'LoadBalancer',
                    nodePort: 30941
                ]
            ],
            resources: [
                memRequest: '256Mi',
                memLimit: '512Mi',
                cpuRequest: '250m',
                cpuLimit: '500m'
            ],
            healthPath: '/health',
            replicas: [dev: 1, staging: 1, prod: 1]
        ]
    ]
}

// ========================================
// Helper Methods
// ========================================

def getServiceConfig(serviceName) {
    def services = getServicesList()
    return services.find { it.name == serviceName }
}

def getServicesByType(type) {
    def services = getServicesList()
    return services.findAll { it.type == type }
}

def getCoreServices() {
    return getServicesByType('core')
}

def getBusinessServices() {
    return getServicesByType('business')
}

def getMonitoringServices() {
    return getServicesByType('monitoring')
}

def getServiceExposure(serviceName, environment) {
    def service = getServiceConfig(serviceName)
    return service?.exposure?.get(environment)
}

// ========================================
// Credentials & Configuration
// ========================================

def getRegistry() {
    return 'docker.io/alejandramantillac'
}

def getDockerHubCredential() {
    return 'dockerhub'
}

def getKubeConfigCredential() {
    return 'kubeconfig'
}

def getNamespaces() {
    return [
        dev: 'dev',
        staging: 'staging',
        prod: 'prod'
    ]
}

return this