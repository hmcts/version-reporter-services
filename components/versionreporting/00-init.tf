terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 1.4.6"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.15.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "azuread" {
}