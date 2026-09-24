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

variable "project_id" {
  type = string
}

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
    "legacy-dms"          = { account_id = "mcp-legacy-dms" }
    "corporate-email"     = { account_id = "mcp-corporate-email" }
    "income-verification" = { account_id = "mcp-income-verification" }
  }
}
