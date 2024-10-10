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

variable "common_folder_id" {
  type        = string
  description = "Folder ID in which to create all application admin projects, must be prefixed with 'folders/'"

  validation {
    condition     = can(regex("^folders/", var.common_folder_id))
    error_message = "The folder ID must be prefixed with 'folders/'."
  }
}

variable "org_id" {
  type        = string
  description = "Google Cloud Organization ID."
}

variable "billing_account" {
  type        = string
  description = "Billing Account ID for application admin project resources."
}

variable "envs" {
  description = "Environments"
  type = map(object({
    billing_account    = string
    folder_id          = string
    network_project_id = string
    network_self_link  = string
    org_id             = string
    subnets_self_links = list(string)
  }))
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

variable "remote_state_bucket" {
  description = "Backend bucket to load Terraform Remote State Data from previous steps."
  type        = string
}


# Define Application Services
variable "applications" {
  description = <<-EOF
  A map where the key is the application name, containing the configuration for each microservice under the application. Each microservice has the following properties:
  - **admin_project** (Optional): Admin project associated with the microservice. This hosts microservice specific CI/CD pipelines. If set, `create_admin_project` must be `false`.
  - **create_infra_project** (Required): Indicates whether an infrastructure project should be created for the microservice (one infra project will be created per environment defines in var.envs).
  - **create_admin_project** (Required): Indicates whether a Admin project should be created for the microservice.
  EOF
  type = map(map(object({
    admin_project        = optional(string, null)
    create_infra_project = bool
    create_admin_project = bool
  })))

  validation {
    condition = alltrue(
      [
        for app_name, microservices in var.applications : alltrue(
          [
            for microservice_name, microservice_obj in microservices :
            (microservice_obj.admin_project == null || microservice_obj.create_admin_project == false)
          ]
        )
      ]
    )
    error_message = "If admin_project is specified, the corresponding create_admin_project must be set to false."
  }
}
