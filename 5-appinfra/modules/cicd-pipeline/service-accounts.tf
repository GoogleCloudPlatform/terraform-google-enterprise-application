# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# cloud build service account
resource "google_service_account" "cloud_build" {
  project                      = var.project_id
  account_id                   = "ci-${var.service_name}"
  create_ignore_already_exists = true
}

# additional roles for cloud-build service account
resource "google_artifact_registry_repository_iam_member" "cloud_build" {
  repository = local.container_registry.repository_id
  location   = local.container_registry.location
  project    = local.container_registry.project

  role   = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.cloud_build.email}"
}

resource "google_service_account_iam_member" "cloud_build_impersonate_cloud_deploy" {
  service_account_id = google_service_account.cloud_deploy.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloud_build.email}"
}

resource "google_service_account_iam_member" "cloud_build_token_creator_cloud_deploy" {
  service_account_id = google_service_account.cloud_deploy.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.cloud_build.email}"
}

resource "google_access_context_manager_access_level_condition" "access-level-conditions" {
  count        = var.access_level_name != null ? 1 : 0
  access_level = var.access_level_name
  members = [
    google_service_account.cloud_deploy.member,
    google_service_account.cloud_build.member,
    google_project_service_identity.cloudbuild_service_identity.member,
    google_project_service_identity.cloud_deploy_sa.member,
  ]

  depends_on = [
    time_sleep.wait_access_level_propagation
  ]
}

resource "time_sleep" "wait_access_level_propagation" {
  depends_on = [
    google_service_account.cloud_deploy,
    google_service_account.cloud_build,
    google_project_service_identity.cloudbuild_service_identity,
    google_project_service_identity.cloud_deploy_sa
  ]
  destroy_duration = "2m"
}
