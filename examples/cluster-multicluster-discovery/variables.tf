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
  type        = string
  description = "Google Cloud project ID in which to deploy all example resources"
}

variable "regions" {
  type        = list(string)
  description = "Google Cloud regions for cluster"
}

variable "base_cidr" {
  type        = string
  description = "Base CIDR for the VPC primary ranges"
  default     = "10.1.0.0/16"
}

variable "pods_base_cidr" {
  type        = string
  description = "Base CIDR for Kubernetes Pods secondary ranges"
  default     = "10.2.0.0/16"
}

variable "services_base_cidr" {
  type        = string
  description = "Base CIDR for Kubernetes Services secondary ranges"
  default     = "10.3.0.0/16"
}

variable "teams" {
  type        = map(string)
  description = "A map of string at the format {\"namespace\" = \"groupEmail\"}"
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

variable "access_level_name" {
  description = "(VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter."
  type        = string
  default     = null
}

variable "attestation_kms_key" {
  type        = string
  description = "The KMS Key ID to be used by attestor."
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

variable "disable_istio_on_namespaces" {
  type        = list(string)
  description = "List the namespaces where you don't want the service mesh to be enabled (i.e. sidecar proxy injection). Ensure that the namespace names match exactly with those defined in 'var.namespace_ids'."
  default     = []
}

variable "config_sync_policy_dir" {
  type        = string
  description = "The path within the Git repository that represents the top level of the repo to sync"
  default     = null
}

variable "config_sync_branch" {
  type        = string
  description = "The branch of the repository to sync from. Default: master"
  default     = "master"
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
    error_message = "Invalid NCC configuration. If create_hub is TRUE: hub_uri is required."
  }
}
