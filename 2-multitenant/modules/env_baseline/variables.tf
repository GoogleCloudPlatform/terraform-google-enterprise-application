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

variable "env" {
  description = "The environment to prepare (ex. development)"
  type        = string
}

variable "org_id" {
  description = "Organization ID"
  type        = string
}

variable "folder_id" {
  description = "Folder ID"
  type        = string
}

variable "create_cluster_project" {
  description = "Create Cluster Project ID, otherwise the Network Project ID is used"
  type        = bool
  default     = true
}

variable "network_project_id" {
  description = "Network Project ID"
  type        = string
}

variable "billing_account" {
  description = "The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ"
  type        = string
}

variable "cluster_subnetworks" {
  description = "The subnetwork self_links for clusters"
  type        = list(string)
}

variable "cluster_release_channel" {
  description = "The release channel for the clusters"
  type        = string
  default     = "REGULAR"
}

variable "apps" {
  description = "Applications"
  type = map(object({
    acronyms = string
    ip_address_names = optional(list(string))
    certificates     = optional(map(list(string)))
  }))
}

variable "cluster_type" {
  description = "GKE multi-tenant cluster types: STANDARD, STANDARD-NAP (Standard with node auto-provisioning), AUTOPILOT"
  type        = string
  default     = "STANDARD-NAP"

  validation {
    condition     = contains(["STANDARD", "STANDARD-NAP", "AUTOPILOT"], var.cluster_type)
    error_message = "The cluster_type value must be one of: STANDARD, STANDARD-NAP, AUTOPILOT."
  }
}
