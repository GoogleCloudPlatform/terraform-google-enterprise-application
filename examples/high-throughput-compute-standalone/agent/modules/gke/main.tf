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

data "google_project" "environment" {
  project_id = var.project_id
}

locals {
  enable_jobs = (var.gke_job_request != "" && var.gke_job_response != "") ? 1 : 0
  enable_hpa  = (var.gke_hpa_request != "" && var.gke_job_response != "") ? 1 : 0
  # Topics
  pubsub_topics = concat(
    local.enable_jobs == 1 ? [
      var.gke_job_request,
      var.gke_job_response,
    ] : [],
    local.enable_hpa == 1 ? [
      var.gke_hpa_request,
      var.gke_hpa_response,
    ] : [],
  )
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Global Resources

# Pubsub
resource "google_pubsub_topic" "topic" {
  for_each = toset(local.pubsub_topics)
  project  = var.project_id
  name     = each.value
  message_storage_policy {
    allowed_persistence_regions = var.regions
  }
}

resource "google_pubsub_subscription" "subscription" {
  for_each                     = toset(local.pubsub_topics)
  project                      = google_pubsub_topic.topic[each.value].project
  topic                        = google_pubsub_topic.topic[each.value].name
  name                         = "${each.value}_sub"
  enable_exactly_once_delivery = var.pubsub_exactly_once
  ack_deadline_seconds         = 60
  retry_policy {
    minimum_backoff = "30s"
    maximum_backoff = "600s"
  }
}

# Dashboard

resource "google_monitoring_dashboard" "risk-platform-overview" {
  project        = data.google_project.environment.project_id
  dashboard_json = file("${path.module}/${var.dashboard}")

  lifecycle {
    ignore_changes = [
      dashboard_json
    ]
  }
}
# Regional Resources

# GCS bucket per region
resource "google_storage_bucket" "gcs_storage_data" {
  for_each                    = toset(var.regions)
  project                     = var.project_id
  location                    = each.value
  name                        = "${var.project_id}-${each.value}-gke-data-${random_string.suffix.id}"
  uniform_bucket_level_access = true
  force_destroy               = true
  hierarchical_namespace {
    enabled = var.hsn_bucket
  }
}

# Create IAM role bindings for each GKE cluster

resource "google_project_iam_member" "storage_objectuser" {
  for_each = { for idx, cluster in var.gke_clusters : idx => cluster }
  project  = data.google_project.environment.project_id
  role     = "roles/storage.objectUser"
  member   = "principalSet://iam.googleapis.com/projects/${data.google_project.environment.number}/locations/global/workloadIdentityPools/${data.google_project.environment.project_id}.svc.id.goog/kubernetes.cluster/https://container.googleapis.com/v1/projects/${data.google_project.environment.project_id}/locations/${each.value.region}/clusters/${each.value.cluster_name}"
}

resource "google_project_iam_member" "pubsub_publisher" {
  for_each = { for idx, cluster in var.gke_clusters : idx => cluster }
  project  = data.google_project.environment.project_id
  role     = "roles/pubsub.publisher"
  member   = "principalSet://iam.googleapis.com/projects/${data.google_project.environment.number}/locations/global/workloadIdentityPools/${data.google_project.environment.project_id}.svc.id.goog/kubernetes.cluster/https://container.googleapis.com/v1/projects/${data.google_project.environment.project_id}/locations/${each.value.region}/clusters/${each.value.cluster_name}"
}

resource "google_project_iam_member" "pubsub_subscriber" {
  for_each = { for idx, cluster in var.gke_clusters : idx => cluster }
  project  = data.google_project.environment.project_id
  role     = "roles/pubsub.subscriber"
  member   = "principalSet://iam.googleapis.com/projects/${data.google_project.environment.number}/locations/global/workloadIdentityPools/${data.google_project.environment.project_id}.svc.id.goog/kubernetes.cluster/https://container.googleapis.com/v1/projects/${data.google_project.environment.project_id}/locations/${each.value.region}/clusters/${each.value.cluster_name}"
}

resource "google_project_iam_member" "pubsub_viewer" {
  for_each = { for idx, cluster in var.gke_clusters : idx => cluster }
  project  = data.google_project.environment.project_id
  role     = "roles/pubsub.viewer"
  member   = "principalSet://iam.googleapis.com/projects/${data.google_project.environment.number}/locations/global/workloadIdentityPools/${data.google_project.environment.project_id}.svc.id.goog/kubernetes.cluster/https://container.googleapis.com/v1/projects/${data.google_project.environment.project_id}/locations/${each.value.region}/clusters/${each.value.cluster_name}"
}

# Apply Resource to each GKE cluster
module "config_apply" {
  for_each     = { for idx, cluster in var.gke_clusters : idx => cluster }
  source       = "../config_apply"
  project_id   = data.google_project.environment.project_id
  region       = each.value.region
  cluster_name = each.value.cluster_name
  agent_image  = var.agent_image
  # Workload options
  workload_image         = var.workload_image
  workload_args          = var.workload_args
  workload_grpc_endpoint = var.workload_grpc_endpoint
  workload_init_args     = var.workload_init_args
  test_configs           = var.test_configs
  gcs_bucket             = google_storage_bucket.gcs_storage_data[each.value.region].id
  # set this to empty string if not enabled
  pubsub_hpa_request = local.enable_hpa == 1 ? google_pubsub_subscription.subscription[var.gke_hpa_request].name : ""
  pubsub_job_request = local.enable_jobs == 1 ? google_pubsub_subscription.subscription[var.gke_job_request].name : ""

  # Parallelstore Config
  parallelstore_enabled       = var.parallelstore_enabled
  parallelstore_access_points = var.parallelstore_enabled ? join(",", var.parallelstore_instances[each.value.region].access_points) : null
  parallelstore_vpc_name      = var.parallelstore_enabled ? var.vpc_name : null
  parallelstore_location      = var.parallelstore_enabled ? var.parallelstore_instances[each.value.region].location : null
  parallelstore_instance_name = var.parallelstore_enabled ? var.parallelstore_instances[each.value.region].name : null
  parallelstore_capacity_gib  = var.parallelstore_enabled ? var.parallelstore_instances[each.value.region].capacity_gib : null

  depends_on = [
    google_project_iam_member.storage_objectuser,
    google_project_iam_member.pubsub_publisher,
    google_project_iam_member.pubsub_subscriber
  ]
}
