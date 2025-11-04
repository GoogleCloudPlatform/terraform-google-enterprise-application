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
  service_name     = "hello-agent"
  team_name        = "default"
  repo_name        = "eab-${local.application_name}-${local.service_name}"
  repo_branch      = "main"

  negs = [for i in data.google_compute_network_endpoint_group.agent_neg : i.id if strcontains(i.self_link, "capital-agent-service")]
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
  version = "~> 2.0"

  for_each    = local.cluster_projects_id
  template_id = "ma-${local.application_name}-${local.service_name}"
  location    = "us"
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
    log_template_operations                  = false
    ignore_partial_invocation_failures       = false
    custom_prompt_safety_error_code          = "799"
    custom_prompt_safety_error_message       = "error 799"
    custom_llm_response_safety_error_message = "error 798"
    custom_llm_response_safety_error_code    = "798"
  }

  labels = {
    "foo" = "bar"
  }
}

resource "null_resource" "create_service_extension" {
  for_each = local.backend_services_names

  triggers = {
    location = regex("/regions/([^/]+)/", each.value)[0]
    project  = local.cluster_projects_id[each.key]
    file     = data.template_file.url_map_config[each.key].rendered
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud service-extensions lb-traffic-extensions import traffic-ext \
      --location=${self.triggers.location} \
      --project=${self.triggers.project} \
      --source=- <<CONFIG
      ${data.template_file.url_map_config[each.key].rendered}
      CONFIG
    EOT
  }
}

data "template_file" "url_map_config" {
  for_each = local.backend_services_names
  template = file("${path.module}/traffic_callout_service.yaml")

  # Variáveis a serem injetadas no template YAML
  vars = {
    url_map_name            = "traffic_callout_service_${regex("/regions/([^/]+)/", each.value)[0]}"
    forwarding_rule         = local.forwarding_rule_ids[each.key]
    project_id              = local.cluster_projects_id[each.key]
    region                  = regex("/regions/([^/]+)/", each.value)[0]
    model_name              = "meta-llama/Llama-3.1-8B-Instruct"
    model_armor_template_id = module.model_armor_configuration[each.key].template.id
  }
}

data "google_compute_network_endpoint_group" "agent_neg" {
  for_each = local.cluster_zones
  project  = local.cluster_projects_id[each.value.env]
  zone     = each.value.zone
  name     = "k8s1-5087f385-default-capital-agent-service-8080-98c69603"
}

resource "google_compute_region_backend_service" "backend_agent" {
  for_each              = local.backend_services_names
  name                  = "bs-capital-agent-${regex("/regions/([^/]+)/", each.value)[0]}"
  project               = local.cluster_projects_id[each.key]
  region                = regex("/regions/([^/]+)/", each.value)[0]
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  dynamic "backend" {
    for_each = local.negs
    content {
      group                 = backend.value
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 100
      capacity_scaler       = 1.0

    }
  }

  health_checks = [for i in google_compute_region_health_check.default : i.id]

  log_config { enable = true }
}

resource "google_compute_region_health_check" "default" {
  for_each = local.backend_services_names
  name     = "health-check-capital-agent-${regex("/regions/([^/]+)/", each.value)[0]}"
  project  = local.cluster_projects_id[each.key]
  region   = regex("/regions/([^/]+)/", each.value)[0]

  http_health_check {
    port         = 8080
    request_path = "/healthz" # ou "/" se seu app retornar 200 proxy_header = "NONE"
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

resource "google_service_account_iam_member" "wi_binding" {
  for_each           = google_service_account.gsa_capital_agent
  service_account_id = each.value.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${each.value.project}.svc.id.goog[default/capital-agent-ksa]"
}
