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
  member   = "principalSet://iam.googleapis.com/projects/${var.cluster_project_number}/locations/global/workloadIdentityPools/${var.cluster_project}.svc.id.goog/namespace/hpc-team-${each.value}-${var.env}"
}

resource "google_project_iam_member" "pubsub_viewer" {
  for_each = toset(["a", "b"])
  project  = var.infra_project
  role     = "roles/pubsub.viewer"
  member   = "principalSet://iam.googleapis.com/projects/${var.cluster_project_number}/locations/global/workloadIdentityPools/${var.cluster_project}.svc.id.goog/namespace/hpc-team-${each.value}-${var.env}"
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

data "google_compute_default_service_account" "default" {
  project = var.infra_project
}

resource "google_compute_network" "default" {
  name                    = "default"
  project                 = var.infra_project
  auto_create_subnetworks = true
}


// TODO: Define exactly where permissions below on fleet scope and fleet project should be assigned - maybe this should be a PR from the team to the 2-multitenant repo, so a platform engineer can approve the role grant
resource "google_project_iam_member" "compute_sa_roles" {
  for_each = toset([
    "roles/gkehub.connect",
    "roles/gkehub.viewer",
    "roles/gkehub.gatewayReader",
    "roles/gkehub.scopeEditorProjectLevel"
  ])
  role    = each.key
  project = var.cluster_project
  member  = data.google_compute_default_service_account.default.member
}

# TODO: Define exactly where to apply rbacrolebindings
module "fleet_app_operator_permissions" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/fleet-app-operator-permissions"
  version = "~> 35.0"

  for_each = toset(["a", "b"])

  fleet_project_id = var.cluster_project
  scope_id         = "hpc-team-${each.value}-${var.env}"
  users            = [data.google_compute_default_service_account.default.email]
  role             = "ADMIN"
}
