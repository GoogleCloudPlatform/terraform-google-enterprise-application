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
      bucket_prefix = "mt"
      roles = [
        "roles/container.admin"
      ]
    }
    "applicationfactory" = {
      repo_name     = "eab-applicationfactory",
      bucket_prefix = "af"
      roles = [
      ]
    }
    "fleetscope" = {
      repo_name     = "eab-fleetscope",
      bucket_prefix = "fs"
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

module "tf_cloudbuild_workspace" {
  for_each = local.cb_config
  source   = "terraform-google-modules/bootstrap/google//modules/tf_cloudbuild_workspace"
  version  = "~> 7.0"

  project_id               = var.project_id
  tf_repo_uri              = google_sourcerepo_repository.gcp_repo[each.key].url
  tf_repo_type             = "CLOUD_SOURCE_REPOSITORIES"
  artifacts_bucket_name    = "${each.value.bucket_prefix}-build-${var.project_id}"
  create_state_bucket_name = "${each.value.bucket_prefix}-state-${var.project_id}"
  log_bucket_name          = "${each.value.bucket_prefix}-logs-${var.project_id}"

  #   cloudbuild_plan_filename  = "cloudbuild-tf-plan.yaml"
  #   cloudbuild_apply_filename = "cloudbuild-tf-apply.yaml"
}
