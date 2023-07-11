# General
locals {
  storage_name  = format("%s-%s", var.product, var.service_name)
  keyvault_name = format("sds%s%skv", replace(var.service_name, "-", ""), var.env)
  common_tags   = module.ctags.common_tags
}

# Common tags
module "ctags" {
  source       = "github.com/hmcts/terraform-module-common-tags"
  builtFrom    = var.builtFrom
  environment  = var.env
  product      = var.product
  expiresAfter = var.expiresAfter
}
