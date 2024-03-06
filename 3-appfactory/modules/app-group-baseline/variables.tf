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

variable "application_name" {
  type        = string
  default     = "demo-app"
  description = "The name of a single application."
}

variable "org_id" {
  type        = string
  description = "Google Cloud Organization ID."
}

variable "folder_id" {
  type        = string
  description = "Folder ID of parent folder for application admin resources. If deploying on the enterprise foundation blueprint, this is usually the 'common' folder."
}

variable "billing_account" {
  type        = string
  description = "Billing Account ID for application admin project resources."
}

variable "envs" {
  type = map(any)
}

variable "create_env_projects" {
  type    = bool
  default = true
}

variable "env_project_apis" {
  type        = list(string)
  description = "List of APIs to enable for environment-specific application infra projects"
  default = [
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudbilling.googleapis.com",
  ]
}

variable "cloudbuild_sa_roles" {
  description = "Optional to assign to custom CloudBuild SA. Map of project name or any static key to object with list of roles. Keys much match keys from var.envs"
  type = map(object({
    roles = list(string)
  }))
  default = {}
}
