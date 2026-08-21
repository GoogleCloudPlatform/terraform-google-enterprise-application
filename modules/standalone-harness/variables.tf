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
  description = "Google Cloud project ID in which to deploy all harness resources."
}

variable "region" {
  type        = string
  description = "Google Cloud region for deployments."
  default     = "us-central1"
}

variable "workerpool_id" {
  type        = string
  description = "Specifies the Cloud Build Worker Pool that will be utilized for triggers."
  default     = null
}

variable "network_id" {
  type        = string
  description = "The network ID where the private worker pool is going to be peered."
  default     = null
}

variable "create_nat" {
  type        = bool
  description = "Enables Cloud NAT creation for Private Worker Pool."
  default     = true
}

variable "enables_network_connection_and_peering_routes" {
  type        = bool
  description = "Enables Network connection and peering routes."
  default     = true
}

variable "logging_bucket" {
  type        = string
  description = "Bucket to store logging."
  default     = null
}

variable "additional_services" {
  type        = list(string)
  description = "Additional GCP services to enable in the project."
  default     = []
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC to create."
  default     = "eab-cluster"
}

variable "subnet_ip" {
  type        = string
  description = "Primary subnet CIDR block."
  default     = "10.1.20.0/24"
}

variable "secondary_ip_cidr_range_01" {
  type        = string
  description = "Secondary CIDR range 1 for pods/services."
  default     = "192.168.0.0/18"
}

variable "secondary_ip_cidr_range_02" {
  type        = string
  description = "Secondary CIDR range 2 for pods/services."
  default     = "192.168.64.0/18"
}

variable "enable_proxy_subnet" {
  type        = bool
  description = "Enables proxy subnet"
  default     = false
}

variable "private_service_connect_ip" {
  description = "Private service IP"
  type        = string
  default     = "10.3.0.5"
}

variable "private_workerpool_name" {
  description = "The private workerpool name"
  type        = string
}

variable "attestation_repository_name" {
  description = "The Artifact repository name to store the BinAuthz image."
  type        = string
}

variable "build_image_module_dependencies" {
  description = "A list of dependencies to wait for before running the gcloud script"
  type        = list(any)
  default     = []
}

variable "worker_range_ip" {
  description = "The global IP do be reserved for peering "
  type        = string
  default     = "10.3.3.0"
}
