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

resource "random_string" "cluster_service_account_suffix" {
  upper   = false
  lower   = true
  special = false
  length  = 4
}

resource "google_service_account" "cluster_service_account" {
  project      = module.eab_cluster_project.project_id
  account_id   = "tf-gke-${var.env}-${random_string.cluster_service_account_suffix.result}"
  display_name = "Terraform-managed service account for ${var.env} clusters"
}

resource "google_project_iam_member" "cluster_service_account" {
  for_each = toset(["roles/container.defaultNodeServiceAccount", "roles/storage.objectViewer", "roles/artifactregistry.reader"])
  project  = module.eab_cluster_project.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

resource "google_project_iam_member" "cluster_service_account_network_project" {
  for_each = toset(["roles/compute.networkUser", "roles/container.hostServiceAgentUser"])
  project  = var.network_project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.cluster_service_account.email}"
}
