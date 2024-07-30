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

provider "azurerm" {
  alias                      = "pipeline_metrics"
  subscription_id            = local.mi_cft["prod"].subscription_id
  skip_provider_registration = "true"
  features {}
}

provider "azurerm" {
  alias                      = "sandbox_pipeline_metrics"
  subscription_id            = local.mi_cft["sandbox"].subscription_id
  skip_provider_registration = "true"
  features {}
}

provider "azurerm" {
  alias                      = "sds_jenkins_pipeline_metrics"
  subscription_id            = local.mi_cft["jenkins_prod"].subscription_id
  skip_provider_registration = "true"
  features {}
}

provider "azurerm" {
  alias                      = "sds_jenkins_pipeline_metrics_sbox"
  subscription_id            = local.mi_cft["jenkins_sbox"].subscription_id
  skip_provider_registration = "true"
  features {}
}
