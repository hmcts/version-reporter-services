locals {
  mi_environment = var.env == "ptlsbox" ? "cftsbox-intsvc" : var.env == "ptl" ? "cftptl-intsvc" : var.env == "sbox" ? "sandbox" : var.env == "stg" ? "aat" : var.env == "dev" ? "preview" : var.env == "test" ? "perftest" : var.env
  mi_cft = {
    # DCD-CNP-Sandbox
    sandbox = {
      subscription_id = "bf308a5c-0624-4334-8ff8-8dca9fd43783"
    }
    # DCD-CNP-DEV
    aat = {
      subscription_id = "1c4f0704-a29e-403d-b719-b90c34ef14c9"
    }
    demo = {
      subscription_id = "1c4f0704-a29e-403d-b719-b90c34ef14c9"
    }
    preview = {
      subscription_id = "1c4f0704-a29e-403d-b719-b90c34ef14c9"
    }
    # DCD-CNP-QA
    ithc = {
      subscription_id = "7a4e3bd5-ae3a-4d0c-b441-2188fee3ff1c"
    }
    perftest = {
      subscription_id = "7a4e3bd5-ae3a-4d0c-b441-2188fee3ff1c"
    }
    # DCD-CNP-Prod
    prod = {
      subscription_id = "8999dec3-0104-4a27-94ee-6588559729d1"
    }
    # DTS-CFTSBOX-INTSVC
    cftsbox-intsvc = {
      subscription_id = "1497c3d7-ab6d-4bb7-8a10-b51d03189ee3"
    }
    # DTS-CFTPTL-INTSVC
    cftptl-intsvc = {
      subscription_id = "1baf5470-1c3e-40d3-a6f7-74bfbce4b348"
    }
  }
}