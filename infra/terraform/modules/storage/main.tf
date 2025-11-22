resource "azurerm_storage_account" "this" {
  name                      = var.storage_account_name
  resource_group_name       = var.resource_group_name
  location                  = var.location
  account_tier              = "Standard"
  account_replication_type  = var.replication_type
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"

  blob_properties {
    versioning_enabled = var.enable_versioning
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Name = var.storage_account_name
  })
}

resource "azurerm_storage_container" "artifact" {
  count                 = var.artifact_container_name != null ? 1 : 0
  name                  = var.artifact_container_name
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "logs" {
  count                 = var.logs_container_name != null ? 1 : 0
  name                  = var.logs_container_name
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

