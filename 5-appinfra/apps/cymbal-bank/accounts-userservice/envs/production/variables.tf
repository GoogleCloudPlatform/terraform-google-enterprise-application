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

variable "cluster_regions" {
  description = "Cluster regions"
  type        = list(string)
}

variable "app_project_id" {
  description = "App Project ID"
  type        = string
}

variable "network_project_id" {
  description = "Network Project ID"
  type        = string
}

variable "network_name" {
  description = "Network name"
  type        = string
}

variable "psc_consumer_fwd_rule_ip" {
  description = "Consumer psc endpoint IP address"
  type        = string
}

variable "remote_state_bucket" {
  description = "Backend bucket to load Terraform Remote State Data from previous steps."
  type        = string
}
