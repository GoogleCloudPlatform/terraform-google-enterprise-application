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

variable "seed_folder_id" {
  description = "The folder to deploy in"
  type        = string
}

variable "seed_project_number" {
  description = "The seed project number"
  type        = string
}

variable "org_id" {
  description = "The numeric organization id"
  type        = string
}

variable "billing_account" {
  description = "The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ"
  type        = string
}

variable "network_name" {
  description = "Required. Immutable. The network definition that the workers are peered to. If this section is left empty, the workers will be peered to WorkerPool.project_id on the service producer network. Must be in the format projects/{project}/global/networks/{network}, where {project} is a project number, such as 12345, and {network} is the name of a VPC network in the project."
  type        = string
}

variable "workpool_region" {
  description = "The region to deploy in"
  type        = string
  default     = "us-central1"
}

variable "workerpool_machine_type" {
  description = "The project to deploy in"
  type        = string
  default     = "e2-standard-4"
}

