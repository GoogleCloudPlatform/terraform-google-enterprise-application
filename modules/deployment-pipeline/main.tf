/**
 * Copyright 2026 Google LLC
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
  membership_re = "projects/([^/]*)/locations/([^/]*)/memberships/([^/]*)$"
  envs          = keys(var.env_cluster_membership_ids)
  memberships   = flatten([for i in local.envs : var.env_cluster_membership_ids[i].cluster_membership_ids])
  gke_projects  = { for i, item in local.memberships : (i) => regex(local.membership_re, item)[0] }

  use_csr = var.cloudbuildv2_repository_config.repo_type == "CSR"
  repo_type = local.use_csr ? "CSR" : (
    var.cloudbuildv2_repository_config.repo_type == "GITHUBv2" ? "GITHUB" : (
      var.cloudbuildv2_repository_config.repo_type == "GITLABv2" ? "GITLAB" : var.cloudbuildv2_repository_config.repo_type
    )
  )

  secret_id             = !local.use_csr && var.cloudbuildv2_repository_config.github_secret_id != null ? var.cloudbuildv2_repository_config.github_secret_id : var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id
  secret_project_number = !local.use_csr && local.secret_id != null ? regex("projects/([^/]*)/", local.secret_id)[0] : null

  github_auth = local.repo_type == "GITHUB" ? {
    secret_id         = var.cloudbuildv2_repository_config.github_secret_id
    app_id_secret_id  = var.cloudbuildv2_repository_config.github_app_id_secret_id
    secret_project_id = local.secret_project_number
  } : null

  gitlab_auth = local.repo_type == "GITLAB" ? {
    read_authorizer_credential_secret_id = var.cloudbuildv2_repository_config.gitlab_read_authorizer_credential_secret_id
    authorizer_credential_secret_id      = var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id
    webhook_secret_id                    = var.cloudbuildv2_repository_config.gitlab_webhook_secret_id
    enterprise_host_uri                  = var.cloudbuildv2_repository_config.gitlab_enterprise_host_uri
    enterprise_service_directory         = var.cloudbuildv2_repository_config.gitlab_enterprise_service_directory
    enterprise_ca_certificate            = var.cloudbuildv2_repository_config.gitlab_enterprise_ca_certificate
    secret_project_id                    = local.secret_project_number
  } : null

  deploy_branch_clusters = {
    for idx, env in local.envs :
    env => {
      name                  = env
      cluster               = trimprefix(regex(local.membership_re, var.env_cluster_membership_ids[env].cluster_membership_ids[0])[2], "cluster-")
      anthos_membership     = regex(local.membership_re, var.env_cluster_membership_ids[env].cluster_membership_ids[0])[2]
      project_id            = var.project_id
      location              = var.region
      required_attestations = var.attestor_id != null ? [var.attestor_id] : []
      env_attestation       = ""
      env_number            = idx + 1
      target_type           = "anthos_cluster"
    }
  }
}

module "ci" {
  source  = "GoogleCloudPlatform/secure-cicd/google//modules/secure-ci"
  version = "~> 2.0"

  project_id       = var.project_id
  primary_location = var.region
  repository_type  = local.repo_type
  ci_repository = {
    repository_name = var.repo_name
    repository_url  = try(var.cloudbuildv2_repository_config.repositories[var.repo_name].repository_url, "")
  }
  github_auth              = local.github_auth
  gitlab_auth              = local.gitlab_auth
  attestor_names_prefix    = ["build"]
  app_build_trigger_yaml   = var.app_build_trigger_yaml
  trigger_branch_name      = var.repo_branch
  cloudbuild_private_pool  = var.private_workerpool.private_workerpool_id
  access_level_name        = var.access_level_name
  bucket_kms_key           = var.bucket_kms_key
  additional_substitutions = var.additional_substitutions
}

module "cd" {
  source  = "GoogleCloudPlatform/secure-cicd/google//modules/secure-cd"
  version = "~> 2.0"

  project_id       = var.project_id
  primary_location = var.region
  repository_type  = local.repo_type
  cd_repository = {
    repository_name = var.repo_name
    repository_url  = try(var.cloudbuildv2_repository_config.repositories[var.repo_name].repository_url, "")
  }
  github_auth                = local.github_auth
  gitlab_auth                = local.gitlab_auth
  gar_repo_name              = module.ci.app_artifact_repo
  app_deploy_trigger_yaml    = var.app_build_trigger_yaml
  cache_bucket_name          = module.ci.cache_bucket_name
  clouddeploy_pipeline_name  = var.service_name
  cloudbuild_service_account = module.ci.build_sa_email
  cloudbuild_private_pool    = var.private_workerpool.private_workerpool_id
  access_level_name          = var.access_level_name
  deploy_branch_clusters     = local.deploy_branch_clusters

  depends_on = [
    module.ci
  ]
}

resource "google_artifact_registry_repository_iam_member" "cluster_nodes" {
  for_each   = var.cluster_service_accounts
  project    = var.project_id
  location   = var.region
  repository = module.ci.app_artifact_repo
  role       = "roles/artifactregistry.reader"
  member     = each.value
}
