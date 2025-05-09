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

variable "project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
  default     = "YOUR_PROJECT_ID"

  # Validation to ensure the project_id is set
  validation {
    condition     = var.project_id != "YOUR_PROJECT_ID"
    error_message = "The 'project_id' variable must be set in terraform.tfvars or on the command line."
  }
}

variable "regions" {
  description = "List of regions where GKE clusters should be created. Used for multi-region deployments."
  type        = list(string)
  default     = ["us-central1"]

  validation {
    condition     = length(var.regions) <= 4
    error_message = "Maximum 4 regions supported"
  }
}

variable "clusters_per_region" {
  description = "Map of regions to number of clusters to create in each (maximum 4 per region)"
  type        = map(number)
  default     = { "us-central1" = 1 }

  validation {
    condition     = alltrue([for count in values(var.clusters_per_region) : count <= 4])
    error_message = "Maximum 4 clusters per region allowed"
  }
}

#-----------------------------------------------------
# Deployment Options
#-----------------------------------------------------

variable "cloudrun_enabled" {
  description = "Enable Cloud Run deployment alongside GKE"
  type        = bool
  default     = true
}

variable "ui_image_enabled" {
  description = "Enable or disable the building of the UI image"
  type        = bool
  default     = false
}

#-----------------------------------------------------
# Output Configuration
#-----------------------------------------------------

variable "scripts_output" {
  description = "Output directory for testing scripts"
  type        = string
  default     = "./generated"
}

#-----------------------------------------------------
# PubSub Configuration
#-----------------------------------------------------

variable "pubsub_exactly_once" {
  description = "Enable Pub/Sub exactly once subscriptions"
  type        = bool
  default     = true
}

variable "request_topic" {
  description = "Request topic for tasks"
  type        = string
  default     = "request"
}

variable "request_subscription" {
  description = "Request subscription for tasks"
  type        = string
  default     = "request_sub"
}

variable "response_topic" {
  description = "Response topic for tasks"
  type        = string
  default     = "response"
}

variable "response_subscription" {
  description = "Response subscription for tasks"
  type        = string
  default     = "response_sub"
}

#-----------------------------------------------------
# BigQuery Configuration
#-----------------------------------------------------

variable "dataset_id" {
  description = "BigQuery dataset in the project to create the tables"
  type        = string
  default     = "pubsub_msgs"
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
# GKE Cluster Configuration
#-----------------------------------------------------

variable "gke_standard_cluster_name" {
  description = "Base name for GKE clusters"
  type        = string
  default     = "gke-risk-research"
}

variable "node_machine_type_ondemand" {
  description = "Machine type for on-demand node pools"
  type        = string
  default     = "n2-standard-16"
}

variable "node_machine_type_spot" {
  description = "Machine type for spot node pools"
  type        = string
  default     = "n2-standard-64"
}

variable "min_nodes_ondemand" {
  description = "Minimum number of on-demand nodes"
  type        = number
  default     = 0
}

variable "max_nodes_ondemand" {
  description = "Maximum number of on-demand nodes"
  type        = number
  default     = 32
}

variable "min_nodes_spot" {
  description = "Minimum number of spot nodes"
  type        = number
  default     = 1
}

variable "max_nodes_spot" {
  description = "Maximum number of spot nodes"
  type        = number
  default     = 3000
}

variable "scaled_control_plane" {
  description = "Deploy a larger initial nodepool to ensure larger control plane nodes are provisioned"
  type        = bool
  default     = false
}

variable "cluster_max_cpus" {
  description = "Maximum CPU cores in cluster autoscaling resource limits"
  type        = number
  default     = 10000
}

variable "cluster_max_memory" {
  description = "Maximum memory (in GB) in cluster autoscaling resource limits"
  type        = number
  default     = 80000
}

#-----------------------------------------------------
# Storage Configuration
#-----------------------------------------------------

variable "storage_type" {
  description = "The type of storage system to deploy (PARALLELSTORE, LUSTRE, or null for none)"
  type        = string
  default     = null

  validation {
    condition     = var.storage_type == null || contains(["PARALLELSTORE", "LUSTRE"], var.storage_type)
    error_message = "The storage_type must be null, PARALLELSTORE, or LUSTRE."
  }
}

variable "storage_capacity_gib" {
  description = "Capacity in GiB for the selected storage system (Parallelstore or Lustre)"
  type        = number
  default     = null

  validation {
    condition     = var.storage_capacity_gib == null || var.storage_capacity_gib > 0
    error_message = "Storage capacity must be a positive number."
  }
}

variable "storage_locations" {
  description = "Map of region to location (zone) for storage instances e.g. {\"us-central1\" = \"us-central1-a\"}"
  type        = map(string)
  default     = {}
}

variable "deployment_type" {
  description = "Parallelstore Instance deployment type (SCRATCH or PERSISTENT)"
  type        = string
  default     = "SCRATCH"

  validation {
    condition     = contains(["SCRATCH", "PERSISTENT"], var.deployment_type)
    error_message = "deployment_type must be either SCRATCH or PERSISTENT."
  }
}

#-----------------------------------------------------
# Lustre Configuration
#-----------------------------------------------------

variable "lustre_filesystem" {
  description = "The name of the Lustre filesystem"
  type        = string
  default     = "lustre-fs"
}

variable "lustre_gke_support_enabled" {
  description = "Enable GKE support for Lustre instance"
  type        = bool
  default     = true
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
# Network Configuration
#-----------------------------------------------------

variable "vpc_name" {
  description = "Name of the VPC network to create"
  type        = string
  default     = "research-vpc"
}

variable "storage_ip_range" {
  description = "IP range for Storage peering, in CIDR notation"
  type        = string
  default     = "172.16.0.0/16"
}

#-----------------------------------------------------
# Artifact Registry Configuration
#-----------------------------------------------------

variable "artifact_registry_name" {
  description = "Name of the Artifact Registry repository"
  type        = string
  default     = "research-images"
}

#-----------------------------------------------------
# Security Configuration
#-----------------------------------------------------

variable "cluster_service_account" {
  description = "Service Account ID for GKE clusters"
  type        = string
  default     = "gke-risk-research-cluster-sa"
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity for GKE clusters"
  type        = bool
  default     = true
}

#-----------------------------------------------------
# CSI Drivers Configuration
#-----------------------------------------------------

variable "enable_csi_parallelstore" {
  description = "Enable the Parallelstore CSI Driver"
  type        = bool
  default     = true
}

variable "enable_csi_filestore" {
  description = "Enable the Filestore CSI Driver"
  type        = bool
  default     = false
}

variable "enable_csi_gcs_fuse" {
  description = "Enable the GCS Fuse CSI Driver"
  type        = bool
  default     = true
}
