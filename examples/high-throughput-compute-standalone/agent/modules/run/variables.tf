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
  description = "The GCP project ID where Cloud Run resources will be created."
}

# Region where the build and artifact repository is
variable "region" {
  type        = string
  description = "The GCP Region where Cloud Run resources will be created."
}

# Containers to build
variable "agent_image" {
  type        = string
  description = "Agent image for Cloud Run templates"
}

# Containers to build
variable "workload_image" {
  type        = string
  description = "Workload image for Cloud Run templates"
}

# Containers to build
variable "workload_args" {
  type        = list(string)
  description = "Workload image for Cloud Run templates"
}

# Sidecar configuration
variable "workload_grpc_endpoint" {
  type        = string
  description = "Endpoint for Workload that the agent will use"
}


#
# Optional functionality
#

# Workload jobs to run to initialize data and test cases
variable "workload_init_args" {
  type        = list(list(string))
  default     = []
  description = "Workload initialization arguments to run"
}

# Configurations to create shell scripts for
variable "test_configs" {
  type = map(object({
    parallel = number
    testfile = string
  }))
  default     = {}
  description = "Test configurations (parallel = 0 use autoscaler)"
}

# Enable Pub/Sub exactly once subscriptions
variable "pubsub_exactly_once" {
  type        = bool
  default     = true
  description = "Enable Pub/Sub exactly once subscriptions"
}


#
# Naming defaults
#

# BigQuery and Pub/Sub naming
variable "bq_dataset" {
  type    = string
  default = "workload"
}
variable "bq_routine" {
  type    = string
  default = "workload"
}
variable "run_job_request" {
  type    = string
  default = "run_job_request"
}
variable "run_job_response" {
  type    = string
  default = "run_job_response"
}
variable "run_hpa_request" {
  type    = string
  default = "run_hpa_request"
}
variable "run_hpa_response" {
  type    = string
  default = "run_hpa_response"
}
