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
  cache_filename     = "cache"
  service_name       = reverse(split("/", var.service))[0]
  team_name          = split("/", var.service)[0]
  service_clean      = replace(var.service, "/", "-")
  targets            = [google_clouddeploy_target.development, google_clouddeploy_target.non_prod[0], google_clouddeploy_target.non_prod[1], google_clouddeploy_target.prod[0], google_clouddeploy_target.prod[1]]
  container_registry = google_artifact_registry_repository.container_registry
}
