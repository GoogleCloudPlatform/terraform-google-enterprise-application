# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  cache_filename      = "cache"
  full_service        = var.team_name == var.service_name ? var.service_name : "${var.team_name}-${var.service_name}"
  service_clean       = replace(local.full_service, "/", "-")
  container_registry  = google_artifact_registry_repository.container_registry
  private_worker_pool = var.private_worker_pool.private_worker_pool_id == null ? google_cloudbuild_worker_pool.pool[0].id : var.private_worker_pool.private_worker_pool_id
}
