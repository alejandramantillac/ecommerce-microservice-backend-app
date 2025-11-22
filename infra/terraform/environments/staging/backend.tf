terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateecomstore"
    container_name       = "tfstate"
    key                  = "staging.terraform.tfstate"
  }
}

