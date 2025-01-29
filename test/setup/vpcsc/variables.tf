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

variable "org_id" {
  description = "The numeric organization id"
  type        = string
}

variable "project_id" {
  description = "The project_id"
  type        = string
}

variable "project_number" {
  description = "The project_id"
  type        = string
}

variable "gitlab_project_number" {
  description = "The Gitlab project_id"
  type        = string
}

variable "service_perimeter_mode" {
  description = "Service perimeter mode: ENFORCE, DRY_RUN."
  type        = string
  default     = "DRY_RUN"

  validation {
    condition     = contains(["ENFORCE", "DRY_RUN"], var.service_perimeter_mode)
    error_message = "The service_perimeter_mode value must be one of: ENFORCE, DRY_RUN."
  }
}

variable "access_level_members" {
  description = "Extra access level members. serviceAccount:EMAIL@DOMAIN or user:EMAIL@DOMAIN"
  type        = list(string)
  default     = []
}
