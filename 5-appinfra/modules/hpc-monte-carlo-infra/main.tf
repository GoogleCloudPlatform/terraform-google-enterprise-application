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
  docker_tag_version_terraform = "v1"
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
    "batch.googleapis.com",
    "binaryauthorization.googleapis.com",
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerscanning.googleapis.com",
    "logging.googleapis.com",
    "notebooks.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com"
  ])
  project            = var.infra_project
  service            = each.key
  disable_on_destroy = false
}

// TODO: use Shared VPC after PR is merged: https://github.com/GoogleCloudPlatform/cluster-toolkit/pull/3671
resource "google_compute_network" "default" {
  name                    = "default"
  project                 = var.infra_project
  auto_create_subnetworks = true
}

resource "google_access_context_manager_access_level_condition" "access-level-conditions" {
  count        = var.access_level_name != null ? 1 : 0
  access_level = var.access_level_name
  members      = [google_service_account.builder.member]
}

resource "google_service_account" "vertex_service_account" {
  project      = var.infra_project
  account_id   = "vertex-instance"
  display_name = "Vertex Instance SA"
}
