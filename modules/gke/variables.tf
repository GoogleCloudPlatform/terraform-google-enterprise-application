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
  description = "The subnetwork self_links for clusters. Adding more subnetworks will increase the number of clusters. You will need a IP block defined on `master_ipv4_cidr_blocks` variable for each cluster subnetwork."
  type        = list(string)
}

variable "cluster_release_channel" {
  description = "The release channel for the clusters"
  type        = string
  default     = "REGULAR"
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
    ip_address_names = optional(list(string))
    certificates     = optional(map(list(string)))
  }))
  validation {
    condition     = alltrue([for o in var.apps : length(o.acronym) <= 3])
    error_message = "The max length for acronym is 3 characters."
  }
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

variable "master_ipv4_cidr_blocks" {
  description = "List of IP ranges (One range per cluster) in CIDR notation to use for the hosted master network. This range will be used for assigning private IP addresses to the cluster master(s) and the ILB VIP. This range must not overlap with any other ranges in use within the cluster's network, and it must be a /28 subnet."
  type        = list(string)
  default     = ["10.11.10.0/28", "10.11.20.0/28"]
}

variable "service_perimeter_name" {
  description = "(VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter."
  type        = string
  default     = null
}

variable "service_perimeter_mode" {
  description = "(VPC-SC) Service perimeter mode: ENFORCE, DRY_RUN."
  type        = string
  default     = null
}

variable "access_level_name" {
  description = "(VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter."
  type        = string
  default     = null
}

variable "cb_private_workerpool_project_id" {
  description = "Private Worker Pool Project ID used for Cloud Build Triggers. It is going to create an Egress rule from Cluster project to Workerpool project in case you are deploying the solution inside of a VPC-SC."
  type        = string
  default     = ""
}

variable "enable_confidential_nodes" {
  type        = bool
  description = "An optional flag to enable confidential node config."
  default     = false
}

variable "deletion_protection" {
  type        = bool
  description = "Whether or not to allow Terraform to destroy the cluster."
  default     = true
}

variable "enable_csi_gcs_fuse" {
  description = "Enable the GCS Fuse CSI Driver for HTC example"
  type        = bool
  default     = false
}
