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
  terraform_version            = "1.9.5"
  docker_tag_version_terraform = "v1"
}

resource "google_artifact_registry_repository" "tf_image" {
  project       = var.project_id
  location      = var.location
  repository_id = "terraform-image"
  description   = "TF Image Docker repository"
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

resource "google_artifact_registry_repository_iam_member" "builder" {
  project    = google_artifact_registry_repository.tf_image.project
  location   = google_artifact_registry_repository.tf_image.location
  repository = google_artifact_registry_repository.tf_image.name
  role       = "roles/artifactregistry.repoAdmin"
  member     = google_service_account.builder.member
}

resource "google_service_account_iam_member" "impersonate" {
  for_each = toset([
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountTokenCreator"
  ])
  service_account_id = google_service_account.builder.name
  role               = each.key
  member             = "serviceAccount:ci-account@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "impersonate_project_level" {
  for_each = toset([
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountTokenCreator"
  ])
  member             = "serviceAccount:ci-account@${var.project_id}.iam.gserviceaccount.com"
  project = var.project_id
  role    = each.value
}

resource "time_sleep" "wait_iam_propagation" {
  create_duration = "10s"

  depends_on = [
    google_artifact_registry_repository_iam_member.builder,
    google_storage_bucket_iam_member.builder_admin,
    google_project_iam_member.builder_object_user,
    google_service_account_iam_member.impersonate,
    google_project_iam_member.impersonate_project_level
  ]
}

module "build_terraform_image" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 3.1"
  upgrade = false

  create_cmd_triggers = {
    "terraform_version" = local.terraform_version
  }

  create_cmd_body = "builds submit --tag ${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.tf_image.name}/terraform:${local.docker_tag_version_terraform} --project=${var.project_id} --service-account=${google_service_account.builder.id} --gcs-log-dir=${google_storage_bucket.build_logs.url}"

  module_depends_on = [time_sleep.wait_iam_propagation]
}

resource "google_artifact_registry_repository_iam_member" "terraform_sa_artifact_registry_reader" {
  for_each = module.tf_cloudbuild_workspace

  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.tf_image.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${reverse(split("/", each.value.cloudbuild_sa))[0]}"
}