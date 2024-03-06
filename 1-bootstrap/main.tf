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
  cb_config = {
    "multitenant" = {
      repo_name     = "eab-multitenant",
      bucket_infix = "mt"
      roles = [
        "roles/container.admin"
      ]
    }
    "applicationfactory" = {
      repo_name     = "eab-applicationfactory",
      bucket_infix = "af"
      roles = [
      ]
    }
    "fleetscope" = {
      repo_name     = "eab-fleetscope",
      bucket_infix = "fs"
      roles = [
      ]
    }
  }
}

resource "google_sourcerepo_repository" "gcp_repo" {
  for_each = local.cb_config

  project = var.project_id
  name    = each.value.repo_name
}

//Change simple bucket
module "gcp_projects_state_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 5.0"

  name          = "${var.bucket_prefix}-${module.seed_bootstrap.seed_project_id}-gcp-projects-tfstate"
  project_id    = module.seed_bootstrap.seed_project_id
  location      = var.default_region
  force_destroy = var.bucket_force_destroy

  encryption = {
    default_kms_key_name = local.state_bucket_kms_key
  }

  depends_on = [module.seed_bootstrap.gcs_bucket_tfstate]
}

resource "google_storage_bucket" "cloudbuild_state" {
  project                     = module.cicd_project.project_id
  name                        = "${var.bucket_prefix}-${var.project_id}-cloudbuild-state"
  location                    = var.location
  labels                      = var.storage_bucket_labels
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}

module "tf_cloudbuild_workspace" {
  source   = "terraform-google-modules/bootstrap/google//modules/tf_cloudbuild_workspace"
  version  = "~> 7.0"
  for_each = local.cb_config


  project_id               = var.project_id
  location                 = var.location

  tf_repo_uri              = google_sourcerepo_repository.gcp_repo[each.key].url
  tf_repo_type             = "CLOUD_SOURCE_REPOSITORIES"
  trigger_location         = var.trigger_location
  artifacts_bucket_name    = "${var.bucket_prefix}-${var.project_id}-${each.value.bucket_infix}-build" # bucket para armazenar artefatos de build
  create_state_bucket      = false
  state_bucket_self_link   = google_storage_bucket.cloudbuild_state.self_link
  //create_state_bucket_name = "${var.bucket_prefix}-${var.project_id}-${each.value.bucket_infix}-state" # bucket para armazenar o state terraform
  log_bucket_name          = "${var.bucket_prefix}-${var.project_id}-${each.value.bucket_infix}-logs" # bucket para armazenar logs do Cloud Build

  cloudbuild_plan_filename  = "cloudbuild-tf-plan.yaml"
  cloudbuild_apply_filename = "cloudbuild-tf-apply.yaml"

  # Branches to run the build
  tf_apply_branches = ["development", "non\\-production", "production"]
}
