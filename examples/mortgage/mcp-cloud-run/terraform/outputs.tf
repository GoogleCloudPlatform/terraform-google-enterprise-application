output "artifact_registry_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.mcp.repository_id}"
}
output "cloudbuild_bucket" {
  value = google_storage_bucket.cloudbuild.name
}
output "agent_mcp_invoker_email" {
  value = google_service_account.invoker.email
}
output "mcp_runtime_sa_emails" {
  value = { for k, sa in google_service_account.mcp_runtime : k => sa.email }
}
output "mcp_discovered_servers_json" {
  description = "MCP_DISCOVERED_SERVERS_JSON 6-appsource"
  value = jsonencode([
    {
      name             = "legacy-dms"
      resolved_url     = "https://legacy-dms-XXXX.${var.region}.run.app/mcp"
      tool_name_prefix = "legacy_dms"
      tools            = ["search_documents", "get_document"]
    },
    {
      name             = "corporate-email"
      resolved_url     = "https://corporate-email-XXXX.${var.region}.run.app/mcp"
      tool_name_prefix = "corporate_email"
      tools            = ["send_email", "read_email"]
    },
    {
      name             = "income-verification"
      resolved_url     = "https://income-verification-XXXX.${var.region}.run.app/mcp"
      tool_name_prefix = "income_verification"
      tools            = ["verify_applicant"]
    }
  ])
}
