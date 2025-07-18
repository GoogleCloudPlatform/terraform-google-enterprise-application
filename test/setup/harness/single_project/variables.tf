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

variable "org_id" {
  description = "The numeric organization id"
  type        = string
}

variable "seed_project_id" {
  description = "The project where the example will be deployed."
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

variable "logging_bucket_name" {
  description = "The logging bucket name."
  type        = string
}

variable "workerpool_id" {
  description = "The workerpool id where builds are going to run."
  type        = string
}
