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
  gar_repository               = split("/", module.tf_cloud_builder.artifact_repo)[length(split("/", module.tf_cloud_builder.artifact_repo)) - 1]
  cloud_builder_trigger_id     = element(split("/", module.tf_cloud_builder.cloudbuild_trigger_id), index(split("/", module.tf_cloud_builder.cloudbuild_trigger_id), "triggers") + 1, )
}

resource "google_service_account" "tf_cloudbuilder" {
  account_id   = "tf-cloudbuilder"
  display_name = "TF Cloud Builder"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "storage_admin" {
  bucket = "${var.bucket_prefix}-${google_sourcerepo_repository.tf_cloud_builder_image.project}-tf-cloudbuilder-build-logs"
  role   = "roles/storage.admin"
  member = google_service_account.tf_cloudbuilder.member

  depends_on = [module.tf_cloud_builder]
}

resource "google_sourcerepo_repository" "tf_cloud_builder_image" {
  project = var.project_id
  name    = "tf-cloudbuilder-image"
}

module "tf_cloud_builder" {
  source  = "terraform-google-modules/bootstrap/google//modules/tf_cloudbuild_builder"
  version = "~> 8.0"

  project_id                   = google_sourcerepo_repository.tf_cloud_builder_image.project
  dockerfile_repo_uri          = google_sourcerepo_repository.tf_cloud_builder_image.url
  terraform_version            = local.terraform_version
  build_timeout                = "1200s"
  cb_logs_bucket_force_destroy = var.bucket_force_destroy
  enable_worker_pool           = true
  bucket_name                  = "${var.bucket_prefix}-${google_sourcerepo_repository.tf_cloud_builder_image.project}-tf-cloudbuilder-build-logs"
  gar_repo_location            = var.location
  trigger_location             = var.location
  cloudbuild_sa                = google_service_account.tf_cloudbuilder.id
}

module "bootstrap_csr_repo" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 3.1"
  upgrade = false

  create_cmd_entrypoint = "${path.module}/scripts/push-to-repo.sh"
  create_cmd_body       = "${google_sourcerepo_repository.tf_cloud_builder_image.project} ${split("/", google_sourcerepo_repository.tf_cloud_builder_image.id)[3]} ${path.module}/Dockerfile"
}

resource "time_sleep" "cloud_builder" {
  create_duration = "30s"

  depends_on = [
    module.tf_cloud_builder,
    module.bootstrap_csr_repo,
    google_storage_bucket_iam_member.storage_admin
  ]
}

data "google_client_openid_userinfo" "me" {
}

resource "null_resource" "name" {
  provisioner "local-exec" {
    command = "builder_bucket=$(gcloud storage buckets list --project ${google_sourcerepo_repository.tf_cloud_builder_image.project} | grep cloudbuilder | grep storage_url | awk '{ print $2 }') && echo $builder_bucket && gcloud storage buckets get-iam-policy $builder_bucket"
  }
  depends_on = [time_sleep.cloud_builder]
}

module "build_terraform_image" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 3.1"
  upgrade = false

  create_cmd_triggers = {
    "terraform_version" = local.terraform_version
  }

  create_cmd_body = "builds triggers run ${local.cloud_builder_trigger_id} --branch main --region ${var.location} --project ${google_sourcerepo_repository.tf_cloud_builder_image.project}"

  module_depends_on = [
    time_sleep.cloud_builder,
  ]
  depends_on = [data.google_client_openid_userinfo.me]
}


resource "google_artifact_registry_repository_iam_member" "terraform_sa_artifact_registry_reader" {
  for_each = module.tf_cloudbuild_workspace

  project    = var.project_id
  location   = var.location
  repository = local.gar_repository
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${reverse(split("/", each.value.cloudbuild_sa))[0]}"
}
