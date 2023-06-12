terraform {
  required_version = ">= 1.4.6"
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

