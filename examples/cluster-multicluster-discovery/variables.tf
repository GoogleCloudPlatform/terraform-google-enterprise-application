/**
 * Copyright 2026 Google LLC
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

variable "regions" {
  type        = list(string)
  description = "Google Cloud regions for cluster"
}

variable "base_cidr" {
  type        = string
  description = "Base CIDR for the VPC primary ranges"
  default     = "10.1.0.0/16"
}

variable "pods_base_cidr" {
  type        = string
  description = "Base CIDR for Kubernetes Pods secondary ranges"
  default     = "10.2.0.0/16"
}

variable "services_base_cidr" {
  type        = string
  description = "Base CIDR for Kubernetes Services secondary ranges"
  default     = "10.3.0.0/16"
}

variable "teams" {
  type        = map(string)
  description = "A map of string at the format {\"namespace\" = \"groupEmail\"}"
}

variable "service_perimeter_name" {
  description = "(VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter."
  type        = string
  default     = null
}

variable "service_perimeter_mode" {
  description = "(VPC-SC) Service perimeter mode: ENFORCE, DRY_RUN."
  type        = string
  default     = "ENFORCE"

  validation {
    condition     = contains(["ENFORCE", "DRY_RUN"], var.service_perimeter_mode)
    error_message = "The service_perimeter_mode value must be one of: ENFORCE, DRY_RUN."
  }
}

variable "access_level_name" {
  description = "(VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter."
  type        = string
  default     = null
}

variable "attestation_kms_key" {
  type        = string
  description = "The KMS Key ID to be used by attestor."
}
