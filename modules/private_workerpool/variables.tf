/**
 * Copyright 2025 Google LLC
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
  description = "Project id where the private workerpool and NAT will be created"
  type        = string
}

variable "network_id" {
  description = "The network ID where the private worker pool is going to be peered. If not provided, a new network is going to be created."
  type        = string
  default     = null

  validation {
    condition     = var.network_id != ""
    error_message = "network_id cannot be empty, only null or a valid value."
  }
}

variable "create_nat" {
  description = "Enables Cloud NAT creation for Private Worker Pool, disable if your network already has one created."
  type        = bool
  default     = true
}

variable "region" {
  description = "The region to deploy in"
  type        = string
  default     = "us-central1"
}

variable "workerpool_machine_type" {
  description = "The project to deploy in"
  type        = string
  default     = "e2-standard-4"
}
