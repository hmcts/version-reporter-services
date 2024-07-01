data "azurerm_resource_group" "cftsbox_intsvc" {
  provider = azurerm.ptlsbox
  name     = "managed-identities-cftsbox-intsvc-rg"
}

resource "azurerm_user_assigned_identity" "ptlsbox_managed_identity" {
  provider = azurerm.ptlsbox

  resource_group_name = data.azurerm_resource_group.cftsbox_intsvc.name
  location            = var.location

  name = "monitoring-cftsbox-intsvc-mi"

  tags = local.common_tags
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