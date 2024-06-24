# The resource group
resource "azurerm_resource_group" "this" {
  name     = format("%s-%s-%s-rg", var.product, var.service_name, var.env)
  location = var.location
  tags     = local.common_tags
}