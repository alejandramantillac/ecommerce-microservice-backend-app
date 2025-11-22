terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "state" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = var.account_replication_type
  https_traffic_only_enabled = true
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
    change_feed_enabled = true
  }

  tags = merge(var.tags, {
    Purpose = "terraform-backend"
  })
}

resource "azurerm_storage_container" "state" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}