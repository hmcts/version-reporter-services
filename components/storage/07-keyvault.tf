resource "azurerm_key_vault" "version_reporter_key_vault" {
  name                            = format("sds-%s-%s-kv", var.service_name, var.env)
  location                        = var.location
  resource_group_name             = azurerm_resource_group.this.name
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days      = 7
  sku_name                        = "standard"
  tags                            = local.common_tags
  depends_on                      = [azurerm_cosmosdb_account.this]
}

resource "azurerm_key_vault_secret" "cosmos_endpoint" {
  key_vault_id = azurerm_key_vault.version_reporter_key_vault.id
  name         = "cosmos-endpoint"
  value        = azurerm_cosmosdb_account.this.endpoint
}

resource "azurerm_key_vault_secret" "cosmos_key" {
  key_vault_id = azurerm_key_vault.version_reporter_key_vault.id
  name         = "cosmos-key"
  value        = azurerm_cosmosdb_account.this.primary_key
}

resource "azurerm_key_vault_secret" "cosmosdb_database" {
  key_vault_id = azurerm_key_vault.version_reporter_key_vault.id
  name         = "cosmos-db-name"
  value        = azurerm_cosmosdb_account.this.name
}