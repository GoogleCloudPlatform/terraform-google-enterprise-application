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
  description = "CI/CD project ID"
  type        = string
}

variable "region" {
  description = "CI/CD region"
  type        = string
}

variable "cluster_membership_id_dev" {
  description = "Cluster fleet membership ID in development environment"
  type        = string
}

variable "cluster_membership_ids_nonprod" {
  description = "Cluster fleet membership IDs in nonprod environment"
  type        = list(string)
}

variable "cluster_membership_ids_prod" {
  description = "Cluster fleet membership IDs in prod environment"
  type        = list(string)
}

variable "buckets_force_destroy" {
  description = "When deleting the bucket for storing CICD artifacts, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects."
  type        = bool
  default     = false
}
