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

variable "org_id" {
  description = "The numeric organization id"
  type        = string
}

variable "seed_project_id" {
  description = "The seed project."
  type        = string
}

variable "branch_name" {
  type        = string
  description = "The branch starting the build."
}

variable "seed_folder_id" {
  description = "The folder to deploy in"
  type        = string
}

variable "billing_account" {
  description = "The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ"
  type        = string
}

variable "sa_email" {
  description = "The ci service account email created by setup to run the tests."
  type        = string
}

variable "sa_id" {
  description = "The ci service account id created by setup to run the tests."
  type        = string
}

variable "hpc" {
  description = "If HPC example will be deployed."
  type        = bool
}

variable "agent" {
  description = "If AGENT example will be deployed."
  type        = bool
}
