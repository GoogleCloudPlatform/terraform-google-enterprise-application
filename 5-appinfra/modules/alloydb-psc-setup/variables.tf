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

variable "env" {
  description = "The environment to prepare (ex. development)"
  type        = string
}

variable "cluster_regions" {
  description = "Cluster regions"
  type        = list(string)
}

variable "app_project_id" {
  description = "App Project ID"
  type        = string
}

variable "network_project_id" {
  description = "The ID of the project in which PSC attachment will be provisioned"
  type        = string
}

variable "network_name" {
  description = "The name of the network in which PSC attachment will be provisioned"
  type        = string
}

variable "psc_consumer_fwd_rule_ip" {
  description = "Consumer psc endpoint IP address"
  type        = string
}

variable "workload_identity_principal" {
  description = "Workload Identity Principal to assign Cloud AlloyDB Admin (roles/alloydb.admin) role. Format: https://cloud.google.com/billing/docs/reference/rest/v1/Policy#Binding"
  type        = string
}
