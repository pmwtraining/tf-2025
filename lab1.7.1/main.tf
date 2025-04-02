terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.1"
    }
  }
  backend "azurerm" {
    resource_group_name  = "tf-state-rgpm"
    storage_account_name = "tfstatesapm"
    container_name       = "tfstatepm"
    key                  = "dev.terraform.tfstate"
  }

}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "state-demo-secure" {
  name     = "state-demo"
  location = "uksouth"
}
