module "version_reporter_key_vault" {
  source = "github.com/hmcts/cnp-module-key-vault?ref=master"

  product                     = var.service_name
  env                         = var.env
  object_id                   = data.azurerm_client_config.current.object_id
  resource_group_name         = azurerm_resource_group.this.name
  product_group_name          = "DTS Platform Operations"
  create_managed_identity     = false
  common_tags                 = local.common_tags
  managed_identity_object_ids = [
    azurerm_user_assigned_identity.managed_identity.principal_id,
    azurerm_user_assigned_identity.ptlsbox_managed_identity.principal_id
  ]
}

resource "azurerm_key_vault_secret" "cosmos_endpoint" {
  key_vault_id = module.version_reporter_key_vault.key_vault_id
  name         = "cosmos-endpoint"
  value        = azurerm_cosmosdb_account.this.endpoint
}

resource "azurerm_key_vault_secret" "cosmos_key" {
  key_vault_id = module.version_reporter_key_vault.key_vault_id
  name         = "cosmos-key"
  value        = azurerm_cosmosdb_account.this.primary_key
}

resource "azurerm_key_vault_secret" "cosmosdb_database_name" {
  key_vault_id = module.version_reporter_key_vault.key_vault_id
  name         = "cosmos-db-name"
  value        = azurerm_cosmosdb_sql_database.this.name
}