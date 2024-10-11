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

variable "service_name" {
  type        = string
  default     = "demo-app"
  description = "The name of a single service application."
}

variable "acronym" {
  type        = string
  description = "The acronym of the application."
  validation {
    condition     = length(var.acronym) <= 3
    error_message = "The max length for acronym is 3 characters."
  }
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
  type = map(object({
    billing_account    = string
    folder_id          = string
    network_project_id = string
    network_self_link  = string
    org_id             = string
    subnets_self_links = list(string)
  }))
  description = "Environments"
}

variable "infra_project_apis" {
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

variable "bucket_prefix" {
  description = "Name prefix to use for buckets created."
  type        = string
  default     = "bkt"
}

variable "bucket_force_destroy" {
  description = "When deleting a bucket, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects."
  type        = bool
  default     = false
}

variable "location" {
  description = "Location for build buckets."
  type        = string
  default     = "us-central1"
}

variable "trigger_location" {
  description = "Location of for Cloud Build triggers created in the workspace. If using private pools should be the same location as the pool."
  type        = string
  default     = "global"
}

variable "tf_apply_branches" {
  description = "List of git branches configured to run terraform apply Cloud Build trigger. All other branches will run plan by default."
  type        = list(string)
  default     = ["development", "nonproduction", "production"]
}

variable "admin_project_id" {
  description = "The admin project associated with the microservice. This project will host resources like microservice CI/CD pipelines. If set, `create_admin_project` must be set to `false`."
  type        = string
}

variable "create_infra_project" {
  description = "Boolean value that indicates whether an infrastructure project should be created for the microservice."
  type        = bool
}

variable "create_admin_project" {
  description = "Boolean value that indicates whether a admin project should be created for the microservice."
  type        = bool
}

