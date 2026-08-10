# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#-----------------------------------------------------
# Project and Regional Configuration
#-----------------------------------------------------
variable "regions" {
  description = "List of regions where GKE clusters should be created. Used for multi-region deployments."
  type        = list(string)
  default     = ["us-central1"]

  validation {
    condition     = length(var.regions) <= 4
    error_message = "Maximum 4 regions supported"
  }
}

#-----------------------------------------------------
# PubSub Configuration
#-----------------------------------------------------

variable "pubsub_exactly_once" {
  description = "Enable Pub/Sub exactly once subscriptions"
  type        = bool
  default     = true
}

#-----------------------------------------------------
# Quota Configuration
#-----------------------------------------------------

variable "additional_quota_enabled" {
  description = "Enable quota requests for additional resources"
  type        = bool
  default     = false
}

variable "quota_contact_email" {
  description = "Contact email for quota requests"
  type        = string
  default     = ""
}

#-----------------------------------------------------
# Storage Configuration
#-----------------------------------------------------

variable "storage_type" {
  description = "The type of storage system to deploy (PARALLELSTORE, LUSTRE, or null for none)"
  type        = string
  default     = null
}

variable "storage_capacity_gib" {
  description = "Capacity in GiB for the selected storage system (Parallelstore or Lustre)"
  type        = number
  default     = null
}

variable "storage_locations" {
  description = "Map of region to location (zone) for storage instances e.g. {\"us-central1\" = \"us-central1-a\"}"
  type        = map(string)
  default     = {}
}


#-----------------------------------------------------
# Storage Options
#-----------------------------------------------------

variable "hsn_bucket" {
  description = "Enable hierarchical namespace GCS buckets"
  type        = bool
  default     = false
}

#-----------------------------------------------------
# VPC-SC
#-----------------------------------------------------

variable "service_perimeter_name" {
  description = "(VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter."
  type        = string
  default     = null
}

variable "service_perimeter_mode" {
  description = "(VPC-SC) Service perimeter mode: ENFORCE, DRY_RUN."
  type        = string
  default     = "DRY_RUN"

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

variable "infra_project" {
  description = "The infrastructure project where resources will be managed."
  type        = string
}

variable "admin_project" {
  description = "The admin project where cloudbuild/cloudrun configurations will be managed."
  type        = string
}

variable "service_name" {
  type        = string
  description = "service name (e.g. 'transactionhistory')"
}

variable "region" {
  description = "The region where the cloud resources will be deployed."
  type        = string
}


variable "network_name" {
  description = "VPC Network Name"
  type        = string
}

variable "network_self_link" {
  description = "VPC Network self link"
  type        = string
}

variable "gke_cluster_names" {
  description = "GKE Cluster Name to be used in configurations"
  type        = list(string)
}

variable "parallelstore_deployment_type" {
  description = "Parallelstore Instance deployment type (SCRATCH or PERSISTENT)"
  type        = string
  default     = "SCRATCH"

  validation {
    condition     = contains(["SCRATCH", "PERSISTENT"], var.parallelstore_deployment_type)
    error_message = "deployment_type must be either SCRATCH or PERSISTENT"
  }
}

variable "cluster_project_id" {
  type        = string
  description = "The GCP project ID where the cluster is created."
}

variable "cluster_project_number" {
  type        = string
  description = "The GCP project ID where the cluster is created."
}

variable "team" {
  description = "Environment Team, must be the same as the fleet scope team"
  type        = string
}

variable "env" {
  description = "The environment to prepare (ex. development)"
  type        = string
}

variable "enable_csi_parallelstore" {
  description = "Enable the Parallelstore CSI Driver"
  type        = bool
  default     = true
}
