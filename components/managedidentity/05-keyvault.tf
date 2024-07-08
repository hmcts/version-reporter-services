data "azurerm_key_vault" "ptl" {
  provider            = azurerm.ptl
  name                = var.kvName
  resource_group_name = var.kvRgName
}
