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
    error_message = "'project_id' was not set, please set the value in your terraform.tfvars file"
  }
}

variable "region" {
  description = "The region to host the cluster in"
  type        = string
  default     = "us-central1"
}

variable "quota_contact_email" {
  description = "Contact email for quota requests"
  type        = string
  default     = ""
}

variable "quota_preferences" {
  description = "Map of quota preferences to request. Each item should include service, quota_id, preferred_value, and optional dimensions"
  type = list(object({
    service         = string
    quota_id        = string
    preferred_value = number
    dimensions      = optional(map(string), {})
    region          = optional(string, null)
    # Use custom_name if you want to override the default name format
    custom_name = optional(string, null)
  }))
  default = []

  validation {
    condition     = length([for q in var.quota_preferences : q if q.service == ""]) == 0
    error_message = "The 'service' field must be provided for each quota preference."
  }

  validation {
    condition     = length([for q in var.quota_preferences : q if q.quota_id == ""]) == 0
    error_message = "The 'quota_id' field must be provided for each quota preference."
  }
}
