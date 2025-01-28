/**
 * Copyright 2024 Google LLC
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

variable "namespace_ids" {
  description = "The fleet namespace IDs with team"
  type        = map(string)
}

variable "remote_state_bucket" {
  description = "Backend bucket to load Terraform Remote State Data from previous steps."
  type        = string
}

variable "config_sync_secret_type" {
  description = "The type of `Secret` configured for access to the Config Sync Git repo. Must be `ssh`, `cookiefile`, `gcenode`, `gcpserviceaccount`, `githubapp`, `token`, or `none`. Depending on the credential type, additional steps must be executed prior to this step. Refer to the following documentation for guidance: https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync#git-creds-secret"
  type        = string
  default     = "gcpserviceaccount"
}

variable "config_sync_repository_url" {
  description = "The Git repository url for Config Sync. If `config_sync_secret_type` value is `gcpserviceaccount`, a Cloud Source Repository will automatically be created and this variable will be ignored."
  type        = string
  default     = ""
}

