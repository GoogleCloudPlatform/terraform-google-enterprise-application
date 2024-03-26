/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  cloudbuild_sa_roles = { for env in keys(var.envs) : env => {
    project_id = module.app_env_project[env].project_id
    roles      = var.cloudbuild_sa_roles[env].roles
  } }
}

// Create admin project
module "app_admin_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 14.5"

  random_project_id = true
  billing_account   = var.billing_account
  name              = "${var.application_name}-admin"
  org_id            = var.org_id
  folder_id         = var.folder_id
  activate_apis = [
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudfunctions.googleapis.com",
    "apikeys.googleapis.com",
    "sourcerepo.googleapis.com"
  ]
}

resource "google_sourcerepo_repository" "app_infra_repo" {
  project = module.app_admin_project.project_id
  name    = "${var.application_name}-infra-repo"
}

module "tf_cloudbuild_workspace" {
  source  = "terraform-google-modules/bootstrap/google//modules/tf_cloudbuild_workspace"
  version = "~> 7.0"

  project_id               = module.app_admin_project.project_id
  tf_repo_uri              = google_sourcerepo_repository.app_infra_repo.url
  tf_repo_type             = "CLOUD_SOURCE_REPOSITORIES"
  location                 = var.location
  trigger_location         = var.trigger_location
  artifacts_bucket_name    = "${var.bucket_prefix}-${module.app_admin_project.project_id}-${var.application_name}-build"
  create_state_bucket_name = "${var.bucket_prefix}-${module.app_admin_project.project_id}-${var.application_name}-state"
  log_bucket_name          = "${var.bucket_prefix}-${module.app_admin_project.project_id}-${var.application_name}-logs"
  buckets_force_destroy    = var.bucket_force_destroy
  cloudbuild_sa_roles      = local.cloudbuild_sa_roles

  cloudbuild_plan_filename  = "cloudbuild-tf-plan.yaml"
  cloudbuild_apply_filename = "cloudbuild-tf-apply.yaml"
  tf_apply_branches         = var.tf_apply_branches
}

// Create env project
module "app_env_project" {
  source   = "terraform-google-modules/project-factory/google"
  version  = "~> 14.5"
  for_each = var.create_env_projects ? var.envs : {}

  random_project_id = true
  billing_account   = each.value.billing_account
  name              = "${var.application_name}-${each.key}"
  org_id            = each.value.org_id
  folder_id         = each.value.folder_id
  activate_apis     = var.env_project_apis
}
