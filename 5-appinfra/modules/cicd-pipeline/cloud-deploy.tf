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

# create delivery pipeline for service including all targets
resource "google_clouddeploy_delivery_pipeline" "delivery-pipeline" {
  project  = var.project_id
  location = var.region
  name     = local.service_name
  serial_pipeline {
    dynamic "stages" {
      for_each = { for idx, target in local.targets : idx => target }
      content {
        # TODO: use "production" profile once it works.
        profiles  = [stages.value.name == "${local.service_name}-dev" ? "development" : (startswith(stages.value.name, "${local.service_name}-nonprod") ? "staging" : "production")]
        target_id = stages.value.name
      }
    }
  }
}
