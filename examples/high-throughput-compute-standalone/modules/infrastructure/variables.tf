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
  type        = string
  default     = "YOUR_PROJECT_ID"
  description = "The GCP project ID where resources will be created."

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

variable "zones" {
  type        = list(string)
  description = "The GCP zone letters to deploy resources to within specified regions (e.g., 'a' for us-central1-a)."
  default     = ["a", "b", "c"]
}

#-----------------------------------------------------
# Network Configuration
#-----------------------------------------------------

variable "vpc_name" {
  type        = string
  description = "Name of the VPC network to create"
  default     = "research-vpc"
}

variable "vpc_mtu" {
  type        = number
  description = "Maximum Transmission Unit (MTU) for the VPC network. 8896 recommended for Parallelstore and Lustre for 10% performance gain."
  default     = 8896
}

# Network peering is required for Storage Filesystems

variable "storage_ip_range" {
  type        = string
  description = "IP range for Storage peering, in CIDR notation"
  default     = "172.16.0.0/16"
}

variable "enable_private_endpoints" {
  type        = bool
  description = "Enable private endpoints for GKE clusters (restricts access to private networks)"
  default     = false
}

#-----------------------------------------------------
# GKE Standard Configuration
#-----------------------------------------------------

variable "clusters_per_region" {
  description = "Map of regions to number of clusters to create in each (maximum 4 per region)"
  type        = map(number)
  default     = { "us-central1" = 1 }

  validation {
    condition     = alltrue([for count in values(var.clusters_per_region) : count <= 4])
    error_message = "Maximum 4 clusters per region allowed"
  }
}

variable "gke_standard_cluster_name" {
  type        = string
  description = "Base name for GKE clusters (will be suffixed with region and index)"
  default     = "gke-risk-research"
}

variable "scaled_control_plane" {
  type        = bool
  description = "Deploy a larger initial nodepool to ensure larger control plane nodes are provisioned"
  default     = false
}

variable "cluster_max_cpus" {
  type        = number
  default     = 10000
  description = "Maximum CPU cores in cluster autoscaling resource limits"
}

variable "cluster_max_memory" {
  type        = number
  default     = 80000
  description = "Maximum memory (in GB) in cluster autoscaling resource limits"
}

variable "create_ondemand_nodepool" {
  description = "Whether to create the on-demand node pool"
  type        = bool
  default     = true
}

variable "create_spot_nodepool" {
  description = "Whether to create the spot node pool"
  type        = bool
  default     = true
}

variable "node_machine_type_ondemand" {
  type        = string
  description = "Machine type for on-demand node pools in GKE clusters"
  default     = "n2-standard-16"
}

variable "node_machine_type_spot" {
  type        = string
  description = "Machine type for spot node pools in GKE clusters"
  default     = "n2-standard-64"
}

variable "min_nodes_ondemand" {
  type        = number
  description = "Minimum number of on-demand nodes in the node pool"
  default     = 0
}

variable "max_nodes_ondemand" {
  type        = number
  description = "Maximum number of on-demand nodes in the node pool"
  default     = 32
}

variable "min_nodes_spot" {
  type        = number
  description = "Minimum number of spot nodes in the node pool"
  default     = 1
}

variable "max_nodes_spot" {
  type        = number
  description = "Maximum number of spot nodes in the node pool"
  default     = 3000
}

variable "release_channel" {
  type        = string
  description = "GKE release channel for clusters (RAPID, REGULAR, STABLE)"
  default     = "RAPID"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be one of: RAPID, REGULAR, STABLE"
  }
}

variable "datapath_provider" {
  description = "The datapath provider for the GKE cluster (DATAPATH_PROVIDER_UNSPECIFIED, LEGACY_DATAPATH, or ADVANCED_DATAPATH)"
  type        = string
  default     = "LEGACY_DATAPATH"

  validation {
    condition     = contains(["DATAPATH_PROVIDER_UNSPECIFIED", "LEGACY_DATAPATH", "ADVANCED_DATAPATH"], var.datapath_provider)
    error_message = "datapath_provider must be one of: DATAPATH_PROVIDER_UNSPECIFIED, LEGACY_DATAPATH, ADVANCED_DATAPATH"
  }
}

variable "maintenance_start_time" {
  description = "The start time for the maintenance window in RFC3339 format (e.g., '2024-09-17T04:00:00Z')"
  type        = string
  default     = "2024-09-17T04:00:00Z"
}

variable "maintenance_end_time" {
  description = "The end time for the maintenance window in RFC3339 format (e.g., '2024-09-18T04:00:00Z')"
  type        = string
  default     = "2024-09-18T04:00:00Z"
}

variable "maintenance_recurrence" {
  description = "The recurrence of the maintenance window in RRULE format (e.g., 'FREQ=WEEKLY;BYDAY=SA,SU')"
  type        = string
  default     = "FREQ=WEEKLY;BYDAY=SA,SU"
}

variable "enable_mesh_certificates" {
  description = "Enable mesh certificates for the GKE cluster"
  type        = bool
  default     = false
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

#-----------------------------------------------------
# Storage Configuration
#-----------------------------------------------------

variable "storage_type" {
  type        = string
  description = "The type of storage system to deploy. Set to PARALLELSTORE or LUSTRE to enable storage creation. If null (default), no storage system will be deployed by these module blocks."
  default     = null
  nullable    = true

  validation {
    # Allow null OR one of the specified types
    condition     = var.storage_type == null ? true : contains(["PARALLELSTORE", "LUSTRE"], var.storage_type)
    error_message = "The storage_type must be null, PARALLELSTORE, or LUSTRE."
  }
}

variable "storage_locations" {
  description = "Map of region to location (zone) for storage instances e.g. {\"us-central1\" = \"us-central1-a\"}. If not specified, the first zone in each region will be used."
  type        = map(string)
  default     = {}
}

variable "storage_capacity_gib" {
  type        = number
  description = "Capacity in GiB for the selected storage system (Parallelstore or Lustre)."
  default     = null
  nullable    = true
  validation {
    condition = var.storage_capacity_gib == null ? true : (
      (var.storage_type != "LUSTRE" || (
        var.storage_capacity_gib >= 18000 &&
        var.storage_capacity_gib <= 936000 &&
        var.storage_capacity_gib % 9000 == 0
      )) &&
      (var.storage_type != "PARALLELSTORE" || (
        var.storage_capacity_gib >= 12000 &&
        var.storage_capacity_gib <= 100000 &&
        var.storage_capacity_gib % 4000 == 0
      )) &&
      (var.storage_type == "LUSTRE" || var.storage_type == "PARALLELSTORE")
    )
    error_message = "Storage capacity must be a positive number."
  }
}

#-----------------------------------------------------
# Parallelstore Configuration
#-----------------------------------------------------

variable "parallelstore_deployment_type" {
  description = "Parallelstore Instance deployment type (SCRATCH or PERSISTENT)"
  type        = string
  default     = "SCRATCH"

  validation {
    condition     = contains(["SCRATCH", "PERSISTENT"], var.parallelstore_deployment_type)
    error_message = "deployment_type must be either SCRATCH or PERSISTENT"
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
# Artifact Registry Configuration
#-----------------------------------------------------

variable "artifact_registry_name" {
  description = "Name of the Artifact Registry repository to create"
  type        = string
  default     = "research-images"
}

variable "artifact_registry_cleanup_policy_keep_count" {
  description = "Number of most recent container image versions to keep in Artifact Registry"
  type        = number
  default     = 10
}

#-----------------------------------------------------
# Identity and Security Configuration
#-----------------------------------------------------

variable "cluster_service_account" {
  description = "Service Account ID to use for GKE clusters"
  type        = string
  default     = "gke-risk-research-cluster-sa"
}

variable "additional_service_account_roles" {
  description = "Additional IAM roles to assign to the cluster service account"
  type        = list(string)
  default     = []
}

variable "enable_shielded_nodes" {
  description = "Enable Shielded GKE Nodes for enhanced security"
  type        = bool
  default     = true
}

variable "enable_secure_boot" {
  description = "Enable Secure Boot for GKE nodes"
  type        = bool
  default     = true
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity for GKE clusters"
  type        = bool
  default     = true
}

#-----------------------------------------------------
# Monitoring Configuration
#-----------------------------------------------------

variable "enable_log_analytics" {
  description = "Enable log analytics with BigQuery linking"
  type        = bool
  default     = true
}
