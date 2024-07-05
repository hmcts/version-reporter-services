locals {
  service_principal_names = [
    "DCD-CFTAPPS-SBOX",
    "DCD-CFTAPPS-DEV",
    "DCD-CFTAPPS-DEMO",
    "DCD-CFTAPPS-ITHC",
    "DTS-CFTSBOX-INTSVC",
    "DCD-CFTAPPS-TEST",
    "DCD-CFTAPPS-STG",
    "DTS-CFTPTL-INTSVC",
    "DCD-CFTAPPS-PROD",
  ]
}

data "azuread_service_principal" "service_connection" {
  for_each     = toset(local.service_principal_names)
  display_name = each.value
}

locals {
  service_principal_ids = [
    for service_principal in data.azuread_service_principal.service_connection : service_principal.object_id
  ]
}
