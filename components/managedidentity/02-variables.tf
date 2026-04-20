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

variable "sbox_metrics_cosmosdb" {
  description = "Flag to determine if the sandbox CosmosDB should be used"
  type        = bool
  default     = false
}

variable "sds_ptl_mi_principal_id" {
  description = "Principal ID of the SDS PTL managed identity. Set by the pipeline from the sdsptl stage output. When non-empty, role assignments for the SDS MI are created in this (ptl) run."
  type        = string
  default     = ""
}