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
  description = "The location (zone) where the Lustre instance will be created, in the format 'region-zone' e.g., 'us-central1-a'"
  type        = string
  default     = "null"
}

variable "instance_id" {
  description = "The ID of the Lustre instance. If null, will be set to 'lustre-{location}'."
  type        = string
  default     = null
}

variable "filesystem" {
  description = "The name of the Lustre filesystem"
  type        = string
  default     = "lustre-fs"
}

variable "network" {
  description = "The VPC network to which the Lustre instance should be connected"
  type        = string
  default     = "default"
}

variable "capacity_gib" {
  description = "Capacity in GiB for Lustre instance. Must be a multiple of 9000."
  type        = number
  default     = 18000

  validation {
    condition     = var.capacity_gib >= 18000 && var.capacity_gib <= 936000 && var.capacity_gib % 9000 == 0
    error_message = "Capacity must be a multiple of 9000 GiB between 18000 GiB and 936000 GiB"
  }
}

variable "gke_support_enabled" {
  description = "Enable GKE support for Lustre instance"
  type        = bool
  default     = true
}
