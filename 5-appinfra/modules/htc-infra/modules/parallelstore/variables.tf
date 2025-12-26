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
    error_message = "'project_id' was not set, please set the value in the terraform.tfvars file"
  }
}

variable "location" {
  description = "The location (zone) where the Parallelstore instance will be created, in the format 'region-zone' e.g., 'us-central1-a'"
  type        = string
  default     = "null"
}

variable "instance_id" {
  description = "The ID of the Parallelstore instance. If null, will be set to 'parallelstore-{location}'."
  type        = string
  default     = null
}

variable "network" {
  description = "The VPC network to which the Parallelstore instance should be connected"
  type        = string
  default     = "default"
}

variable "deployment_type" {
  description = "Parallelstore Instance deployment type (SCRATCH or PERSISTENT)"
  type        = string
  default     = "SCRATCH"

  validation {
    condition     = contains(["SCRATCH", "PERSISTENT"], var.deployment_type)
    error_message = "The deployment_type must be either SCRATCH or PERSISTENT"
  }
}

variable "capacity_gib" {
  description = "Custom capacity in GiB for Parallelstore instance. If null, defaults to 12000 for SCRATCH and 27000 for PERSISTENT."
  type        = number
  default     = null
}
