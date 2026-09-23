variable "project_id" { type = string }
variable "region" {
  type    = string
  default = "us-central1"
}
variable "artifact_registry_id" {
  type    = string
  default = "mcp-docker"
}
variable "gke_agent_sa_email" {
  type        = string
  description = "e.g. gsa-mortgage-agent@PROJECT.iam.gserviceaccount.com"
}
variable "mcp_services" {
  type = map(object({
    account_id = string
  }))
  default = {
    "legacy-dms" = { account_id = "mcp-legacy-dms" }
    "corporate-email" = { account_id = "mcp-corporate-email" }
    "income-verification" = { account_id = "mcp-income-verification" }
  }
}
