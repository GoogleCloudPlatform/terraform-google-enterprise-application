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

locals {
  application_name = "agent"
  service_name     = "capital-agent"
  team_name        = "default"
  repo_name        = "eab-${local.application_name}-${local.service_name}"
  repo_branch      = "main"
}

module "app" {
  source = "../../modules/cicd-pipeline"

  project_id                 = local.app_admin_project
  region                     = var.region
  env_cluster_membership_ids = local.cluster_membership_ids
  cluster_service_accounts   = { for i, sa in local.cluster_service_accounts : (i) => "serviceAccount:${sa}" }

  service_name           = local.service_name
  team_name              = local.team_name
  repo_name              = var.cloudbuildv2_repository_config.repositories[local.repo_name].repository_name
  repo_branch            = local.repo_branch
  app_build_trigger_yaml = "cloudbuild.yaml"

  buckets_force_destroy = var.buckets_force_destroy
  bucket_prefix         = var.bucket_prefix

  cloudbuildv2_repository_config = var.cloudbuildv2_repository_config

  workerpool_id     = data.terraform_remote_state.bootstrap.outputs.cb_private_workerpool_id
  access_level_name = var.access_level_name
  logging_bucket    = var.logging_bucket
  bucket_kms_key    = var.bucket_kms_key

  attestation_kms_key                = var.attestation_kms_key
  attestor_id                        = var.attestation_kms_key != null ? contains(var.environment_names, "production") ? data.terraform_remote_state.fleetscope["production"].outputs.attestor_id : data.terraform_remote_state.fleetscope[var.environment_names[0]].outputs.attestor_id : null
  binary_authorization_image         = data.terraform_remote_state.bootstrap.outputs.binary_authorization_image
  binary_authorization_repository_id = data.terraform_remote_state.bootstrap.outputs.binary_authorization_repository_id
}

module "model_armor_configuration" {
  source  = "GoogleCloudPlatform/vertex-ai/google//modules/model-armor-template"
  version = "~> 2.3"

  for_each    = local.cluster_projects_id
  template_id = "ma-${local.application_name}-${local.service_name}"
  location    = var.region
  project_id  = each.value

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
    "agent" = "capital-agent"
  }
}

resource "google_service_account" "gsa_capital_agent" {
  for_each     = local.cluster_projects_id
  project      = each.value
  account_id   = "gsa-capital-agent"
  display_name = "GSA for capital-agent"
}

resource "google_project_iam_member" "gsa_vertex_user" {
  for_each = google_service_account.gsa_capital_agent
  project  = each.value.project
  role     = "roles/aiplatform.user"
  member   = each.value.member
}

resource "google_project_iam_member" "gsa_trace_agent" {
  for_each = google_service_account.gsa_capital_agent
  project  = each.value.project
  role     = "roles/cloudtrace.agent"
  member   = each.value.member
}

resource "google_service_account_iam_member" "wi_binding" {
  for_each           = google_service_account.gsa_capital_agent
  service_account_id = each.value.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${each.value.project}.svc.id.goog[capital-agent-${each.key}/capital-agent-ksa]"
}
