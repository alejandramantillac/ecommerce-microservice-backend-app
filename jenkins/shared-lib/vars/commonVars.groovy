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
            replicas: [dev: 1, staging: 1, prod: 1]
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
            replicas: [dev: 1, staging: 1, prod: 1]
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
            replicas: [dev: 1, staging: 1, prod: 1]
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
            healthPath: '/app/actuator/health',
            replicas: [dev: 1, staging: 1, prod: 1]
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
            replicas: [dev: 1, staging: 1, prod: 1]
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
                    nodePort: 30942
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
        ],

        [
            name: 'prometheus',
            port: 9090,
            type: 'monitoring',
            path: 'prometheus',
            external: true,
            exposure: [
                dev: [
                    type: 'NodePort',
                    nodePort: 30909
                ],
                staging: [
                    type: 'NodePort',
                    nodePort: 30909
                ],
                prod: [
                    type: 'LoadBalancer',
                    nodePort: 30909
                ]
            ],
            resources: [
                memRequest: '512Mi',
                memLimit: '2Gi',
                cpuRequest: '250m',
                cpuLimit: '1000m'
            ],
            healthPath: '/-/healthy',
            replicas: [dev: 1, staging: 1, prod: 1]
        ],

        [
            name: 'grafana',
            port: 3000,
            type: 'monitoring',
            path: 'grafana',
            external: true,
            exposure: [
                dev: [
                    type: 'NodePort',
                    nodePort: 30300
                ],
                staging: [
                    type: 'NodePort',
                    nodePort: 30300
                ],
                prod: [
                    type: 'LoadBalancer',
                    nodePort: 30300
                ]
            ],
            resources: [
                memRequest: '256Mi',
                memLimit: '512Mi',
                cpuRequest: '100m',
                cpuLimit: '500m'
            ],
            healthPath: '/api/health',
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

def getGitHubTokenCredential() {
    return 'github-token'
}

def getNamespaces() {
    return [
        dev: 'dev',
        staging: 'staging',
        prod: 'prod'
    ]
}

def getSonarHostUrl() {
    return 'https://sonarcloud.io'
}

def getSonarOrganization() {
    return 'alejandramantillac'
}

// SonarQube Quality Gate Configuration
def getSonarEnforceQualityGate() {
    return 'true'
}

// Trivy Configuration
def getTrivySeverityThreshold() {
    return 'CRITICAL,HIGH'
}

def getTrivyExitOnFailure() {
    return 'false'
}

def getTrivyReportFormat() {
    return 'json'
}

def getNotificationConfig() {
    return [
        enabled: 'true',
        channel: 'slack',
        slack: [
            credentialId: 'slack-hook-url',
            channel: 'jenkins',
            username: 'Jenkins CI',
            iconEmoji: ':rocket:'
        ]
    ]
}

def getServiceCodeOwners() {
    def defaultSlackMention = '@María Alejandra Mantilla'

    return [
        'user-service': [
            slack: '@Andrés Parra',
        ],
        'product-service': [
            slack: defaultSlackMention,
        ],
        'favourite-service': [
            slack: defaultSlackMention,
        ],
        'proxy-client': [
            slack: defaultSlackMention,
        ],
        'service-discovery': [
            slack: defaultSlackMention,
        ],
        'api-gateway': [
            slack: defaultSlackMention,
        ],
        'zipkin': [
            slack: defaultSlackMention,
        ]
    ]
}

def getCodeOwner(serviceName) {
    def owners = getServiceCodeOwners()
    return owners.get(serviceName)
}

return this