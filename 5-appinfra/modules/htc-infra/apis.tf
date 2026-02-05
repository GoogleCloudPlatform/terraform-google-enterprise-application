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

module "enabled_google_apis" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 18.0"

  project_id                  = var.infra_project
  disable_services_on_destroy = false

  activate_apis = [
    "bigquery.googleapis.com",
    "parallelstore.googleapis.com",
    "container.googleapis.com",
    "logging.googleapis.com",
    "privateca.googleapis.com"
  ]
}

resource "google_project_iam_member" "team_roles_infra_project" {
  for_each = toset([
    "roles/storage.objectUser",
    "roles/storage.objectViewer",
    "roles/pubsub.publisher",
    "roles/pubsub.viewer",
    "roles/pubsub.subscriber",
    "roles/monitoring.viewer",
    "roles/privateca.certificateManager"
  ])

  project = var.infra_project
  role    = each.value
  member  = "principalSet://iam.googleapis.com/projects/${var.cluster_project_number}/locations/global/workloadIdentityPools/${var.cluster_project_id}.svc.id.goog/namespace/${local.namespace}"
}

resource "google_project_iam_member" "team_roles_cluster_project" {
  for_each = toset([
    "roles/storage.objectUser",
    "roles/storage.objectViewer",
    "roles/pubsub.publisher",
    "roles/pubsub.viewer",
    "roles/pubsub.subscriber",
    "roles/monitoring.viewer",
    "roles/privateca.certificateManager"
  ])

  project = var.cluster_project_id
  role    = each.value
  member  = "principalSet://iam.googleapis.com/projects/${var.cluster_project_number}/locations/global/workloadIdentityPools/${var.cluster_project_id}.svc.id.goog/namespace/${local.namespace}"
}
