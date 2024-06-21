data "azuread_group" "reader_access_group" {
  display_name     = "DTS Readers"
  security_enabled = true
}

resource "azuread_group_member" "group_membership" {
  group_object_id  = data.azuread_group.reader_access_group.id
  member_object_id = module.version_reporter_key_vault.managed_identity_objectid
}