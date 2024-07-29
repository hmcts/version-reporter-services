terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "azurerm" {
  alias                      = "managed_identity_infra_subs"
  subscription_id            = local.mi_cft[local.mi_environment].subscription_id
  skip_provider_registration = "true"
  features {}
}

# Used for access to key vault by MIs
provider "azurerm" {
  alias                      = "ptl"
  subscription_id            = "1baf5470-1c3e-40d3-a6f7-74bfbce4b348"
  skip_provider_registration = "true"
  features {}
}


data "terraform_remote_state" "version_reporting" {
  backend = "azurerm"
  config = {
    resource_group_name  = "azure-control-ptl-rg"
    storage_account_name = "c1baf547074bfbce4b348sa"
    container_name       = "subscription-tfstate"
    key                  = "UK South/cft-platform/version-reporter-services/${var.env}/versionreporting/terraform.tfstate"
  }
}
