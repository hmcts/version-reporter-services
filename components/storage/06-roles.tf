data "azurerm_client_config" "current" {}

data "azurerm_subscription" "sub" {
  subscription_id = data.azurerm_client_config.current.subscription_id
}

data "azurerm_resource_group" "this" {
  name = "managed-identities-${var.env}-rg"
}

# User Managed Identity to be used ber the version reporter applications
resource "azurerm_user_assigned_identity" "this" {
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.location
  name                = "version-reporter-${var.env}-mi"
  tags                = module.ctags.common_tags
}

resource "azurerm_role_assignment" "this" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}
