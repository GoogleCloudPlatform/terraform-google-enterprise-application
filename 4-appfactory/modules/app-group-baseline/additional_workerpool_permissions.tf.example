
// ============== TERRAFOM SCRIPT - CLOUD BUILD WORKER POOL PERMISSIONS ==============
// This is an optional terraform script
// - Assigns workerPoolUser to Cloud Build Service Agent and Service Account
// - Allows the use of worker pool in separate project
// - Admin projects will be able to build images using workerpool
// ******************
// ** REQUIREMENTS **
// ******************
// To run this script in AppFactory Pipeline:
// - Application Factory Pipeline SA must have `roles/resourcemanager.projectIamAdmin` on the workerpool project

locals {
  projects_re         = "projects/([^/]+)/"
  worker_pool_project = regex(local.projects_re, var.worker_pool_id)[0]
}

data "google_project" "admin_projects" {
  project_id = local.admin_project_id
}

resource "google_project_iam_member" "assign_permissions" {
  project  = local.worker_pool_project
  role     = "roles/cloudbuild.workerPoolUser"
  member   = "serviceAccount:service-${data.google_project.admin_projects.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "assign_permissions_service_agent" {
  project  = local.worker_pool_project
  role     = "roles/cloudbuild.workerPoolUser"
  member   = "serviceAccount:${data.google_project.admin_projects.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "sd_viewer" {
  project = local.worker_pool_project
  role    = "roles/servicedirectory.viewer"
  member  = "serviceAccount:service-${data.google_project.admin_projects.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "access_network" {
  project = local.worker_pool_project
  role    = "roles/servicedirectory.pscAuthorizedService"
  member  = "serviceAccount:service-${data.google_project.admin_projects.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}
