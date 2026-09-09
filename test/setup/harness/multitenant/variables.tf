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

variable "org_id" {
  description = "The numeric organization id"
  type        = string
}

variable "seed_project_id" {
  description = "The seed project."
  type        = string
}

variable "branch_name" {
  type        = string
  description = "The branch starting the build."
}

variable "seed_folder_id" {
  description = "The folder to deploy in"
  type        = string
}

variable "billing_account" {
  description = "The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ"
  type        = string
}

variable "sa_email" {
  description = "The ci service account email created by setup to run the tests."
  type        = string
}

variable "sa_id" {
  description = "The ci service account id created by setup to run the tests."
  type        = string
}

variable "hpc" {
  description = "If HPC example will be deployed."
  type        = bool
}

variable "agent" {
  description = "If AGENT example will be deployed."
  type        = bool
}

variable "ncc_config" {
  description = <<-EOT
    Configuration block for Google Cloud Network Connectivity Center (NCC) Spokes.
    - enable_ncc: (bool) Toggles whether to create a new NCC spoke.
    - hub_uri: (string) The URI of an existing Hub. [Required if enable_ncc is TRUE]
    - spoke_group: (string) The NCC group the spoke belongs to (default: "default").
    - spoke_name: (string) Name for the main VPC spoke.
    - spoke_description: (string) Description for the main VPC spoke.
    - spoke_labels: (map) Labels for the main VPC spoke.
    - spoke_exclude_export_ranges: (set of strings) IP ranges to exclude from route export.
    - spoke_include_export_ranges: (set of strings) IP ranges to explicitly include in route export.
  EOT
  type = object({
    enable_ncc                  = optional(bool, false)
    hub_uri                     = optional(string)
    spoke_group                 = optional(string, "default")
    spoke_name                  = optional(string, "vpc-spoke")
    spoke_description           = optional(string)
    spoke_labels                = optional(map(string))
    spoke_exclude_export_ranges = optional(set(string), [])
    spoke_include_export_ranges = optional(set(string), [])
  })

  default = {}

  validation {
    condition = (var.ncc_config.enable_ncc == false || (
      var.ncc_config.enable_ncc == true &&
      var.ncc_config.hub_uri != null
    ))
    error_message = "Invalid NCC configuration. If enable_ncc is TRUE: hub_uri is required."
  }
}
