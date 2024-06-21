# Data lookups
data "azurerm_client_config" "current" {}

# General
locals {
  cosmosdb_name = format("%s-%s-cosmos", var.service_name, var.environment)
  keyvault_name = format("%s-%s-kv", var.service_name, var.environment)
  common_tags   = module.ctags.common_tags
}

# Common tags
module "ctags" {
  source       = "github.com/hmcts/terraform-module-common-tags"
  builtFrom    = var.builtFrom
  environment  = var.environment
  product      = var.product
  expiresAfter = var.expiresAfter
}
