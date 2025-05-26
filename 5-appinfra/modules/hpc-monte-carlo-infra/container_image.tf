/**
 * Copyright 2025 Google LLC
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

resource "google_service_account" "builder" {
  project    = var.infra_project
  account_id = "mc-builder"
}

module "build_logs" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "10.0.2"

  name              = "cb-mc-builder-logs-${var.infra_project}"
  project_id        = var.infra_project
  location          = var.region
  log_bucket        = var.logging_bucket
  log_object_prefix = "cbmc-${var.infra_project}"

  force_destroy = var.bucket_force_destroy

  versioning = true
  encryption = { default_kms_key_name = var.bucket_kms_key }

  # Module does not support values not know before apply (member and role are used to create the index in for_each)
  # https://github.com/terraform-google-modules/terraform-google-cloud-storage/blob/v10.0.2/modules/simple_bucket/main.tf#L122
  # iam_members = [{
  #   role   = "roles/storage.admin"
  #   member = google_service_account.builder.member
  # }]

  depends_on = [google_kms_crypto_key_iam_member.crypto_key]
}

resource "google_storage_bucket_iam_member" "build_logs_storage_admin" {
  bucket = module.build_logs.name
  role   = "roles/storage.admin"
  member = google_service_account.builder.member
}

data "google_storage_project_service_account" "gcs_account" {
  project = var.infra_project
}

resource "google_kms_crypto_key_iam_member" "crypto_key" {
  crypto_key_id = var.bucket_kms_key
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypterViaDelegation"
  member        = data.google_storage_project_service_account.gcs_account.member
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

resource "google_artifact_registry_repository_iam_member" "allow_cluster_sa_download" {
  for_each   = var.cluster_service_accounts
  project    = google_artifact_registry_repository.research_images.project
  location   = google_artifact_registry_repository.research_images.location
  repository = google_artifact_registry_repository.research_images.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${each.value}"
}

resource "time_sleep" "wait_iam_propagation" {
  create_duration = "60s"

  depends_on = [
    google_artifact_registry_repository_iam_member.builder,
    google_project_iam_member.builder_object_user,
    google_storage_bucket_iam_member.build_logs_storage_admin,
    google_access_context_manager_access_level_condition.access-level-conditions,
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
  version = "~> 3.5"
  upgrade = false

  create_cmd_triggers = {
    "tag_version" = local.docker_tag_version_terraform
  }

  create_cmd_entrypoint = "bash"

  create_cmd_body = <<EOF
gcloud builds submit ${path.module} \
  --tag ${var.region}-docker.pkg.dev/${var.infra_project}/${google_artifact_registry_repository.research_images.name}/mc_run:${local.docker_tag_version_terraform} \
  --project=${var.infra_project} \
  --service-account=${google_service_account.builder.id} \
  --gcs-log-dir=${module.build_logs.url} \
  --worker-pool=${var.workerpool_id} || (
    sleep 45 && gcloud builds submit ${path.module} \
      --tag ${var.region}-docker.pkg.dev/${var.infra_project}/${google_artifact_registry_repository.research_images.name}/mc_run:${local.docker_tag_version_terraform} \
      --project=${var.infra_project} \
      --service-account=${google_service_account.builder.id} \
      --gcs-log-dir=${module.build_logs.url} \
      --worker-pool=${var.workerpool_id}
  )
EOF

  module_depends_on = [time_sleep.wait_iam_propagation]
}
