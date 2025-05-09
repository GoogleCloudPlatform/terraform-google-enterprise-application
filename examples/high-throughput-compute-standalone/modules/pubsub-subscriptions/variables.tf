# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Project ID where resources will be deployed
variable "project_id" {
  type        = string
  description = "The GCP project ID where resources will be created."
}

# Region where the build and artifact repository is
variable "region" {
  type        = string
  description = "The Region of the Pub/Sub topic and subscriptions"
}

# Region where the build and artifact repository is
variable "bigquery_dataset" {
  type        = string
  description = "The Dataset for capturing BigQuery data"
}

# Region where the build and artifact repository is
variable "bigquery_table" {
  type        = string
  description = "The Datsaset for capturing BigQuery data"
}

# Containers to build
variable "topics" {
  type        = list(string)
  description = "List of topics to persist to BigQuery"
}

variable "subscriber_service_account" {
  description = "Service account that will be granted subscriber role on topics"
  type        = string
  default     = ""
}
