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
  repository_id = local.final_service_name
  location      = var.region
  format        = "docker"
  description   = "${local.service_name} docker repository"
  project       = var.project_id

  depends_on = [
    module.enabled_google_apis
  ]
}

resource "google_artifact_registry_repository_iam_member" "member" {
  for_each = {
    "compute"      = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com",
    "cloud_deploy" = "serviceAccount:${google_service_account.cloud_deploy.email}",
  }

  project    = var.project_id
  location   = var.region
  repository = local.final_service_name
  role       = "roles/artifactregistry.reader"
  member     = each.value

  depends_on = [
    module.enabled_google_apis,
    google_artifact_registry_repository.container_registry
  ]
}
