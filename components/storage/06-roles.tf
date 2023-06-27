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

/*
 * Granting the MI Contributor, User Access Administrator and Reader to various
 * subscriptions to enable permissions to carry out relevant operations to retrive data
*/
resource "azurerm_role_assignment" "miroles" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_role_assignment" "sub_id_user_reader" {
  for_each             = local.readers
  scope                = "/subscriptions/${each.value}"
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

/*
 * Granting Cosmos DB Built-in Data Contributor to enable read/write permissions to MI
 */
resource "azurerm_cosmosdb_sql_role_assignment" "this" {
  resource_group_name = azurerm_cosmosdb_account.this.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  # Cosmos DB Built-in Data Contributor
  role_definition_id = "${azurerm_cosmosdb_account.this.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id       = azurerm_user_assigned_identity.this.principal_id
  scope              = azurerm_cosmosdb_account.this.id
}
