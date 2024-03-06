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
  description = "Project ID for initial resources"
  type        = string
}

variable "bucket_prefix" {
  description = "Name prefix to use for state bucket created."
  type        = string
  default     = "bkt"
}

variable "location" {
  description = "Location for build logs/state bucket"
  type        = string
  default     = "us-central1"
}

variable "trigger_location" {
  description = "Location of for Cloud Build triggers created in the workspace. If using private pools should be the same location as the pool."
  type        = string
  default     = "global"
}

variable "storage_bucket_labels" {
  description = "Labels to apply to the storage bucket."
  type        = map(string)
  default     = {}
}
