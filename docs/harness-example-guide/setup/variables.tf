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

variable "org_id" {
  description = "The numeric organization id"
  type        = string
}

variable "folder_id" {
  description = "The folder to deploy in"
  type        = string
}

variable "billing_account" {
  description = "The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ"
  type        = string
}

variable "cloud_build_sa" {
  description = "Cloud Build Service Account email to be granted Encrypt/Decrypt role."
  type        = string
}

variable "region" {
  description = "Region where KMS and Logging bucket will be deployed."
  type        = string
}

variable "workpool_region" {
  description = "The region to deploy in."
  type        = string
}

variable "workerpool_machine_type" {
  description = "The workerpool machine type."
  type        = string
}

variable "workerpool_peering_address" {
  description = "The IP address for the Cloud Build private worker pool peering range (e.g., 10.3.3.0). Change this if it conflicts with your corporate network."
  type        = string
}

variable "workerpool_nat_subnet_ip" {
  description = "The IP CIDR range for the worker pool NAT proxy subnet (e.g., 10.1.1.0/24). Change this if it conflicts with your corporate network."
  type        = string
}

variable "enabled_environments" {
  description = "A map of environments to deploy. Set the value to 'true' for each environment you want to create."
  type        = map(bool)
}

variable "network_regions_to_deploy" {
  description = "List of regions where the network resources should be deployed."
  type = list(string)
  validation {
    condition     = alltrue([for r in var.network_regions_to_deploy : contains(["us-central1", "us-east4"], r)])
    error_message = "For this harness guide, only 'us-central1' and 'us-east4' are supported."
  }
}
