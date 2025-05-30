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

# Credentials for Kubernetes
output "get_credentials" {
  description = "Get Credentials command"
  value       = length(module.gke) > 0 ? module.gke.get_credentials : {}
}

# Dashboard for monitoring performance
output "monitoring_dashboard_url" {
  description = "Monitoring dashboard"
  value       = length(module.gke) > 0 ? module.gke.monitoring_dashboard_url : ""
}

# Dashboard for monitoring Pub/Sub and logs
output "lookerstudio_create_dashboard_url" {
  description = "Looker Studio template dashboard"
  value = join("", [
    "https://lookerstudio.google.com/reporting/create?",
    join("&", [
      "c.reportId=075df725-91f5-4424-a2e1-cd9bb5d139cc&c.reportName=LoadTest",
      "ds.msgs.projectId=${var.project_id}",
      "ds.msgs.billingProjectId=${var.project_id}",
      "ds.msgs.type=TABLE",
      "ds.msgs.datasetId=${google_bigquery_dataset.main.dataset_id}",
      "ds.msgs.tableId=${google_bigquery_table.messages_joined.table_id}",
      "ds.logs.projectId=${var.project_id}",
      "ds.logs.billingProjectId=${var.project_id}",
      "ds.logs.type=TABLE",
      "ds.logs.datasetId=${google_bigquery_dataset.main.dataset_id}",
      "ds.logs.tableId=${google_bigquery_table.agent_stats.table_id}",
    ])
  ])
}

# Test scripts
output "local_test_scripts" {
  description = "Test scripts for running loadtest"
  value = [
    for key, script in local.local_test_scripts : key
  ]
}

# UI image
output "ui_image" {
  description = "Image for the UI"
  value       = var.ui_image_enabled ? module.ui_image[0].status["ui"].image : ""
}

# output "debug_test_scripts" {
#   value = {
#     for config in local.test_configs : config.name => {
#       matching_scripts = [for script in module.gke.test_scripts_list : script if strcontains(script, config.name)]
#       script_count     = length([for script in module.gke.test_scripts_list : script if strcontains(script, config.name)])
#     }
#   }
# }

output "cluster_service_account" {
  description = "The service account used by GKE clusters"
  value = {
    email = module.infrastructure.cluster_service_account.email
    id    = module.infrastructure.cluster_service_account.id
    name  = module.infrastructure.cluster_service_account.name
  }
}
