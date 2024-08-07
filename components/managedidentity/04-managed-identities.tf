data "azurerm_resource_group" "managed_identities" {
  provider = azurerm.managed_identity_infra_subs
  name     = "managed-identities-${local.mi_environment}-rg"
}

resource "azurerm_user_assigned_identity" "managed_identity" {
  provider            = azurerm.managed_identity_infra_subs
  resource_group_name = data.azurerm_resource_group.managed_identities.name
  location            = var.location

  name = "monitoring-${local.mi_environment}-mi"

  tags = local.common_tags
}

resource "azurerm_key_vault_access_policy" "managed_identity_access_policy" {
  provider     = azurerm.ptl
  key_vault_id = data.azurerm_key_vault.ptl.id
  object_id    = azurerm_user_assigned_identity.managed_identity.principal_id
  tenant_id    = data.azurerm_client_config.current.tenant_id

  key_permissions = [
    "Get",
    "List",
  ]

  certificate_permissions = [
    "Get",
    "List",
  ]

  secret_permissions = [
    "Get",
    "List",
  ]
}

data "azurerm_cosmosdb_account" "version_reporter" {
  provider            = azurerm.ptl
  name                = "version-reporter-ptl-cosmos"
  resource_group_name = "cft-platform-version-reporter-ptl-rg"
}

resource "azurerm_cosmosdb_sql_role_assignment" "identity_contributor" {
  provider            = azurerm.ptl
  resource_group_name = data.azurerm_cosmosdb_account.version_reporter.resource_group_name
  account_name        = data.azurerm_cosmosdb_account.version_reporter.name
  # Cosmos DB Built-in Data Contributor
  role_definition_id = "${data.azurerm_cosmosdb_account.version_reporter.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id       = azurerm_user_assigned_identity.managed_identity.principal_id
  scope              = data.azurerm_cosmosdb_account.version_reporter.id
}

data "azurerm_cosmosdb_account" "pipeline_metrics" {
  provider            = azurerm.pipeline-metrics
  name                = local.cosmosdb_name
  resource_group_name = local.cosmosdb_rg
}

resource "azurerm_cosmosdb_sql_role_assignment" "monitoring_mi_assignment" {
  provider            = azurerm.pipeline-metrics
  resource_group_name = data.azurerm_cosmosdb_account.pipeline_metrics.resource_group_name
  account_name        = data.azurerm_cosmosdb_account.pipeline_metrics.name
  role_definition_id  = "${data.azurerm_cosmosdb_account.pipeline_metrics.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_user_assigned_identity.managed_identity.principal_id
  scope               = data.azurerm_cosmosdb_account.pipeline_metrics.id
}

# Service connection does not have enough access to grant this via automation
# The addition of the MI to the group has been completed manually and the code commented here to limit failures
# The code is being left here for reference and understand if required in future

# data "azuread_group" "reader_access_group" {
#   display_name     = "DTS Readers (mg:HMCTS)"
#   security_enabled = true
# }

# resource "azuread_group_member" "group_membership" {
#   group_object_id  = data.azuread_group.reader_access_group.id
#   member_object_id = azurerm_user_assigned_identity.ptlsbox_managed_identity.principal_id
# }