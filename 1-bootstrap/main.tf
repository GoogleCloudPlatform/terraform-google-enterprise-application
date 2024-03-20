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
      repo_name    = "eab-multitenant",
      bucket_infix = "mt"
      roles = [
        "roles/container.admin"
      ]
    }
    "applicationfactory" = {
      repo_name    = "eab-applicationfactory",
      bucket_infix = "af"
      roles        = []
    }
    "fleetscope" = {
      repo_name    = "eab-fleetscope",
      bucket_infix = "fs"
      roles        = []
    }
  }
}

resource "google_sourcerepo_repository" "gcp_repo" {
  for_each = local.cb_config

  project = var.project_id
  name    = each.value.repo_name
}

module "tfstate_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 5.0"

  name          = "${var.bucket_prefix}-${var.project_id}-tf-state"
  project_id    = var.project_id
  location      = var.location
  force_destroy = var.bucket_force_destroy
}

module "tf_cloudbuild_workspace" {
  source  = "terraform-google-modules/bootstrap/google//modules/tf_cloudbuild_workspace"
  version = "~> 7.0"

  for_each = local.cb_config

  project_id = var.project_id
  location   = var.location

  tf_repo_uri           = google_sourcerepo_repository.gcp_repo[each.key].url
  tf_repo_type          = "CLOUD_SOURCE_REPOSITORIES"
  trigger_location      = var.trigger_location
  artifacts_bucket_name = "${var.bucket_prefix}-${var.project_id}-${each.value.bucket_infix}-build"
  log_bucket_name       = "${var.bucket_prefix}-${var.project_id}-${each.value.bucket_infix}-logs"

  create_state_bucket    = false
  state_bucket_self_link = module.tfstate_bucket.bucket.self_link

  cloudbuild_plan_filename  = "cloudbuild-tf-plan.yaml"
  cloudbuild_apply_filename = "cloudbuild-tf-apply.yaml"

  # Branches to run the build
  tf_apply_branches = var.tf_apply_branches
}
