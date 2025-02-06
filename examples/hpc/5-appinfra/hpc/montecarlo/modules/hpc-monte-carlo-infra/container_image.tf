resource "google_service_account" "builder" {
  project    = var.infra_project
  account_id = "mc-builder"
}

resource "google_storage_bucket" "build_logs" {
  name                        = "cb-mc-builder-logs-${var.infra_project}"
  project                     = var.infra_project
  uniform_bucket_level_access = true
  force_destroy               = var.bucket_force_destroy
  location                    = var.region
}

# IAM Roles required to build the terraform image on Google Cloud Build
resource "google_storage_bucket_iam_member" "builder_admin" {
  member = google_service_account.builder.member
  bucket = google_storage_bucket.build_logs.name
  role   = "roles/storage.admin"
}

resource "google_project_iam_member" "builder_object_user" {
  member  = google_service_account.builder.member
  project = var.infra_project
  role    = "roles/storage.objectUser"
}

resource "google_artifact_registry_repository_iam_member" "builder" {
  project    = google_artifact_registry_repository.research_images.project
  location   = google_artifact_registry_repository.research_images.location
  repository = google_artifact_registry_repository.research_images.name
  role       = "roles/artifactregistry.repoAdmin"
  member     = google_service_account.builder.member
}

resource "time_sleep" "wait_iam_propagation" {
  create_duration = "60s"

  depends_on = [
    google_artifact_registry_repository_iam_member.builder,
    google_storage_bucket_iam_member.builder_admin,
    google_project_iam_member.builder_object_user,
  ]
}

resource "google_artifact_registry_repository" "research_images" {
  location      = var.region
  project       = var.infra_project
  repository_id = "research-images"
  description   = "Docker repository for research images"
  format        = "DOCKER"

  depends_on = [google_project_service.enable_apis]
}

module "build_mc_run_image_image" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 3.1"
  upgrade = false

  create_cmd_triggers = {
    "tag_version" = local.docker_tag_version_terraform
  }

  create_cmd_entrypoint = "bash"
  create_cmd_body       = "gcloud builds submit ${path.module} --tag ${var.region}-docker.pkg.dev/${var.infra_project}/${google_artifact_registry_repository.research_images.name}/mc_run:${local.docker_tag_version_terraform} --project=${var.infra_project} --service-account=${google_service_account.builder.id} --gcs-log-dir=${google_storage_bucket.build_logs.url} || ( sleep 45 && gcloud builds submit ${path.module} --tag ${var.region}-docker.pkg.dev/${var.infra_project}/${google_artifact_registry_repository.research_images.name}/mc_run:${local.docker_tag_version_terraform} --project=${var.infra_project} --service-account=${google_service_account.builder.id} --gcs-log-dir=${google_storage_bucket.build_logs.url} )"

  module_depends_on = [time_sleep.wait_iam_propagation]
}
