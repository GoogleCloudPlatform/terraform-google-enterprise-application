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
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "logging.googleapis.com",
    "notebooks.googleapis.com",
    "batch.googleapis.com",
    "pubsub.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com"
  ])
  project            = var.infra_project
  service            = each.key
  disable_on_destroy = false
}

// TODO: use custom service account after PR is merged:  https://github.com/GoogleCloudPlatform/cluster-toolkit/pull/3736
data "google_compute_default_service_account" "default" {
  # tflint-ignore: terraform_unused_declarations
  project = var.infra_project
}

// TODO: use Shared VPC after PR is merged: https://github.com/GoogleCloudPlatform/cluster-toolkit/pull/3671
resource "google_compute_network" "default" {
  name                    = "default"
  project                 = var.infra_project
  auto_create_subnetworks = true
}
