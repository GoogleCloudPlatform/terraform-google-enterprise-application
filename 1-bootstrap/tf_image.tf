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

locals {
  docker_tag_version_terraform = "v1"
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_artifact_registry_repository" "tf_image" {
  project       = var.project_id
  location      = var.location
  repository_id = "terraform-image"
  description   = "Terraform Image Docker repository"
  format        = "DOCKER"
}

resource "google_service_account" "builder" {
  project    = var.project_id
  account_id = "tf-builder"
}

resource "google_storage_bucket" "build_logs" {
  name                        = "cb-tf-builder-logs-${var.project_id}"
  project                     = var.project_id
  uniform_bucket_level_access = true
  force_destroy               = var.bucket_force_destroy
  location                    = var.location
}

# IAM Roles required to build the terraform image on Google Cloud Build
resource "google_storage_bucket_iam_member" "builder_admin" {
  member = google_service_account.builder.member
  bucket = google_storage_bucket.build_logs.name
  role   = "roles/storage.admin"
}

resource "google_project_iam_member" "builder_object_user" {
  member  = google_service_account.builder.member
  project = var.project_id
  role    = "roles/storage.objectUser"
}

resource "google_project_iam_member" "builder_logging_writer" {
  member  = google_service_account.builder.member
  project = var.project_id
  role    = "roles/logging.logWriter"
}

resource "google_artifact_registry_repository_iam_member" "builder" {
  project    = google_artifact_registry_repository.tf_image.project
  location   = google_artifact_registry_repository.tf_image.location
  repository = google_artifact_registry_repository.tf_image.name
  role       = "roles/artifactregistry.repoAdmin"
  member     = google_service_account.builder.member
}

resource "google_project_iam_member" "tf_workerpool_user" {
  member  = google_service_account.builder.member
  project = local.worker_pool_project
  role    = "roles/cloudbuild.workerPoolUser"
}

resource "google_project_iam_member" "identity_workerpool_user" {
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
  project = local.worker_pool_project
  role    = "roles/cloudbuild.workerPoolUser"
}

resource "google_project_iam_member" "identity_build_builder" {
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
  project = local.worker_pool_project
  role    = "roles/cloudbuild.builds.builder"
}

resource "google_project_iam_member" "identity_log_viewer" {
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
  project = local.worker_pool_project
  role    = "roles/logging.viewer"
}

resource "google_project_iam_member" "identity_log_writer" {
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
  project = local.worker_pool_project
  role    = "roles/logging.logWriter"
}

resource "google_project_iam_member" "worker_pool_builder_logging_writer" {
  member  = google_service_account.builder.member
  project = local.worker_pool_project
  role    = "roles/logging.logWriter"
}

resource "google_project_iam_member" "tf_cloud_build_builder" {
  member  = google_service_account.builder.member
  project = local.worker_pool_project
  role    = "roles/cloudbuild.builds.builder"
}

resource "time_sleep" "wait_iam_propagation" {
  create_duration = "60s"

  depends_on = [
    google_project_iam_member.tf_workerpool_user,
    google_project_iam_member.worker_pool_builder_logging_writer,
    google_project_iam_member.tf_cloud_build_builder,
    google_artifact_registry_repository_iam_member.builder,
    google_storage_bucket_iam_member.builder_admin,
    google_project_iam_member.builder_object_user,
  ]
}

# Use Dockerfile to create the custom Terraform Image on Google Cloud Build
module "build_terraform_image" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 3.1"
  upgrade = false

  create_cmd_triggers = {
    "tag_version" = local.docker_tag_version_terraform
  }

  create_cmd_entrypoint = "bash"
  create_cmd_body       = "gcloud builds submit --tag ${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.tf_image.name}/terraform:${local.docker_tag_version_terraform} --project=${var.project_id} --service-account=${google_service_account.builder.id} --gcs-log-dir=${google_storage_bucket.build_logs.url} --worker-pool=${var.workerpool_id} || ( sleep 45 && gcloud builds submit --tag ${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.tf_image.name}/terraform:${local.docker_tag_version_terraform} --project=${var.project_id} --service-account=${google_service_account.builder.id} --gcs-log-dir=${google_storage_bucket.build_logs.url}  --worker-pool=${var.workerpool_id}  )"

  module_depends_on = [time_sleep.wait_iam_propagation]
}


# Allow infrastructure pipeline service accounts to download the image
resource "google_artifact_registry_repository_iam_member" "terraform_sa_artifact_registry_reader" {
  for_each = module.tf_cloudbuild_workspace

  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.tf_image.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${reverse(split("/", each.value.cloudbuild_sa))[0]}"
}
