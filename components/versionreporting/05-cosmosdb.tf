# The cosmosdb account
resource "azurerm_cosmosdb_account" "this" {
  count = var.env == "ptl" ? 1 : 0

  name                = local.cosmosdb_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this[0].name
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
  count = var.env == "ptl" ? 1 : 0

  name                = "reports"
  resource_group_name = azurerm_resource_group.this[0].name
  account_name        = azurerm_cosmosdb_account[0].this.name

  autoscale_settings {
    max_throughput = var.max_throughput
  }
}

# The report containers. One container per report
resource "azurerm_cosmosdb_sql_container" "this" {

  for_each              = var.env == "ptl" ? var.containers_partitions : []
  name                  = each.key
  resource_group_name   = azurerm_resource_group.this[0].name
  account_name          = azurerm_cosmosdb_account[0].this.name
  database_name         = azurerm_cosmosdb_sql_database[0].this.name
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
  count = var.env == "ptl" ? 1 : 0

  resource_group_name = azurerm_resource_group.this[0].name
  account_name        = azurerm_cosmosdb_account[0].this.name
  # Cosmos DB Built-in Data Contributor
  role_definition_id = "${azurerm_cosmosdb_account[0].this.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id       = azurerm_user_assigned_identity.managed_identity.principal_id
  scope              = azurerm_cosmosdb_account[0].this.id
}