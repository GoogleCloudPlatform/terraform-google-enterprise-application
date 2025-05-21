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

resource "google_storage_bucket" "build_logs" {
  name                        = "cb-mc-builder-logs-${var.infra_project}"
  project                     = var.infra_project
  uniform_bucket_level_access = true
  force_destroy               = var.bucket_force_destroy
  location                    = var.region
  versioning {
    enabled = true
  }
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
    google_storage_bucket_iam_member.builder_admin,
    google_project_iam_member.builder_object_user,
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
  --gcs-log-dir=${google_storage_bucket.build_logs.url} \
  --worker-pool=${var.workerpool_id} || (
    sleep 45 && gcloud builds submit ${path.module} \
      --tag ${var.region}-docker.pkg.dev/${var.infra_project}/${google_artifact_registry_repository.research_images.name}/mc_run:${local.docker_tag_version_terraform} \
      --project=${var.infra_project} \
      --service-account=${google_service_account.builder.id} \
      --gcs-log-dir=${google_storage_bucket.build_logs.url} \
      --worker-pool=${var.workerpool_id}
  )
EOF

  module_depends_on = [time_sleep.wait_iam_propagation]
}
