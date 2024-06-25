data "azuread_group" "reader_access_group" {
  display_name     = "DTS Readers (mg:HMCTS)"
  security_enabled = true
}

# Service connection does not have enough access to grant this via automation
# The addition of the MI to the group has been completed manually and the code commented here to limit failures
# The code is being left here for reference and understand if required in future
# resource "azuread_group_member" "group_membership" {
#   group_object_id  = data.azuread_group.reader_access_group.id
#   member_object_id = module.version_reporter_key_vault.managed_identity_objectid[0]
# }