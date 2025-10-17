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

module "build_logs" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 11.0"

  name              = "${var.bucket_prefix}-cb-tf-builder-logs-${var.project_id}"
  project_id        = var.project_id
  location          = var.location
  log_bucket        = var.logging_bucket
  log_object_prefix = "cb-tf-${var.project_id}"
  force_destroy     = var.bucket_force_destroy

  public_access_prevention = "enforced"

  versioning = true

  encryption = var.bucket_kms_key == null ? null : {
    default_kms_key_name = var.bucket_kms_key
  }

  internal_encryption_config = var.bucket_kms_key == null ? {
    create_encryption_key = true
    prevent_destroy       = !var.bucket_force_destroy
  } : {}

  # Module does not support values not know before apply (member and role are used to create the index in for_each)
  # https://github.com/terraform-google-modules/terraform-google-cloud-storage/blob/v10.0.2/modules/simple_bucket/main.tf#L122
  # iam_members = [
  #   {
  #     role   = "roles/storage.admin"
  #     member = google_service_account.builder.member
  #   },
  #   {
  #     member = google_service_account.builder.member
  #     role   = "roles/storage.objectUser"
  #   }
  # ]
}

resource "google_storage_bucket_iam_member" "logging_storage_admin" {
  bucket = module.build_logs.name
  role   = "roles/storage.admin"
  member = google_service_account.builder.member
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

resource "google_project_iam_member" "tf_workerpool_user" {
  for_each = toset([
    "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com",
    google_service_account.builder.member
    ]
  )
  member  = each.value
  project = local.worker_pool_project
  role    = "roles/cloudbuild.workerPoolUser"
}

resource "time_sleep" "wait_iam_propagation" {
  create_duration = "60s"

  depends_on = [
    google_project_iam_member.tf_workerpool_user,
    google_storage_bucket_iam_member.logging_storage_admin,
    google_artifact_registry_repository_iam_member.builder,
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
  create_cmd_body       = "gcloud builds submit --tag ${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.tf_image.name}/terraform:${local.docker_tag_version_terraform} --project=${var.project_id} --service-account=${google_service_account.builder.id} --gcs-log-dir=${module.build_logs.url} --worker-pool=${var.workerpool_id} || ( sleep 45 && gcloud builds submit --tag ${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.tf_image.name}/terraform:${local.docker_tag_version_terraform} --project=${var.project_id} --service-account=${google_service_account.builder.id} --gcs-log-dir=${module.build_logs.url}  --worker-pool=${var.workerpool_id}  )"

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
