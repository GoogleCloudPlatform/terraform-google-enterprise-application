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

resource "google_artifact_registry_repository" "mcp" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_id
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}

resource "google_storage_bucket" "cloudbuild" {
  project                     = var.project_id
  name                        = "${var.project_id}-mcp-cloudbuild"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  depends_on                  = [google_project_service.apis]
}

resource "google_service_account" "mcp_runtime" {
  for_each     = var.mcp_services
  project      = var.project_id
  account_id   = each.value.account_id
  display_name = "MCP runtime ${each.key}"
  depends_on   = [google_project_service.apis]
}

resource "google_service_account" "invoker" {
  project      = var.project_id
  account_id   = "agent-mcp-invoker"
  display_name = "ADK GKE MCP invoker"
  depends_on   = [google_project_service.apis]
}

resource "google_service_account_iam_member" "gke_token_creator" {
  service_account_id = google_service_account.invoker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.gke_agent_sa_email}"
}

resource "google_cloud_run_v2_service" "mcp" {
  for_each = var.mcp_services

  project             = var.project_id
  name                = each.key
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.mcp_runtime[each.key].email

    scaling {
      min_instance_count = each.value.min_instance_count
      max_instance_count = each.value.max_instance_count
    }

    containers {
      image = coalesce(each.value.image, var.mcp_placeholder_image)

      ports {
        container_port = each.value.container_port
      }

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }

      env {
        name  = "OTEL_SERVICE_NAME"
        value = each.key
      }

      resources {
        limits = {
          cpu    = each.value.cpu
          memory = each.value.memory
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [google_project_service.apis]

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image,
      template[0].labels,
      template[0].annotations,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = var.mcp_services
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.mcp[each.key].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.invoker.email}"
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
}

resource "google_storage_bucket_iam_member" "cloudbuild_object" {
  for_each = toset(local.cloudbuild_sas)
  bucket   = google_storage_bucket.cloudbuild.name
  role     = "roles/storage.objectAdmin"
  member   = each.value
}