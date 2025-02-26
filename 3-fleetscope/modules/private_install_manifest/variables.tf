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

variable "url" {
  description = "URL for manifests"
  type        = string
}

variable "project_id" {
  description = "Project ID for Artifact Registry Remote Repository deployment"
  type        = string
}

variable "region" {
  description = "Region for Artifact Registry Remote Repository deployment"
  type        = string
}

variable "k8s_registry" {
  description = "Kubernetes registry domain"
  type        = string
  default     = "registry.k8s.io"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "cluster_region" {
  description = "Region of the Kubernetes cluster"
  type        = string
}

variable "cluster_project" {
  description = "Project ID for the Kubernetes cluster"
  type        = string
}

variable "cluster_service_accounts" {
  description = "Cluster nodes services accounts."
  type        = list(string)
}
