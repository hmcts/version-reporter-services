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

locals {
  service_principal_ids = [
    for service_principal in data.service_principal.service_connection : service_principal.object_id
  ]
}