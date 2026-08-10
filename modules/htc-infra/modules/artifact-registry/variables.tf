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

# Region for resource deployment (default: us-central1)
variable "regions" {
  description = "List of regions where GKE clusters will be deployed - used to determine the multi-region location"
  type        = list(string)
  default     = ["us-central1"]
}

variable "name" {
  description = "Name of the Artifact Registry"
  type        = string
  default     = "research-images"
}

variable "cleanup_keep_count" {
  description = "Number of most recent container image versions to keep in Artifact Registry cleanup policy"
  type        = number
  default     = 10
}
