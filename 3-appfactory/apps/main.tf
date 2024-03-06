
module "app_01" {
  source = "../modules/appl-group-baseline"

  application_name = "app1"
  create_env_projects = true

  org_id = var.org_id
  billing_account = var.billing_account
  folder_id = var.folder_id
  envs = var.envs
  cloudbuild_sa_roles = {
    development = [
        "roles/owner"
    ]
    non-production = [
        "roles/owner"
    ]
    production = [
        "roles/owner"
    ]
  }
}