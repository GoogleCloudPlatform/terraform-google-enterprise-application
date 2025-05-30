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

# Topics (for BigQuery capturing of output)
output "topics" {
  description = "Image and tag names for build containers"
  value       = local.pubsub_topics
  depends_on = [
    google_pubsub_topic.topic,
    google_pubsub_subscription.subscription
  ]
}

# Dashboard for Platform Overview
output "monitoring_dashboard_url" {
  description = "Cloud Monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards/builder/${regex("projects/[0-9]+/dashboards/(.*)$", google_monitoring_dashboard.risk-platform-overview.id)[0]};project=${var.project_id}"
}

# Test scripts (shell scripts)
output "test_scripts_list" {
  description = "Test configuration shell scripts as a list"
  value = flatten([
    for cluster_module in module.config_apply : [
      for script_id, script in cluster_module.test_scripts : script
    ]
  ])
}

output "first_test_script" {
  description = "First test script"
  value       = module.config_apply[0].test_scripts
}

# Cluster
output "cluster_urls" {
  description = "Cluster urls"
  value = {
    for idx, cluster in var.gke_clusters :
    cluster.cluster_name => "https://console.cloud.google.com/kubernetes/workload/overview?project=${var.project_id}&pageState=(%22savedViews%22:(%22n%22:%5B%22default%22%5D,%22c%22:%5B%22gke%2F${cluster.region}%2F${cluster.cluster_name}%22%5D))"
  }
}

output "get_credentials" {
  description = "Commands for getting credentials for each GKE cluster"
  value = {
    for idx, cluster in var.gke_clusters :
    cluster.cluster_name => "gcloud container clusters get-credentials ${cluster.cluster_name} --project ${var.project_id} --location ${cluster.region}"
  }
}
