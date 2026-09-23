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

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = var.mcp_services
  project  = var.project_id
  location = var.region
  name     = each.key
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
