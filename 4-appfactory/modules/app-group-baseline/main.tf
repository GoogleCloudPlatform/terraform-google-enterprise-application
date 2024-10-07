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
  cicd_project = var.create_cicd_project ? module.app_cicd_project[0].project_id : var.cicd_project
  cloudbuild_sa_roles = var.create_infra_project ? { for env in keys(var.envs) : env => {
    project_id = module.app_infra_project[env].project_id
    roles      = var.cloudbuild_sa_roles[env].roles
  } } : {}
}


module "app_cicd_project" {
  count = var.create_cicd_project ? 1 : 0

  source  = "terraform-google-modules/project-factory/google"
  version = "~> 17.0"

  random_project_id        = true
  random_project_id_length = 4
  billing_account          = var.billing_account
  name                     = substr("${var.acronym}-${var.service_name}-cicd", 0, 25) # max length 30 chars
  org_id                   = var.org_id
  folder_id                = var.folder_id
  deletion_policy          = "DELETE"
  activate_apis = [
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudfunctions.googleapis.com",
    "apikeys.googleapis.com",
    "sourcerepo.googleapis.com",
    "clouddeploy.googleapis.com"
  ]
}

resource "google_sourcerepo_repository" "app_infra_repo" {
  project = local.cicd_project
  name    = "${var.service_name}-i-r"
}

module "tf_cloudbuild_workspace" {
  source  = "terraform-google-modules/bootstrap/google//modules/tf_cloudbuild_workspace"
  version = "~> 8.0"

  project_id               = local.cicd_project
  tf_repo_uri              = google_sourcerepo_repository.app_infra_repo.url
  tf_repo_type             = "CLOUD_SOURCE_REPOSITORIES"
  location                 = var.location
  trigger_location         = var.trigger_location
  artifacts_bucket_name    = "${var.bucket_prefix}-${local.cicd_project}-${var.service_name}-build"
  create_state_bucket_name = "${var.bucket_prefix}-${local.cicd_project}-${var.service_name}-state"
  log_bucket_name          = "${var.bucket_prefix}-${local.cicd_project}-${var.service_name}-logs"
  buckets_force_destroy    = var.bucket_force_destroy
  cloudbuild_sa_roles      = local.cloudbuild_sa_roles

  cloudbuild_plan_filename  = "cloudbuild-tf-plan.yaml"
  cloudbuild_apply_filename = "cloudbuild-tf-apply.yaml"
  tf_apply_branches         = var.tf_apply_branches
}

// Create infra project
module "app_infra_project" {
  source   = "terraform-google-modules/project-factory/google"
  version  = "~> 17.0"
  for_each = var.create_infra_project ? var.envs : {}

  random_project_id        = true
  random_project_id_length = 4
  billing_account          = each.value.billing_account
  name                     = substr("eab-${var.acronym}-${var.service_name}-${each.key}", 0, 25) # max length 30 chars
  org_id                   = each.value.org_id
  folder_id                = each.value.folder_id
  activate_apis            = var.infra_project_apis
  deletion_policy          = "DELETE"
}
