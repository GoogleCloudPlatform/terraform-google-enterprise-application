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
  cb_config = {
    "multitenant" = {
      bucket_infix = "mt"
      roles = [
        "roles/container.admin"
      ]
    }
    "applicationfactory" = {
      bucket_infix = "af"
      roles        = ["roles/resourcemanager.projectIamAdmin"]
    }
    "fleetscope" = {
      bucket_infix = "fs"
      roles        = []
    }
  }
  use_csr                    = var.cloudbuildv2_repository_config.repo_type == "CSR"
  csr_repos                  = local.use_csr ? { for k, v in var.cloudbuildv2_repository_config.repositories : k => v.repository_name } : {}
  cb_service_accounts_emails = { for k, v in module.tf_cloudbuild_workspace : k => reverse(split("/", v.cloudbuild_sa))[0] }

  // If the user specify a Cloud Build Worker Pool, utilize it in the trigger
  optional_worker_pool = var.workerpool_id != null ? { "_PRIVATE_POOL" = var.workerpool_id } : {}

  projects_re         = "projects/([^/]+)/"
  worker_pool_project = var.workerpool_id != null ? regex(local.projects_re, var.workerpool_id)[0] : null
  kms_project         = var.bucket_kms_key != null ? regex(local.projects_re, var.bucket_kms_key)[0] : null
}

resource "google_sourcerepo_repository" "gcp_repo" {
  for_each = local.csr_repos

  project                      = var.project_id
  name                         = each.value
  create_ignore_already_exists = true
}

module "cloudbuild_repositories" {
  count = local.use_csr ? 0 : 1

  source  = "terraform-google-modules/bootstrap/google//modules/cloudbuild_repo_connection"
  version = "~> 11.0"

  project_id = var.project_id

  connection_config = {
    connection_type                             = var.cloudbuildv2_repository_config.repo_type
    github_secret_id                            = var.cloudbuildv2_repository_config.github_secret_id
    github_app_id_secret_id                     = var.cloudbuildv2_repository_config.github_app_id_secret_id
    gitlab_read_authorizer_credential_secret_id = var.cloudbuildv2_repository_config.gitlab_read_authorizer_credential_secret_id
    gitlab_authorizer_credential_secret_id      = var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id
    gitlab_webhook_secret_id                    = var.cloudbuildv2_repository_config.gitlab_webhook_secret_id
    gitlab_enterprise_host_uri                  = var.cloudbuildv2_repository_config.gitlab_enterprise_host_uri
    gitlab_enterprise_service_directory         = var.cloudbuildv2_repository_config.gitlab_enterprise_service_directory
    gitlab_enterprise_ca_certificate            = var.cloudbuildv2_repository_config.gitlab_enterprise_ca_certificate
  }
  cloud_build_repositories = var.cloudbuildv2_repository_config.repositories
}

module "tfstate_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 11.0"

  name                     = "${var.bucket_prefix}-${var.project_id}-tf-state"
  project_id               = var.project_id
  location                 = var.location
  force_destroy            = var.bucket_force_destroy
  public_access_prevention = "enforced"

  encryption = var.bucket_kms_key == null ? null : {
    default_kms_key_name = var.bucket_kms_key
  }

  internal_encryption_config = var.bucket_kms_key == null ? {
    create_encryption_key = true
    prevent_destroy       = !var.bucket_force_destroy
  } : {}

  log_bucket        = var.logging_bucket
  log_object_prefix = "tf-state-${var.project_id}"

  versioning = true

}

module "tf_cloudbuild_workspace" {
  for_each = var.cloudbuildv2_repository_config.repositories

  source  = "terraform-google-modules/bootstrap/google//modules/tf_cloudbuild_workspace"
  version = "~> 11.0"

  project_id = var.project_id
  location   = var.location

  tf_repo_uri           = local.use_csr ? google_sourcerepo_repository.gcp_repo[each.key].url : module.cloudbuild_repositories[0].cloud_build_repositories_2nd_gen_repositories[each.key].id
  tf_repo_type          = local.use_csr ? "CLOUD_SOURCE_REPOSITORIES" : "CLOUDBUILD_V2_REPOSITORY"
  trigger_location      = var.trigger_location
  artifacts_bucket_name = "${var.bucket_prefix}-${var.project_id}-${local.cb_config[each.key].bucket_infix}-build"
  log_bucket_name       = "${var.bucket_prefix}-${var.project_id}-${local.cb_config[each.key].bucket_infix}-logs"
  buckets_force_destroy = var.bucket_force_destroy

  create_state_bucket    = false
  state_bucket_self_link = module.tfstate_bucket.bucket.self_link

  cloudbuild_plan_filename  = "cloudbuild-tf-plan.yaml"
  cloudbuild_apply_filename = "cloudbuild-tf-apply.yaml"
  cloudbuild_sa_roles = {
    "roles" = {
      project_id = var.project_id
      roles      = local.cb_config[each.key].roles
    }
  }

  substitutions = merge({
    "_GAR_REGION"                   = var.location
    "_GAR_PROJECT_ID"               = google_artifact_registry_repository.tf_image.project
    "_GAR_REPOSITORY"               = google_artifact_registry_repository.tf_image.name
    "_DOCKER_TAG_VERSION_TERRAFORM" = local.docker_tag_version_terraform
  }, local.optional_worker_pool)

  # Branches to run the build
  tf_apply_branches = var.tf_apply_branches
}
