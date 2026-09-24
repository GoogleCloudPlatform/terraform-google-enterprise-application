/**
 * Copyright 2026 Google LLC
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

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "time_sleep" "wait_apis_and_default_sas" {
  create_duration = "30s"
  depends_on      = [google_project_service.apis]
}

resource "google_artifact_registry_repository" "mcp" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_id
  format        = "DOCKER"
  depends_on    = [time_sleep.wait_apis_and_default_sas]
}

resource "google_storage_bucket" "cloudbuild" {
  project                     = var.project_id
  name                        = "${var.project_id}-mcp-cloudbuild"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  depends_on                  = [time_sleep.wait_apis_and_default_sas]
}

# SAs MCP Runtime
resource "google_service_account" "mcp_runtime" {
  for_each     = var.mcp_services
  project      = var.project_id
  account_id   = each.value.account_id
  display_name = "MCP runtime ${each.key}"
  depends_on   = [google_project_service.apis]
}

# SA Invoker
resource "google_service_account" "invoker" {
  project      = var.project_id
  account_id   = "agent-mcp-invoker"
  display_name = "ADK GKE MCP invoker"
  depends_on   = [google_project_service.apis]
}

resource "time_sleep" "wait_invoker_sa_propagation" {
  create_duration = "30s"
  depends_on      = [google_service_account.invoker]
}

resource "google_service_account_iam_member" "gke_token_creator" {
  service_account_id = google_service_account.invoker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = var.gke_agent_sa_email

  depends_on = [time_sleep.wait_invoker_sa_propagation]
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = var.mcp_services
  project  = var.project_id
  location = var.region
  name     = each.key
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.invoker.email}"

  depends_on = [time_sleep.wait_invoker_sa_propagation]
}

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  cloudbuild_sas = [
    "serviceAccount:${data.google_project.this.number}@cloudbuild.gserviceaccount.com",
    "serviceAccount:${data.google_project.this.number}-compute@developer.gserviceaccount.com",
  ]
}

resource "google_artifact_registry_repository_iam_member" "cloudbuild_writer" {
  for_each   = toset(local.cloudbuild_sas)
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.mcp.name
  role       = "roles/artifactregistry.writer"
  member     = each.value

  depends_on = [time_sleep.wait_apis_and_default_sas]
}

resource "google_storage_bucket_iam_member" "cloudbuild_object" {
  for_each = toset(local.cloudbuild_sas)
  bucket   = google_storage_bucket.cloudbuild.name
  role     = "roles/storage.objectAdmin"
  member   = each.value

  depends_on = [time_sleep.wait_apis_and_default_sas]
}