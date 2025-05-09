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


#
# Mandatory configuration
#

# Project ID where resources will be deployed
variable "project_id" {
  type        = string
  description = "The GCP project ID where resources will be created."
}

variable "regions" {
  description = "List of regions where GKE clusters should be created"
  type        = list(string)
  default     = ["us-central1"]
}

variable "gke_clusters" {
  description = "List of GKE cluster configurations containing cluster name and region"
  type = list(object({
    cluster_name = string
    region       = string
  }))
}

# Enable hierarchical namespace GCS buckets
variable "hsn_bucket" {
  description = "Enable hierarchical namespace GCS buckets"
  type        = bool
  default     = false
}

# Containers to build
variable "agent_image" {
  type        = string
  description = "Agent image for Cloud Run templates"
}

# Containers to build
variable "workload_image" {
  type        = string
  description = "Map of image name to configuration (source)"
}

# Sidecar configuration
variable "workload_grpc_endpoint" {
  type        = string
  description = ""
}

variable "workload_args" {
  type = list(string)
}

variable "dashboard" {
  type    = string
  default = "dashboards/risk-platform-overview.json"
}

#
# Optional functionality
# (Review suggested)
#

# Configurations to create shell scripts for
variable "test_configs" {
  type = map(object({
    parallel = number
    testfile = string
  }))
  default     = {}
  description = "Test configurations (parallel = 0 use autoscaler)"
}

variable "workload_init_args" {
  type        = list(list(string))
  default     = []
  description = "Workload initialization arguments to run"
}

variable "pubsub_exactly_once" {
  type        = bool
  default     = true
  description = "Enable Pub/Sub exactly once subscriptions"
}


#
# Naming defaults
# (Only change if conflicting with other modules)
#

variable "gke_job_request" {
  type    = string
  default = "gke_job_request"
}
variable "gke_job_response" {
  type    = string
  default = "gke_job_response"
}
variable "gke_hpa_request" {
  type    = string
  default = "gke_hpa_request"
}
variable "gke_hpa_response" {
  type    = string
  default = "gke_hpa_response"
}

# Parallelstore
# Enable/disable Parallelstore deployment (default: false)
variable "parallelstore_enabled" {
  type        = bool
  description = "Enable or disable the deployment of Parallelstore."
  default     = false
}

variable "parallelstore_instances" {
  type = map(object({
    name          = string
    access_points = list(string)
    location      = string
    region        = string
    id            = string
    capacity_gib  = number
  }))
  default = null
  validation {
    condition = var.parallelstore_instances == null || alltrue([
      for instance in values(var.parallelstore_instances) :
      instance.access_points != null && instance.access_points != ""
    ])
    error_message = "All parallelstore instances must have non-null access_points"
  }
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC used by Parallelstore"
}
