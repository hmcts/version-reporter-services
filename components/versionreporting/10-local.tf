locals {
  service_principal_names = [
    "DTS Bootstrap (sub:dcd-cftapps-sbox)",
    "DTS Bootstrap (sub:dcd-cftapps-dev)",
    "DTS Bootstrap (sub:dcd-cftapps-demo)",
    "DTS Bootstrap (sub:dcd-cftapps-ithc)",
    "DTS Bootstrap (sub:dts-cftsbox-intsvc)",
    "DTS Bootstrap (sub:dcd-cftapps-test)",
    "DTS Bootstrap (sub:dcd-cftapps-stg)",
    "DTS Bootstrap (sub:dts-cftptl-intsvc)",
    "DTS Bootstrap (sub:dcd-cftapps-prod)"
  ]
}

data "azuread_service_principal" "service_connection" {
  for_each     = toset(local.service_principal_names)
  display_name = each.value
}

locals {
  service_principal_ids = {
    for name, sp in data.azuread_service_principal.service_connection : name => sp.object_id
  }
}