# The cosmosdb account
resource "azurerm_cosmosdb_account" "this" {
  name                = local.cosmosdb_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  kind                = "GlobalDocumentDB"
  offer_type          = "Standard"

  automatic_failover_enabled = true

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = true
  }
  tags = local.common_tags
}

# The sql database
resource "azurerm_cosmosdb_sql_database" "this" {
  name                = "reports"
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name

  autoscale_settings {
    max_throughput = var.max_throughput
  }
}

# The report containers. One container per report
resource "azurerm_cosmosdb_sql_container" "this" {
  for_each              = var.containers_partitions
  name                  = each.key
  resource_group_name   = azurerm_resource_group.this.name
  account_name          = azurerm_cosmosdb_account.this.name
  database_name         = azurerm_cosmosdb_sql_database.this.name
  partition_key_path    = each.value
  partition_key_version = 2

  autoscale_settings {
    max_throughput = var.max_throughput
  }

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }
  }
}

/*
 * Granting Cosmos DB Built-in Data Contributor to enable read/write permissions to MI
 */
resource "azurerm_cosmosdb_sql_role_assignment" "this" {
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  # Cosmos DB Built-in Data Contributor
  role_definition_id = "${azurerm_cosmosdb_account.this.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id       = module.version_reporter_key_vault.managed_identity_objectid[0]
  scope              = azurerm_cosmosdb_account.this.id
}