data "azurerm_resource_group" "managed_identities" {
  name = "managed-identities-${local.mi_environment}-rg"
}

resource "azurerm_user_assigned_identity" "managed_identity" {
  resource_group_name = data.azurerm_resource_group.managed_identities.name
  location            = var.location

  name = "monitoring-${local.mi_environment}-mi"

  tags = local.common_tags
}

resource "azurerm_key_vault_access_policy" "managed_identity_access_policy" {
  provider     = azurerm.ptl
  key_vault_id = data.azurerm_key_vault.ptl
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