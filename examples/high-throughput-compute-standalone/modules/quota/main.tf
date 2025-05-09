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

locals {
  # Process quota preferences to handle region-specific quotas
  quota_preferences = [
    for pref in var.quota_preferences : {
      service         = pref.service
      quota_id        = pref.quota_id
      preferred_value = pref.preferred_value
      # Merge region into dimensions if present and not already in dimensions
      dimensions = pref.region != null ? merge(pref.dimensions, { region = pref.region }) : pref.dimensions
      # Generate name if custom_name is not provided
      name = pref.custom_name != null ? pref.custom_name : "${replace(pref.service, ".", "_")}-${pref.quota_id}${pref.region != null ? "_${pref.region}" : ""}"
    }
  ]
}

data "google_project" "environment" {
  project_id = var.project_id
}

resource "google_cloud_quotas_quota_preference" "quota_preferences" {
  for_each = { for idx, pref in local.quota_preferences : idx => pref if var.quota_contact_email != "" }

  parent        = "projects/${var.project_id}"
  name          = each.value.name
  dimensions    = each.value.dimensions
  service       = each.value.service
  quota_id      = each.value.quota_id
  contact_email = var.quota_contact_email

  quota_config {
    preferred_value = each.value.preferred_value
  }

  lifecycle {
    ignore_changes = all
  }
}
