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

  cluster_membership_ids = { (local.env) : { "cluster_membership_ids" : module.multitenant_infra.cluster_membership_ids } }

  sa_cb = [for cicd in module.cicd : "serviceAccount:${cicd.cloudbuild_service_account}"]
  secret_project_number = try(
    regex("projects/([^/]*)/", var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id)[0],
    regex("projects/([^/]*)/", var.cloudbuildv2_repository_config.github_secret_id)[0],
    null
  )

  team_name    = "mortgage"
  service_name = "mortgage-agent"

  # Agent Identity trust domain: org-scoped when an organization is available,
  # otherwise project-scoped (projects without an organization).
  agent_org_id = try(coalesce(var.organization_id, data.google_project.project.org_id), "")
  agent_trust_domain = (
    local.agent_org_id != ""
    ? "agents.global.org-${local.agent_org_id}.system.id.goog"
    : "agents.global.proj-${data.google_project.project.number}.system.id.goog"
  )
  agent_identity_spiffe = "spiffe://${local.agent_trust_domain}/*"
  agent_identity_principal = join("/", [
    "principal://${local.agent_trust_domain}/resources/container/projects",
    module.multitenant_infra.cluster_project_number,
    "locations",
    var.region,
    "clusters",
    module.multitenant_infra.cluster_names[0],
    "ns",
    "mortgage-agent-${local.env}",
    "sa",
    "mortgage-agent-ksa",
  ])

  target_deploy_parameters = { (local.env) : {
    "PROJECT_ID"           = var.project_id
    "MODEL_ID"             = var.model_id
    "SERVICE_ACCOUNT"      = google_service_account.gsa_mortgage_agent.email
    "MCP_INVOKER_SA_EMAIL" = google_service_account.invoker.email
    "AGENT_IDENTITY"       = local.agent_identity_spiffe
    }
  }
}

data "google_project" "project" {
  project_id = var.project_id
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

resource "google_project_iam_member" "cloudbuild_sa_user" {
  for_each = module.cicd
  project  = var.project_id
  role     = "roles/iam.serviceAccountUser"
  member   = "serviceAccount:${each.value.cloudbuild_service_account}"
}

module "cicd" {
  source   = "GoogleCloudPlatform/enterprise-application/google//modules/deployment-pipeline"
  version  = "~> 0.7"
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

  ci_build_included_files = ["**"]

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

  target_deploy_parameters = local.target_deploy_parameters

  depends_on = [
    google_access_context_manager_service_perimeter_egress_policy.egress_policy,
    google_access_context_manager_service_perimeter_dry_run_egress_policy.egress_policy,
    google_access_context_manager_service_perimeter_dry_run_ingress_policy.private_workerpool_deployment,
    google_access_context_manager_service_perimeter_ingress_policy.private_workerpool_deployment,
    google_cloud_run_v2_service.mcp,
    module.standalone_harness,
  ]
}

resource "google_service_account" "gsa_mortgage_agent" {
  project      = var.project_id
  account_id   = "gsa-mortgage-agent"
  display_name = "GSA for mortgage-agent"
}

resource "google_project_iam_member" "gsa_mortgage_roles" {
  for_each = toset([
    "roles/aiplatform.user",
    "roles/cloudtrace.agent",
  ])
  project = var.project_id
  role    = each.value
  member  = google_service_account.gsa_mortgage_agent.member
}

resource "google_service_account_iam_member" "mortgage_wi_binding" {
  service_account_id = google_service_account.gsa_mortgage_agent.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[mortgage-agent-${local.env}/mortgage-agent-ksa]"

  depends_on = [module.fleetscope_infra]
}

# Agent Identity IAM (SPIFFE principal). ADC with google-auth >= 2.61 uses this
# principal when the Pod requests an agent identity and injects certificates.
resource "google_project_iam_member" "agent_identity_roles" {
  for_each = toset([
    "roles/aiplatform.user",
    "roles/cloudtrace.agent",
  ])
  project = var.project_id
  role    = each.value
  member  = local.agent_identity_principal

  depends_on = [module.multitenant_infra]
}

resource "google_service_account_iam_member" "agent_identity_token_creator" {
  service_account_id = google_service_account.invoker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.agent_identity_principal

  depends_on = [module.multitenant_infra]
}
