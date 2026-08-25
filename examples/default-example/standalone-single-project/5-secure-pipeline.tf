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

# 5-appinfra

# app_01
locals {

  cluster_membership_ids = { (local.env) : { "cluster_membership_ids" : module.multitenant_infra.cluster_membership_ids } }

  sa_cb       = [for cicd in module.cicd : "serviceAccount:${cicd.cloudbuild_service_account}"]
  projects_re = "projects/([^/]+)/"
  secret_project_number = try(
    regex("projects/([^/]*)/", var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id)[0],
    regex("projects/([^/]*)/", var.cloudbuildv2_repository_config.github_secret_id)[0],
    null
  )

  team_name    = "default"
  service_name = "hello-world"
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_iam_member" "assign_permissions" {
  project = local.workerpool_project_id
  role    = "roles/cloudbuild.workerPoolUser"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "assign_permissions_service_agent" {
  project = local.workerpool_project_id
  role    = "roles/cloudbuild.workerPoolUser"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "sd_viewer" {
  project = local.workerpool_network_project_id
  role    = "roles/servicedirectory.viewer"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "access_network" {
  project = local.workerpool_network_project_id
  role    = "roles/servicedirectory.pscAuthorizedService"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuid_builder" {
  for_each = module.cicd
  project  = local.workerpool_network_project_id
  role     = "roles/cloudbuild.builds.builder"
  member   = "serviceAccount:${each.value.cloudbuild_service_account}"
}

resource "time_sleep" "wait_propagation" {
  create_duration = "60s"

  depends_on = [
    google_project_iam_member.assign_permissions,
    google_project_iam_member.assign_permissions_service_agent,
    google_project_iam_member.sd_viewer,
    google_project_iam_member.access_network,
    google_access_context_manager_service_perimeter_egress_policy.egress_policy,
    google_access_context_manager_service_perimeter_dry_run_egress_policy.egress_policy,
    google_access_context_manager_service_perimeter_ingress_policy.cymbal_bank_private_deployment,
    google_access_context_manager_service_perimeter_dry_run_ingress_policy.cymbal_bank_private_deployment,
    google_project_service.required_services
  ]
}

module "cicd" {
  source   = "../../../modules/deployment-pipeline"
  for_each = var.cloudbuildv2_repository_config.repositories

  project_id                 = var.project_id
  region                     = var.region
  env_cluster_membership_ids = local.cluster_membership_ids
  cluster_service_accounts   = { for i, sa in module.multitenant_infra.cluster_service_accounts : (i) => "serviceAccount:${sa}" }

  service_name           = local.service_name
  team_name              = local.team_name
  repo_name              = each.value.repository_name
  repo_branch            = "main"
  app_build_trigger_yaml = "cloudbuild.yaml"

  additional_substitutions = {
    _SERVICE = local.service_name
    _TEAM    = local.team_name
  }

  ci_build_included_files = ["*"]

  buckets_force_destroy = true

  cloudbuildv2_repository_config = var.cloudbuildv2_repository_config

  workerpool_id = local.workerpool_id

  logging_bucket = var.logging_bucket
  bucket_kms_key = var.bucket_kms_key

  access_level_name = var.access_level_name

  attestation_kms_key = var.attestation_kms_key
  attestor_id         = var.attestation_kms_key != null ? module.fleetscope_infra.attestor_id : null

  binary_authorization_image         = module.binary_autz.binary_authorization_image
  binary_authorization_repository_id = module.binary_autz.binary_authorization_repository_id

  depends_on = [
    time_sleep.wait_propagation
  ]
}
