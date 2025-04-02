#lab1.9

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.1"
    }
  }
}

provider "azurerm" {
  features {}

  storage_use_azuread = true
}
