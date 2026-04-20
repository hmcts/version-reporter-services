# Data lookups
data "azurerm_client_config" "current" {}

# General
locals {
  common_tags = module.ctags.common_tags
}

# Common tags
module "ctags" {
  source       = "github.com/hmcts/terraform-module-common-tags"
  builtFrom    = var.builtFrom
  environment  = local.ctags_environment
  product      = var.product
  expiresAfter = var.expiresAfter
}
