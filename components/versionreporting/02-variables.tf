variable "location" {
  default = "uksouth"
}

variable "env" {
  default = "ptl"
}

variable "builtFrom" {
  default = "hmcts/version-reporter-services"
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

variable "max_throughput" {
  default     = "4000"
  description = "The Maximum throughput of SQL database (RU/s)."
}

/*
 * Define your partition and partition key based on your reports need
 * partition name should be the same as the report name
 * partition key should be based on the shape of the data stored
*/
variable "containers_partitions" {
  type        = map(any)
  description = "Partition Keys for corresponding database containers."
  default = {
    paloalto     = "/resourceType"
    helmcharts   = "/namespace"
    renovate     = "/repository"
    docsoutdated = "/docTitle"
    aksversions  = "/clusterName"
    platopsapps  = "/appName"
    cveinfo      = "/dateReserved"
    netflow      = "/netflow"
  }
}

variable "ptlsbox_subscription" {
  default     = "1497c3d7-ab6d-4bb7-8a10-b51d03189ee3"
  description = "PTLSBOX subscription Id to use for additional Managed Identity"
}
