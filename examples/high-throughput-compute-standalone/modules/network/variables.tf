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

# Calculate network ranges based on region index

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

# Region for resource deployment (default: us-central1)
variable "regions" {
  description = "List of regions where GKE clusters should be created"
  type        = list(string)
  default     = ["us-central1"]
}

variable "vpc_id" {
  description = "ID of the shared VPC network"
  type        = string
}

variable "vpc_name" {
  description = "Name of the shared VPC network"
  type        = string
}
