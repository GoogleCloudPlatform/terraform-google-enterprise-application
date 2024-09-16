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
  name     = var.service_name
  serial_pipeline {
    dynamic "stages" {
      for_each = google_clouddeploy_target.clouddeploy_targets
      content {
        # TODO: use "production" profile once validated.
        profiles  = [endswith(stages.value.name, "-development") ? "development" : (endswith(stages.value.name, "-nonproduction") ? "staging" : "production")]
        target_id = stages.value.name
      }
    }
  }
}
