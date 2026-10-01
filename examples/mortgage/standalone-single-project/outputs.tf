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
  mcp_tools = {
    "legacy-dms"          = ["search_documents", "get_document"]
    "corporate-email"     = ["send_email", "read_email"]
    "income-verification" = ["verify_applicant"]
  }
  mcp_prefixes = {
    "legacy-dms"          = "legacy_dms"
    "corporate-email"     = "corporate_email"
    "income-verification" = "income_verification"
  }
}

output "cluster_project_id" {
  description = "Cluster Project ID"
  value       = module.multitenant_infra.cluster_project_id
}

output "cluster_project_number" {
  description = "Cluster Project Number"
  value       = module.multitenant_infra.cluster_project_number
}

output "network_project_id" {
  description = "Network Project ID"
  value       = module.multitenant_infra.network_project_id
}

output "fleet_project_id" {
  description = "Fleet Project ID"
  value       = module.multitenant_infra.fleet_project_id
}

output "env" {
  description = "Environment"
  value       = local.env
}

output "cluster_regions" {
  description = "Regions with clusters"
  value       = module.multitenant_infra.cluster_regions
}

output "cluster_membership_ids" {
  description = "GKE cluster membership IDs"
  value       = module.multitenant_infra.cluster_membership_ids
}

output "gke_agent_sa_email" {
  description = "GSA for mortgage-agent."
  value       = google_service_account.gsa_mortgage_agent.member
}

output "app_ip_addresses" {
  description = "App IP Addresses"
  value       = module.multitenant_infra.app_ip_addresses
}

output "app_certificates" {
  description = "App Certificates"
  value       = module.multitenant_infra.app_certificates
}

output "acronyms" {
  description = "App Acronyms"
  value       = { for k, v in local.apps : (k) => v.acronym }
}

output "cluster_type" {
  description = "Cluster type"
  value       = module.multitenant_infra.cluster_type
}

output "cluster_service_accounts" {
  description = "The default service accounts used for nodes, if not overridden in node_pools."
  value       = module.multitenant_infra.cluster_service_accounts
}

output "clouddeploy_targets_names" {
  description = "Cloud deploy targets names."
  value       = { for k, cicd in module.cicd : k => cicd.clouddeploy_targets_names }
}

output "service_repository_name" {
  description = "The Source Repository name."
  value       = { for k, cicd in module.cicd : k => cicd.service_repository_name }
}

output "service_repository_project_id" {
  description = "The Source Repository project id."
  value       = { for k, cicd in module.cicd : k => cicd.service_repository_project_id }
}

// MCPs outputs

output "artifact_registry_url" {
  description = "The Artifact Registry repository URL for docker push/pull"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.mcp.repository_id}"
}

output "cloudbuild_bucket" {
  description = "Cloud Build MCPs bucket name."
  value       = google_storage_bucket.cloudbuild.name
}

output "agent_mcp_invoker_email" {
  description = "Email of the SA agents impersonate when invoking MCP Cloud Run services."
  value       = google_service_account.invoker.email
}

output "mcp_runtime_sa_emails" {
  description = "Emails of the service accounts used for MCP runtime."
  value       = { for k, sa in google_service_account.mcp_runtime : k => sa.email }
}

output "mcp_service_urls" {
  description = "Cloud Run service base URLs"
  value       = { for k, svc in google_cloud_run_v2_service.mcp : k => svc.uri }
}

output "mcp_discovered_servers_json" {
  description = "MCP_DISCOVERED_SERVERS_JSON on 6-appsource"
  value = jsonencode([
    for name, svc in google_cloud_run_v2_service.mcp : {
      name             = name
      resolved_url     = "${trimsuffix(svc.uri, "/")}/mcp"
      tool_name_prefix = lookup(local.mcp_prefixes, name, replace(name, "-", "_"))
      tools            = lookup(local.mcp_tools, name, [])
    }
  ])
}
