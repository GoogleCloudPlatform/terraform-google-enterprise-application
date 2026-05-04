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

output "analytics_bigquery_dataset_id" {
  description = "ID of the BigQuery dataset linked to Cloud Logging for log analytics, returned only when log analytics is enabled, used for querying logs and creating dashboards"
  value       = var.enable_log_analytics ? google_logging_linked_dataset.all_logging_linked_dataset[0].bigquery_dataset[0].dataset_id : null
}
