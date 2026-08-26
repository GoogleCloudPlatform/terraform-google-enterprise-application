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

  team_name    = "agent"
  service_name = "capital-agent"
}

data "google_project" "project" {
  project_id = module.standalone_harness.project_id
}


resource "google_project_iam_member" "assign_permissions" {
  project = module.standalone_harness.workerpool_project_id
  role    = "roles/cloudbuild.workerPoolUser"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "assign_network_permissions" {
  for_each = toset(["roles/servicedirectory.viewer", "roles/servicedirectory.pscAuthorizedService"])
  project  = module.standalone_harness.workerpool_network_project_id
  role     = each.value
  member   = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
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
    google_project_iam_member.assign_network_permissions,
    google_project_iam_member.assign_permissions_service_agent,
    google_project_iam_member.cloudbuild_builder,
  ]
}

module "cicd" {
  source   = "../../../modules/deployment-pipeline"
  for_each = var.cloudbuildv2_repository_config.repositories

  project_id                 = module.standalone_harness.project_id
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

  private_workerpool = {
    use_private_workerpool = true
    private_workerpool_id  = module.standalone_harness.workerpool_id
  }

  logging_bucket = var.logging_bucket
  bucket_kms_key = var.bucket_kms_key

  access_level_name = var.access_level_name

  service_perimeter_name = var.service_perimeter_name
  service_perimeter_mode = var.service_perimeter_mode

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

resource "google_service_account" "gsa_capital_agent" {
  project      = module.standalone_harness.project_id
  account_id   = "gsa-capital-agent"
  display_name = "GSA for capital-agent"

  depends_on = [module.standalone_harness]
}

resource "google_project_iam_member" "gsa_vertex_user" {
  project = module.standalone_harness.project_id
  role    = "roles/aiplatform.user"
  member  = google_service_account.gsa_capital_agent.member

  depends_on = [module.standalone_harness]
}

resource "google_project_iam_member" "gsa_trace_agent" {
  project = module.standalone_harness.project_id
  role    = "roles/cloudtrace.agent"
  member  = google_service_account.gsa_capital_agent.member

  depends_on = [module.standalone_harness]
}

resource "google_service_account_iam_member" "wi_binding" {
  service_account_id = google_service_account.gsa_capital_agent.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${module.standalone_harness.project_id}.svc.id.goog[capital-agent-${local.env}/capital-agent-ksa]"

  depends_on = [module.fleetscope_infra]
}
