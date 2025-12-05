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

# Define Multi-Tenant Environments
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

# Define Applications
variable "apps" {
  description = <<-EOF
  A map, where the key is the application name, defining the application configurations with the following properties:
  - **acronym** (Required): A short identifier for the application with a maximum of 3 characters in length.
  - **ip_address_names** (Optional): A list of IP address names associated with the application.
  - **certificates** (Optional): A map of certificate names to a list of certificate values required by the application.
  EOF
  type = map(object({
    acronym          = string
    ip_address_names = optional(list(string), [])
    certificates     = optional(map(list(string)), {})
  }))
  validation {
    condition     = alltrue([for o in var.apps : length(o.acronym) <= 3])
    error_message = "The max length for acronym is 3 characters."
  }
}

variable "service_perimeter_name" {
  description = "(VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter."
  type        = string
  default     = null
}

variable "service_perimeter_mode" {
  description = "(VPC-SC) Service perimeter mode: ENFORCE, DRY_RUN."
  type        = string
  default     = "ENFORCE"

  validation {
    condition     = contains(["ENFORCE", "DRY_RUN"], var.service_perimeter_mode)
    error_message = "The service_perimeter_mode value must be one of: ENFORCE, DRY_RUN."
  }
}

variable "cb_private_workerpool_project_id" {
  description = "Private Worker Pool Project ID used for Cloud Build Triggers."
  type        = string
  default     = ""
}

variable "access_level_name" {
  description = "(VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter."
  type        = string
  default     = null
}

variable "deletion_protection" {
  type        = bool
  description = "Whether or not to allow Terraform to destroy the cluster."
  default     = true
}

variable "cluster_release_channel" {
  description = "The release channel for the clusters"
  type        = string
  default     = "REGULAR"
}
