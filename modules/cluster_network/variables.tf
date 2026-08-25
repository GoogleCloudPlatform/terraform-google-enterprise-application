/**
 * Copyright 2025 Google LLC
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

variable "vpc_name" {
  description = "The VPC name to be concat with `vpc-` prefix."
  type        = string
}

variable "project_id" {
  description = "The project to deploy in"
  type        = string
}

variable "shared_vpc_host" {
  description = "Makes this project a Shared VPC host if 'true' (default 'false')"
  type        = bool
  default     = false
}

variable "subnets" {
  description = "Sub-networks to be created."
  type        = any
}

variable "secondary_ranges" {
  description = "Secondary ranges that will be used in some of the subnets."
  type        = any
  default     = {}
}

variable "ingress_rules" {
  description = "List of ingress rules. This will be ignored if variable 'rules' is non-empty."
  type        = any
  default     = []
}

variable "egress_rules" {
  description = "List of egress rules. This will be ignored if variable 'rules' is non-empty"
  type        = any
  default     = []
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
    spoke_labels                = optional(map(string))
    spoke_exclude_export_ranges = optional(set(string), [])
    spoke_include_export_ranges = optional(set(string), [])
    spoke_name                  = optional(string, "vpc-spoke")
    spoke_description           = optional(string)
    spoke_group                 = optional(string, "default")
  })

  validation {
    condition = (var.ncc_config.enable_ncc == false || (
      var.ncc_config.enable_ncc == true &&
      var.ncc_config.hub_uri != null
    ))
    error_message = "Invalid NCC configuration. If create_hub is TRUE: hub_uri is required."
  }
}
