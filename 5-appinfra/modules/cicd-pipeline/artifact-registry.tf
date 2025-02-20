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

# create artifact registry for container images
resource "google_artifact_registry_repository" "container_registry" {
  repository_id = var.service_name
  location      = var.region
  format        = "DOCKER"
  description   = "${var.service_name} docker repository"
  project       = var.project_id

  depends_on = [
    module.enabled_google_apis
  ]
}

resource "google_artifact_registry_repository_iam_member" "container_member" {
  for_each = merge({
    cloud_deploy   = google_service_account.cloud_deploy.member,
    cloud_build_si = google_project_service_identity.cloudbuild_service_identity.member,
    compute        = data.google_compute_default_service_account.compute_service_identity.member,
  }, var.cluster_service_accounts)

  project    = var.project_id
  location   = var.region
  repository = var.service_name
  role       = "roles/artifactregistry.reader"
  member     = each.value

  depends_on = [
    module.enabled_google_apis,
    google_artifact_registry_repository.container_registry
  ]
}

resource "google_artifact_registry_vpcsc_config" "allow_artifact_registry" {
  provider     = google-beta
  project      = var.project_id
  location     = var.region
  vpcsc_policy = "ALLOW"
}
