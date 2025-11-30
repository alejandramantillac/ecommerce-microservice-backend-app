terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

locals {
  # Sanitizar nombres para cumplir con restricciones de Azure
  name_prefix_short = replace(replace(lower(var.name_prefix), "ecommerce", "ecom"), "staging", "stg")
  
  # Container Apps Environment
  container_app_env_name = "${local.name_prefix_short}-elk-env"
  
  # Container Apps
  elasticsearch_app_name = "${local.name_prefix_short}-elasticsearch"
  logstash_app_name      = "${local.name_prefix_short}-logstash"
  kibana_app_name        = "${local.name_prefix_short}-kibana"
}

# Registrar Microsoft.App para Azure Container Apps
# Nota: Este provider NO se registra automáticamente, debe registrarse manualmente
# Microsoft.OperationalInsights se registra automáticamente por Terraform, no necesita registro manual
resource "azurerm_resource_provider_registration" "app" {
  name = "Microsoft.App"
  
  lifecycle {
    # Evitar que Terraform intente desregistrar el provider
    prevent_destroy = true
  }
}

# Log Analytics Workspace para logs de Container Apps
resource "azurerm_log_analytics_workspace" "elk" {
  name                = "${local.name_prefix_short}-elk-logs"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Container Apps Environment (entorno compartido para todas las apps)
# Depende del registro del provider Microsoft.App
resource "azurerm_container_app_environment" "elk" {
  name                       = local.container_app_env_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.elk.id
  
  depends_on = [
    azurerm_resource_provider_registration.app
  ]
  
  # Integración con VNet para conectividad privada con AKS (opcional)
  # Nota: Si se proporciona, la subnet debe estar dedicada para Container Apps
  # y no puede compartirse con otros recursos como AKS
  # Por ahora, dejamos esto vacío para que Container Apps funcione sin integración VNet
  # Se puede agregar más adelante si se necesita conectividad privada
  
  tags = var.tags
}

# Container App: Elasticsearch
resource "azurerm_container_app" "elasticsearch" {
  name                         = local.elasticsearch_app_name
  container_app_environment_id = azurerm_container_app_environment.elk.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  
  # Configuración del contenedor
  template {
    min_replicas = var.elasticsearch_replicas
    max_replicas = var.elasticsearch_replicas
    
    container {
      name   = "elasticsearch"
      image  = "docker.elastic.co/elasticsearch/elasticsearch:8.11.0"
      cpu    = var.elasticsearch_cpu
      memory = var.elasticsearch_memory
      
      env {
        name  = "cluster.name"
        value = "ecommerce-microservices"
      }
      env {
        name  = "node.name"
        value = "elasticsearch"
      }
      env {
        name  = "discovery.type"
        value = "single-node"
      }
      env {
        name  = "ES_JAVA_OPTS"
        value = "-Xms${var.elasticsearch_java_heap}m -Xmx${var.elasticsearch_java_heap}m"
      }
      env {
        name  = "bootstrap.memory_lock"
        value = "false"
      }
      env {
        name  = "xpack.security.enabled"
        value = "false"
      }
      env {
        name  = "xpack.security.enrollment.enabled"
        value = "false"
      }
      env {
        name  = "xpack.security.http.ssl.enabled"
        value = "false"
      }
      env {
        name  = "xpack.security.transport.ssl.enabled"
        value = "false"
      }
      env {
        name  = "xpack.monitoring.collection.enabled"
        value = "true"
      }
      env {
        name  = "action.auto_create_index"
        value = "true"
      }
    }
  }
  
  # Exponer puerto HTTP
  ingress {
    external_enabled = var.elasticsearch_public_access
    target_port      = 9200
    transport        = "http"
    allow_insecure_connections = true
    
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  tags = var.tags
}

# Container App: Logstash
# NOTA: Logstash necesita acceso a Elasticsearch. Si elasticsearch_public_access = false,
# Logstash no podrá conectarse desde Azure Container Apps debido a limitaciones de red.
# Soluciones:
# 1. Habilitar elasticsearch_public_access = true
# 2. Configurar VNet integration para Container Apps
# 3. Usar Filebeat directamente a Elasticsearch (recomendado si no necesitas procesamiento de Logstash)
resource "azurerm_container_app" "logstash" {
  name                         = local.logstash_app_name
  container_app_environment_id  = azurerm_container_app_environment.elk.id
  resource_group_name           = var.resource_group_name
  revision_mode                 = "Single"
  
  # Depende de Elasticsearch
  depends_on = [azurerm_container_app.elasticsearch]
  
  template {
    min_replicas = var.logstash_replicas
    max_replicas = var.logstash_replicas
    
    container {
      name   = "logstash"
      image  = "docker.elastic.co/logstash/logstash:8.11.0"
      cpu    = var.logstash_cpu
      memory = var.logstash_memory
      
      # Determinar el endpoint de Elasticsearch
      # Si elasticsearch_public_access = true, usar HTTPS con el FQDN público
      # Azure Container Apps expone servicios públicamente vía HTTPS en puerto 443
      # El ingress mapea automáticamente HTTPS:443 -> HTTP:9200 internamente
      # Si no está disponible, intentar usar endpoint interno (puede no funcionar sin VNet integration)
      env {
        name  = "ELASTICSEARCH_ENDPOINT"
        value = var.elasticsearch_public_access && azurerm_container_app.elasticsearch.ingress[0].fqdn != null && azurerm_container_app.elasticsearch.ingress[0].fqdn != "" ? "https://${azurerm_container_app.elasticsearch.ingress[0].fqdn}" : "http://${azurerm_container_app.elasticsearch.name}.${azurerm_container_app_environment.elk.default_domain}:9200"
      }
      env {
        name  = "ELASTICSEARCH_USE_SSL"
        value = var.elasticsearch_public_access ? "true" : "false"
      }
      # Variables para configuración de monitoreo de Logstash
      # IMPORTANTE: Desde dentro del mismo Container Apps Environment, usar el endpoint interno
      # El endpoint interno debería funcionar sin problemas de DNS/resolución
      # Formato: http://app-name.environment-default-domain:port
      env {
        name  = "XPACK_MONITORING_ELASTICSEARCH_HOSTS"
        value = "http://${azurerm_container_app.elasticsearch.name}.${azurerm_container_app_environment.elk.default_domain}:9200"
      }
      # Configurar Java para aceptar certificados SSL cuando se usa HTTPS
      # Azure Container Apps usa certificados válidos, pero Java puede necesitar configuración adicional
      env {
        name  = "LS_JAVA_OPTS"
        value = var.elasticsearch_public_access ? "-Djavax.net.ssl.trustStoreType=JKS" : ""
      }
      
    }
  }
  
  tags = var.tags
}

# Container App: Kibana
resource "azurerm_container_app" "kibana" {
  name                         = local.kibana_app_name
  container_app_environment_id  = azurerm_container_app_environment.elk.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  
  # Depende de Elasticsearch
  depends_on = [azurerm_container_app.elasticsearch]
  
  template {
    min_replicas = var.kibana_replicas
    max_replicas = var.kibana_replicas
    
    container {
      name   = "kibana"
      image  = "docker.elastic.co/kibana/kibana:8.11.0"
      cpu    = var.kibana_cpu
      memory = var.kibana_memory
      
      # Usar endpoint público HTTPS si está disponible (requiere elasticsearch_public_access = true)
      # Azure Container Apps expone servicios públicamente vía HTTPS en puerto 443
      # El ingress mapea automáticamente HTTPS:443 -> HTTP:9200 internamente
      # Si no está disponible, intentar usar endpoint interno (puede no funcionar sin VNet integration)
      env {
        name  = "ELASTICSEARCH_HOSTS"
        value = var.elasticsearch_public_access && azurerm_container_app.elasticsearch.ingress[0].fqdn != null && azurerm_container_app.elasticsearch.ingress[0].fqdn != "" ? "https://${azurerm_container_app.elasticsearch.ingress[0].fqdn}" : "http://${azurerm_container_app.elasticsearch.name}.${azurerm_container_app_environment.elk.default_domain}:9200"
      }
      env {
        name  = "SERVER_NAME"
        value = "${local.kibana_app_name}.${azurerm_container_app_environment.elk.default_domain}"
      }
      env {
        name  = "SERVER_PUBLICBASEURL"
        value = var.kibana_public_access ? "https://${local.kibana_app_name}.${azurerm_container_app_environment.elk.default_domain}" : "http://${local.kibana_app_name}.${azurerm_container_app_environment.elk.default_domain}"
      }
    }
  }
  
  # Exponer puerto HTTP
  ingress {
    external_enabled = var.kibana_public_access
    target_port      = 5601
    transport        = "http"
    allow_insecure_connections = true
    
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  tags = var.tags
}

