locals {
  cluster_service_accounts = flatten([for state in data.terraform_remote_state.multitenant : state.outputs.cluster_service_accounts])
  cluster_projects_ids     = [for state in data.terraform_remote_state.multitenant : state.outputs.cluster_project_id]
  acronym                  = flatten([for state in data.terraform_remote_state.multitenant : state.outputs.acronyms])[0]
  gar_project_id           = data.terraform_remote_state.bootstrap.outputs.tf_project_id
  gar_image_name           = data.terraform_remote_state.bootstrap.outputs.tf_repository_name
  gar_tag_version          = data.terraform_remote_state.bootstrap.outputs.tf_tag_version_terraform
}