# The resource group
resource "azurerm_resource_group" "this" {
  count = env == "ptl" ? 1 : 0
  
  name     = format("%s-%s-%s-rg", var.product, var.service_name, var.env)
  location = var.location
  tags     = local.common_tags
}