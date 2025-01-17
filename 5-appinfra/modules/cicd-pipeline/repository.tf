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
  service_repo_name = var.cloudbuildv2_repository_config.repositories[var.repo_name].repository_name
  use_csr           = var.cloudbuildv2_repository_config.repo_type == "CSR"
}

# DEPRECATED - TODO: Remove after CSR support is removed
resource "google_sourcerepo_repository" "app_repo" {
  count = local.use_csr ? 1 : 0


  project = var.project_id
  name    = var.repo_name

  create_ignore_already_exists = true
}

# DEPRECATED - TODO: Remove after CSR support is removed
resource "google_sourcerepo_repository_iam_member" "member" {
  count = local.use_csr ? 1 : 0


  project    = var.project_id
  repository = google_sourcerepo_repository.app_repo[0].name
  role       = "roles/source.admin"
  member     = google_project_service_identity.cloudbuild_service_identity.member
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
