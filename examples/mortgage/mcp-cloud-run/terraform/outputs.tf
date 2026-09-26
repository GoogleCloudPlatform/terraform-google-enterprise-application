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
