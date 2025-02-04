locals {
  docker_tag_version_terraform = "v1"
}

resource "google_project_iam_member" "storage_objectuser" {
  for_each = toset(["a", "b"])
  project  = var.infra_project
  role     = "roles/storage.objectUser"
  member   = "principalSet://iam.googleapis.com/projects/${var.cluster_project_number}/locations/global/workloadIdentityPools/${var.cluster_project}.svc.id.goog/namespace/hpc-team-${each.value}-${var.env}"
}

resource "google_project_iam_member" "pubsub_publisher" {
  for_each = toset(["a", "b"])
  project  = var.infra_project
  role     = "roles/pubsub.publisher"
  member   = "principalSet://iam.googleapis.com/projects/${var.cluster_project_number}/locations/global/workloadIdentityPools/${var.cluster_project}.svc.id.goog/namespace/hpc-team-${each.value}"
}

resource "google_project_iam_member" "pubsub_viewer" {
  for_each = toset(["a", "b"])
  project  = var.infra_project
  role     = "roles/pubsub.viewer"
  member   = "principalSet://iam.googleapis.com/projects/${var.cluster_project_number}/locations/global/workloadIdentityPools/${var.cluster_project}.svc.id.goog/namespace/hpc-team-${each.value}"
}

resource "google_project_service" "enable_apis" {
  for_each = toset([
    "bigquery.googleapis.com",
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
