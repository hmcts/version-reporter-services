terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.58.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.4.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "azuread" {
}

provider "azurerm" {
  alias           = "ptlsbox"
  subscription_id = var.ptlsbox_subscription
  features {}
}
