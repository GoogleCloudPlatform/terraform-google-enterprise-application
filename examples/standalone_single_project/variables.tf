/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "project_id" {
  type        = string
  description = "Google Cloud project ID in which to deploy all example resources"
}

variable "network_id" {
  type        = string
  description = "Network id"
}

variable "subnetwork_self_link" {
  type        = string
  description = "Sub-Network self-link"
}

variable "region" {
  type        = string
  description = "Google Cloud region for deployments"
  default     = "us-central1"
}

variable "teams" {
  type        = map(string)
  description = "A map of string at the format {\"namespace\" = \"groupEmail\"}"
}

variable "service_perimeter_name" {
  description = "Service perimeter full name."
  type        = string
  default     = null
}

variable "service_perimeter_mode" {
  description = "Service perimeter mode: ENFORCE, DRY_RUN."
  type        = string
  default     = "ENFORCE"

  validation {
    condition     = contains(["ENFORCE", "DRY_RUN"], var.service_perimeter_mode)
    error_message = "The service_perimeter_mode value must be one of: ENFORCE, DRY_RUN."
  }
}
