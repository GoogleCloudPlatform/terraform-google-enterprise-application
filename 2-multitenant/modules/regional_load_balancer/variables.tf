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

variable "vpc_id" {
  description = "The VPC ID to be used."
  type        = string
}

variable "project_id" {
  description = "The project to where the regional Load Balancer will be created."
  type        = string
}

variable "network_project_id" {
  description = "The project to where the VPC is hosted."
  type        = string
}

variable "region" {
  description = "The region where the regional load balancer will be configured."
  type        = string
}
