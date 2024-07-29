output "pipeline_service_principals" {
  value = data.terraform_remote_state.source.outputs.pipeline_service_principals
}