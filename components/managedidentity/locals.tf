locals {
  mi_environment = var.env == "ptlsbox" ? "cftsbox-intsvc" : var.env == "ptl" ? "cftptl-intsvc" : var.env == "sbox" ? "sandbox" : var.env == "stg" ? "aat" : var.env == "dev" ? "preview" : var.env == "test" ? "perftest" : var.env == "jenkins_prod" ? "prod" : var.env == "jenkins_sbox" ? "sandbox" : var.env
  mi_cft = {
    # DCD-CNP-Sandbox
    sandbox = {
      subscription_id     = "bf308a5c-0624-4334-8ff8-8dca9fd43783"
      cosmosdb_name       = "sandbox-pipeline-metrics"
      resource_group_name = "pipelinemetrics-database-sandbox"
    }
    # DCD-CNP-Prod
    prod = {
      subscription_id     = "8999dec3-0104-4a27-94ee-6588559729d1"
      cosmosdb_name       = "pipeline-metrics"
      resource_group_name = "pipelinemetrics-database-prod"
    }
    # Jenkins Sbox
    jenkins_sbox = {
      subscription_id     = "64b1c6d6-1481-44ad-b620-d8fe26a2c768"
      cosmosdb_name       = "sds-jenkins-pipeline-metrics"
      resource_group_name = "sds-jenkins-ptl-rg"
    }
    # Jenkins Prod
    jenkins_prod = {
      subscription_id     = "6c4d2513-a873-41b4-afdd-b05a33206631"
      cosmosdb_name       = "sds-jenkins-pipeline-metrics"
      resource_group_name = "sds-jenkins-ptl-rg"
    }
    # Other environments without CosmosDB details
    cftsbox-intsvc = {
      subscription_id = ""
    }
    cftptl-intsvc = {
      subscription_id = "1baf5470-1c3e-40d3-a6f7-74bfbce4b348"
    }
    aat = {
      subscription_id = "1c4f0704-a29e-403d-b719-b90c34ef14c9"
    }
    demo = {
      subscription_id = "1c4f0704-a29e-403d-b719-b90c34ef14c9"
    }
    preview = {
      subscription_id = "1c4f0704-a29e-403d-b719-b90c34ef14c9"
    }
    ithc = {
      subscription_id = "7a4e3bd5-ae3a-4d0c-b441-2188fee3ff1c"
    }
    perftest = {
      subscription_id = "7a4e3bd5-ae3a-4d0c-b441-2188fee3ff1c"
    }
  }
}

locals {
  valid_envs = contains(["sandbox", "prod"], local.mi_environment)
}
