# General
locals {
  storage_name = format("%s-%s", var.product, var.service_name)
  readers = {
    ptl_stg  = "74dacd4f-a248-45bb-a2f0-af700dc4cf68",
    ptl_test = "3eec5bde-7feb-4566-bfb6-805df6e10b90",
    ptl_demo = "c68a4bed-4c3d-4956-af51-4ae164c1957c",
    ptl_ithc = "ba71a911-e0d6-4776-a1a6-079af1df7139",
    ptl_prod = "5ca62022-6aa2-4cee-aaa7-e7536c8d566c",
    ptl_dev  = "867a878b-cb68-4de5-9741-361ac9e178b6"
    ptl_sbox = "a8140a9e-f1b0-481f-a4de-09e2ee23f7ab"
    hub_sbox    = "ea3a8c1e-af9d-4108-bc86-a7e2d267f49c"
    hub_nonprod = "fb084706-583f-4c9a-bdab-949aac66ba5c"
    hub_prod    = "0978315c-75fe-4ada-9d11-1eb5e0e0b214"
  }
  common_tags = module.ctags.common_tags
}

# Common tags
module "ctags" {
  source       = "github.com/hmcts/terraform-module-common-tags"
  builtFrom    = var.builtFrom
  environment  = var.env
  product      = var.product
  expiresAfter = var.expiresAfter
}
