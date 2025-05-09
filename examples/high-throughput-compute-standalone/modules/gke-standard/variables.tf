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

variable "project_id" {
  description = "The GCP project where the resources will be created"
  type        = string

  validation {
    condition     = var.project_id != "YOUR_PROJECT_ID"
    error_message = "'project_id' was not set, please set the value in the fsi-resaerch-1.tfvars file"
  }
}

variable "region" {
  description = "The region to host the cluster in"
  type        = string
  default     = "us-central1"
}

variable "zones" {
  description = "The zones for cluster nodes"
  type        = list(string)
}

variable "network" {
  description = "The vpc the cluster should be deployed to"
  type        = string
  default     = "default"
}

variable "subnet" {
  description = "The subnet the cluster should be deployed to"
  type        = string
  default     = "default"
}

variable "ip_range_pods" {
  type        = string
  description = "The _name_ of the secondary subnet ip range to use for pods"
}

variable "ip_range_services" {
  type        = string
  description = "The _name_ of the secondary subnet range to use for services"
}

variable "scaled_control_plane" {
  type        = bool
  description = "Deploy a larger initial nodepool to ensure larger control plane nodes are provisied"
  default     = false
}

variable "cluster_name" {
  type        = string
  description = "Name of GKE cluster"
  default     = "gke-risk-research"
}

variable "cluster_service_account" {
  description = "The service account for the GKE cluster"
  type = object({
    email = string
    id    = string
  })
}

variable "artifact_registry" {
  type = object({
    project  = string
    location = string
    name     = string
  })
}

variable "cluster_max_cpus" {
  type        = number
  default     = 10000
  description = "Max CPU in cluster autoscaling resource limits"
}

variable "cluster_max_memory" {
  type        = number
  default     = 80000
  description = "Max memory in cluster autoscaling resource limits"
}

variable "cluster_index" {
  description = "Index of this cluster within its region (0-3)"
  type        = number

  validation {
    condition     = var.cluster_index >= 0 && var.cluster_index < 4
    error_message = "cluster_index must be between 0 and 3"
  }
}

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

variable "min_master_version" {
  description = "The minimum version of the master. GKE will auto-update the master to new versions, so this does not guarantee the current master version."
  type        = string
  default     = "1.32.3"
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

variable "enable_private_endpoint" {
  description = "Enable private endpoint for GKE control plane (restricts access to private networks)"
  type        = bool
  default     = false
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

variable "datapath_provider" {
  description = "The datapath provider for the GKE cluster (DATAPATH_PROVIDER_UNSPECIFIED, LEGACY_DATAPATH, or ADVANCED_DATAPATH)"
  type        = string
  default     = "LEGACY_DATAPATH"

  validation {
    condition     = contains(["DATAPATH_PROVIDER_UNSPECIFIED", "LEGACY_DATAPATH", "ADVANCED_DATAPATH"], var.datapath_provider)
    error_message = "datapath_provider must be one of: DATAPATH_PROVIDER_UNSPECIFIED, LEGACY_DATAPATH, ADVANCED_DATAPATH"
  }
}

variable "enable_advanced_datapath_observability_metrics" {
  description = "Enable advanced datapath observability metrics when datapath_provider is ADVANCED_DATAPATH"
  type        = bool
  default     = true
}

variable "enable_advanced_datapath_observability_relay" {
  description = "Enable advanced datapath observability relay when datapath_provider is ADVANCED_DATAPATH"
  type        = bool
  default     = false
}

variable "enable_intranode_visibility" {
  description = "Enable intranode visibility for the GKE cluster"
  type        = bool
  default     = false
}

variable "enable_cilium_clusterwide_network_policy" {
  description = "Enable Cilium clusterwide network policy for the GKE cluster"
  type        = bool
  default     = false
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
