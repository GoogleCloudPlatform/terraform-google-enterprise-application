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

# Project ID where resources will be deployed
variable "project_id" {
  type        = string
  description = "The GCP project ID where resources will be created."
}

# Region where the build and artifact repository is
variable "region" {
  type        = string
  description = "The region of the build"
}

variable "repository_region" {
  type        = string
  description = "Artifacte Repository region"

}

# Repository ID
variable "repository_id" {
  type        = string
  description = "Artifact repository ID"
}

# Containers to build
variable "containers" {
  type = map(object({
    source      = string
    config_yaml = optional(string, "")
  }))
  description = "Map of image name to configuration (source)"
}

# Service account name to create
variable "service_account_name" {
  type        = string
  description = "Service account name"
  default     = "cloudbuild-actor"
}
