/**
 * Copyright 2025 Google LLC
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
  namespace                    = "${var.team}-${var.env}"
}

resource "google_project_iam_member" "team_roles" {
  for_each = toset([
    "roles/storage.objectUser",
    "roles/pubsub.publisher",
    "roles/pubsub.viewer"
  ])

  project = var.infra_project
  role    = each.value
  member  = "principalSet://iam.googleapis.com/projects/${var.cluster_project_number}/locations/global/workloadIdentityPools/${var.cluster_project}.svc.id.goog/namespace/${local.namespace}"
}

resource "google_project_service" "enable_apis" {
  for_each = toset([
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "logging.googleapis.com",
    "batch.googleapis.com",
    "cloudbuild.googleapis.com",
  ])
  project            = var.infra_project
  service            = each.key
  disable_on_destroy = false
}
