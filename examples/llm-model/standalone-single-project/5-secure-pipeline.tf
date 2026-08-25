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

  sa_cb = [for cicd in module.cicd : "serviceAccount:${cicd.cloudbuild_service_account}"]
  secret_project_number = try(
    regex("projects/([^/]*)/", var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id)[0],
    regex("projects/([^/]*)/", var.cloudbuildv2_repository_config.github_secret_id)[0],
    null
  )

  application_name = "llm-model"
  service_name     = "llamma-model"
  team_name        = "default"
  repo_branch      = "main"

  target_deploy_parameters = { (local.env) = {
    "cluster_project_id"      = var.project_id
    "model_armor_template_id" = module.model_armor_configuration.template.id
    "model_armor_location"    = var.region
    "env_namespace_id"        = "vllm-model-${local.env}"
    }
  }
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_iam_member" "assign_permissions" {
  for_each = toset(["roles/cloudbuild.workerPoolUser", "roles/servicedirectory.viewer", "roles/servicedirectory.pscAuthorizedService"])
  project = module.standalone_harness.workerpool_project_id
  role    = each.value
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "assign_permissions_service_agent" {
  project = module.standalone_harness.workerpool_project_id
  role    = "roles/cloudbuild.workerPoolUser"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_builder" {
  for_each = module.cicd
  project  = module.standalone_harness.workerpool_network_project_id
  role     = "roles/cloudbuild.builds.builder"
  member   = "serviceAccount:${each.value.cloudbuild_service_account}"
}

resource "time_sleep" "wait_propagation" {
  create_duration = "30s"

  depends_on = [
    google_project_iam_member.assign_permissions,
    google_project_iam_member.assign_permissions_service_agent,
  ]
}

module "cicd" {
  source = "../../../modules/deployment-pipeline"

  for_each = var.cloudbuildv2_repository_config.repositories

  project_id                 = var.project_id
  region                     = var.region
  env_cluster_membership_ids = local.cluster_membership_ids
  cluster_service_accounts   = { for i, sa in module.multitenant_infra.cluster_service_accounts : (i) => "serviceAccount:${sa}" }

  service_name           = local.service_name
  team_name              = local.team_name
  repo_name              = each.value.repository_name
  repo_branch            = local.repo_branch
  app_build_trigger_yaml = "cloudbuild.yaml"

  buckets_force_destroy = true

  cloudbuildv2_repository_config = var.cloudbuildv2_repository_config

  workerpool_id     = module.standalone_harness.workerpool_id
  access_level_name = var.access_level_name
  logging_bucket    = var.logging_bucket
  bucket_kms_key    = var.bucket_kms_key

  target_deploy_parameters = local.target_deploy_parameters

  attestation_kms_key = var.attestation_kms_key
  attestor_id         = var.attestation_kms_key != null ? module.fleetscope_infra.attestor_id : null

  binary_authorization_image         = module.standalone_harness.binary_authorization_image
  binary_authorization_repository_id = module.standalone_harness.binary_authorization_repository_id

  depends_on = [
    google_access_context_manager_service_perimeter_egress_policy.egress_policy,
    google_access_context_manager_service_perimeter_dry_run_egress_policy.egress_policy,
    google_access_context_manager_service_perimeter_dry_run_ingress_policy.private_workerpool_deployment,
    google_access_context_manager_service_perimeter_ingress_policy.private_workerpool_deployment,
    module.standalone_harness,
  ]
}

module "model_armor_configuration" {
  source  = "GoogleCloudPlatform/vertex-ai/google//modules/model-armor-template"
  version = "~> 7.3"

  template_id = "ma-${local.application_name}-${local.service_name}"
  location    = var.region
  project_id  = var.project_id

  rai_filters = {
    dangerous         = "LOW_AND_ABOVE"
    sexually_explicit = "MEDIUM_AND_ABOVE"
  }

  enable_malicious_uri_filter_settings = true

  pi_and_jailbreak_filter_settings = "MEDIUM_AND_ABOVE"

  sdp_settings = {
    basic_config_filter_enforcement = true
  }

  metadata_configs = {
    enforcement_type                         = "INSPECT_AND_BLOCK"
    enable_multi_language_detection          = true
    log_sanitize_operations                  = true
    log_template_operations                  = true
    ignore_partial_invocation_failures       = false
    custom_prompt_safety_error_code          = "799"
    custom_prompt_safety_error_message       = "error 799"
    custom_llm_response_safety_error_message = "error 798"
    custom_llm_response_safety_error_code    = "798"
  }

  labels = {
    "model" = "llamma-model"
  }
}

resource "google_service_account" "gsa_llamma_model" {
  project                      = var.project_id
  account_id                   = "gsa-llamma-model"
  display_name                 = "GSA for llamma-model"
  create_ignore_already_exists = true
}

resource "google_project_iam_member" "gsa_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = google_service_account.gsa_llamma_model.member
}

resource "google_service_account_iam_member" "wi_binding" {
  service_account_id = google_service_account.gsa_llamma_model.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[vllm-model-${local.env}/llamma-model-ksa]"
}
