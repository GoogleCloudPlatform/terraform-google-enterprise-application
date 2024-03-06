locals {
  cloudbuild_sa_roles = { for env in var.envs : env => {
    project_id = module.app_env_project[env].project_id
    roles = var.cloudbuild_sa_roles[env]
  }}
}

// Create admin project
module "app_admin_project" {
  source                  = "terraform-google-modules/project-factory/google"
  version                 = "11.3.0"
  random_project_id       = true
  billing_account         = var.billing_account
  name                    = "${var.application_name}-admin"
  org_id                  = var.org_id
  folder_id               = var.folder_id
  activate_apis = [
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudfunctions.googleapis.com",
    "apikeys.googleapis.com"
  ]
}

resource "google_sourcerepo_repository" "app_infra_repo" {
  project = module.app_admin_project.project_id
  name    = "${var.application_name}-infra-repo"
}

module "tf_cloudbuild_workspace" {
  source   = "terraform-google-modules/bootstrap/google//modules/tf_cloudbuild_workspace"
  version  = "~> 7.0"

  project_id               = module.app_admin_project.project_id
  tf_repo_uri              = google_sourcerepo_repository.app_infra_repo.url
  tf_repo_type             = "CLOUD_SOURCE_REPOSITORIES"
  artifacts_bucket_name    = "${each.value.bucket_prefix}-build-${var.project_id}"
  create_state_bucket_name = "${each.value.bucket_prefix}-state-${var.project_id}"
  log_bucket_name          = "${each.value.bucket_prefix}-logs-${var.project_id}"
  cloudbuild_sa_roles      = local.cloudbuild_sa_roles

  cloudbuild_plan_filename  = "cloudbuild-tf-plan.yaml"
  cloudbuild_apply_filename = "cloudbuild-tf-apply.yaml"
}

// Create env project
module "app_env_project" {
  for_each = create_env_projects ? var.envs : {}
  source                  = "terraform-google-modules/project-factory/google"
  version                 = "11.3.0"
  random_project_id       = true
  billing_account         = each.value.billing_account
  name                    = "${var.application_name}-${each.env}"
  org_id                  = each.value.org_id
  folder_id               = each.value.folder_id
  activate_apis           = var.env_project_apis
}