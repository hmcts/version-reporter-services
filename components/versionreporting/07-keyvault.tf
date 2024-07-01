module "version_reporter_key_vault" {
  count = var.env == "ptl" ? 1 : 0

  source = "github.com/hmcts/cnp-module-key-vault?ref=master"

  product                 = var.service_name
  env                     = var.env
  object_id               = data.azurerm_client_config.current.object_id
  resource_group_name     = azurerm_resource_group.this[0].name
  product_group_name      = "DTS Platform Operations"
  create_managed_identity = false
  common_tags             = local.common_tags
}

resource "azurerm_key_vault_secret" "cosmos_endpoint" {
  count = var.env == "ptl" ? 1 : 0

  key_vault_id = module.version_reporter_key_vault[0].key_vault_id
  name         = "cosmos-endpoint"
  value        = azurerm_cosmosdb_account.this[0].endpoint
}

resource "azurerm_key_vault_secret" "cosmos_key" {
  count = var.env == "ptl" ? 1 : 0

  key_vault_id = module.version_reporter_key_vault[0].key_vault_id
  name         = "cosmos-key"
  value        = azurerm_cosmosdb_account.this[0].primary_key
}

resource "azurerm_key_vault_secret" "cosmosdb_database_name" {
  count = var.env == "ptl" ? 1 : 0

  key_vault_id = module.version_reporter_key_vault[0].key_vault_id
  name         = "cosmos-db-name"
  value        = azurerm_cosmosdb_sql_database.this[0].name
}