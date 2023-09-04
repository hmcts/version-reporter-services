variable "location" {
  default = "uksouth"
}

variable "environment" {
  default = "stg"
}

variable "product" {
  default = "sds-platform"
}

variable "builtFrom" {
  default = "hmcts/version-reporter-services"
}

variable "env" {
  default = "stg"
}

variable "expiresAfter" {
  default = "3000-01-01"
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
    paloalto   = "/resourceType"
    helmcharts = "/namespace"
    renovate   = "/repository"
    docsoutdated = "/title"
  }
}
