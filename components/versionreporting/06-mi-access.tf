data "azurerm_resource_group" "cft_intsvc" {
  name = "managed-identities-cft${env}-intsvc-rg"
}

resource "azurerm_user_assigned_identity" "managed_identity" {

  resource_group_name = data.azurerm_resource_group.cft_intsvc.name
  location            = var.location

  name = "monitoring-cft${env}-intsvc-mi"

  tags = local.common_tags
}

resource "azurerm_key_vault_access_policy" "ptl_implicit_managed_identity_access_policy" {
  count = env =="ptl" ? 1 : 0

  key_vault_id = module.version_reporter_key_vault.key_vault_id

  object_id = azurerm_user_assigned_identity.managed_identity.principal_id
  tenant_id = data.azurerm_client_config.current.tenant_id

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

data "azurerm_key_vault" "ptl_kv" {
  count = env == "sbox" ? 1 : 0

  name                = "${var.service_name}-ptl"
  resource_group_name = "${var.product}-${var.service_name}-ptl-rg"
}


resource "azurerm_key_vault_access_policy" "sbox_implicit_managed_identity_access_policy" {
  count = env == "sbox" ? 1 : 0
  
  key_vault_id = data.azurerm_key_vault.ptl_kv.id

  object_id = azurerm_user_assigned_identity.managed_identity.principal_id
  tenant_id = data.azurerm_client_config.current.tenant_id

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
#   member_object_id = module.version_reporter_key_vault.managed_identity_objectid[0]
# }