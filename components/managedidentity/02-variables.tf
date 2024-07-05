variable "location" {
  default = "uksouth"
}

variable "env" {
  default = "ptl"
}

variable "builtFrom" {
  default = "hmcts/version-reporter-services"
}

variable "kvName" {
  default = "version-reporter-ptl"
}

variable "kvRgName" {
  default = "cft-platform-version-reporter-ptl-rg"
}

variable "expiresAfter" {
  default = "3000-01-01"
}

variable "product" {
  type    = string
  default = "version-reporter"
}

variable "service_name" {
  type    = string
  default = "version-reporter"
}

variable "service_connections" {
  type = map(string)
  default = {
    "DCD-CFTAPPS-SBOX"  = "service_connection_sbox"
    "DCD-CFTAPPS-DEV"   = "service_connection_preview"
    "DCD-CFTAPPS-DEMO"  = "service_connection_demo"
    "DCD-CFTAPPS-ITHC"  = "service_connection_ithc"
    "DTS-CFTSBOX-INTSVC"= "service_connection_ptlsbox"
    "DCD-CFTAPPS-TEST"  = "service_connection_perftest"
    "DCD-CFTAPPS-STG"   = "service_connection_aat"
    "DTS-CFTPTL-INTSVC" = "service_connection_ptl"
    "DCD-CFTAPPS-PROD"  = "service_connection_prod"
  }
}