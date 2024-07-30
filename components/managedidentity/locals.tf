locals {
  mi_environment         = var.env == "ptlsbox" ? "cftsbox-intsvc" : var.env == "ptl" ? "cftptl-intsvc" : var.env == "sbox" ? "sandbox" : var.env == "stg" ? "aat" : var.env == "dev" ? "preview" : var.env == "test" ? "perftest" : var.env
  jenkins_mi_environment = var.env == "prod" ? "jenkins_prod" : var.env == "sbox" ? "jenkins_sbox" : var.env
  mi_cft = {
    # DCD-CNP-Sandbox
    sbox = {
      cosmosdb_name       = "sandbox-pipeline-metrics"
      resource_group_name = "pipelinemetrics-database-sandbox"
    }
    # DCD-CNP-Prod
    prod = {
      cosmosdb_name       = "pipeline-metrics"
      resource_group_name = "pipelinemetrics-database-prod"
    }
    # Jenkins Sbox
    jenkins_sbox = {
      cosmosdb_name       = "sds-jenkins-pipeline-metrics"
      resource_group_name = "sds-jenkins-ptl-rg"
    }
    # Jenkins Prod
    jenkins_prod = {
      cosmosdb_name       = "sds-jenkins-pipeline-metrics"
      resource_group_name = "sds-jenkins-ptl-rg"
    }
    # Other environments without CosmosDB details
    cftsbox-intsvc = {
      subscription_id = "1497c3d7-ab6d-4bb7-8a10-b51d03189ee3"
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
