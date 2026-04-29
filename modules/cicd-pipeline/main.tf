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

# used to get project number
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_service_identity" "cloudbuild_service_identity" {
  provider = google-beta

  project = var.project_id
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service_identity" "cloud_deploy_sa" {
  provider = google-beta

  project = var.project_id
  service = "clouddeploy.googleapis.com"
}

resource "google_project_service_identity" "compute_sa" {
  provider = google-beta
  project  = var.project_id
  service  = "compute.googleapis.com"
}

data "google_compute_default_service_account" "compute_service_identity" {
  project = var.project_id
}
