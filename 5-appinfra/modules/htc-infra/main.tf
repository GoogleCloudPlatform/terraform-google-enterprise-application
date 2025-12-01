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
  namespace = "${var.team}-${var.env}"
  storage_locations_map = length(var.storage_locations) > 0 ? var.storage_locations : {
    for region in var.regions : region => region
  }
  workload_args          = ["serve", "--logJSON"]
  workload_grpc_endpoint = "http://localhost:2002/main.LoadTestService/RunLibrary"
  workload_init_args = [
    ["writedata", "--logJSON", "--showProgress=false", "--size", "1048576", "--parallel", "20", "--count", "5", "/data/read_dir/small-low"],
    ["gentasks", "--logJSON", "--count=1000", "--initMinMicros=1000000", "--minMicros=1000000", "--initReadDir=/data/read_dir/small", "/data/tasks/1k_1s_1s_read_small.jsonl.gz"],
  ]
  test_configs = [
    { name = "hpa_1k_1s_s_read_small", testfile = "/data/tasks/1k_1s_1s_read_small.jsonl.gz", parallel = 0, description = "Autoscaling workers, 1 second compute and small folder read on initialization, 1,000 tasks for 1 second task compute." },
  ]
  test_configs_dict = {
    for config in local.test_configs :
    config.name => config
  }

  ui_config_file = yamlencode({
    "project_id" : var.infra_project,
    "region" : var.region,
    "pubsub_summary_table" : "${google_bigquery_table.messages_summary.project}.${google_bigquery_table.messages_summary.dataset_id}.${google_bigquery_table.messages_summary.table_id}",
    "urls" : {
      "dashboard" = module.gke.monitoring_dashboard_url
      "cluster"   = module.gke.cluster_urls
    },
    "tasks" : concat(
      length(module.gke) == 0 ? [] : [
        for config in local.test_configs : {
          "name" = "GKE ${config.name}",
          # "script"      = module.gke.first_test_script[config.name],
          "script"      = module.gke.test_scripts_list[0],
          "parallel"    = config.parallel,
          "description" = config.description,
        }
      ],
    ),
  })
  parallelstore_instances = var.storage_type == "PARALLELSTORE" ? {
    for region, instance in module.parallelstore : region => {
      name          = instance.name_short
      instance_id   = instance.instance_id
      access_points = instance.access_points
      location      = instance.location
      region        = instance.region
      id            = instance.id
      capacity_gib  = instance.capacity_gib
      daos_version  = instance.daos_version
      kubernetes_usage = {
        persistent_volume_claim_template = "templates/parallelstore-pvc.yaml"
        csi_driver_enabled               = var.enable_csi_parallelstore
      }
    }
  } : {}
}

#-----------------------------------------------------
# Container Image Building
#-----------------------------------------------------

module "agent" {
  source = "./modules/builder"

  project_id        = var.admin_project
  region            = var.region
  repository_region = var.region
  repository_id     = var.service_name

  containers = {
    agent = {
      source = "${path.module}/agent/src"
    },
    loadtest = {
      source = "${path.module}/loadtest"
    },
    american_option = {
      source = "${path.module}/american-option"
    }
  }
}

#-----------------------------------------------------
# GKE Deployment
#-----------------------------------------------------

module "gke" {
  source             = "./agent/modules/gke"
  gke_cluster_names  = var.gke_cluster_names
  project_id         = var.infra_project
  cluster_project_id = var.cluster_project_id
  regions            = ["us-central1"]
  agent_image        = module.agent.status["agent"].image_url
  namespace          = local.namespace
  env                = var.env
  # GCS specific options
  hsn_bucket = var.hsn_bucket

  # Pub/Sub configuration
  pubsub_exactly_once = var.pubsub_exactly_once

  # Workload options
  # TODO: Other configuration for the workload - needs to be standardized
  workload_image         = module.agent.status["loadtest"].image_url
  workload_args          = local.workload_args
  workload_grpc_endpoint = local.workload_grpc_endpoint
  workload_init_args     = local.workload_init_args
  test_configs           = local.test_configs_dict

  parallelstore_enabled   = var.storage_type == "PARALLELSTORE"
  parallelstore_instances = local.parallelstore_instances
  vpc_name                = var.network_name

  depends_on = [
    module.agent
  ]
}

#-----------------------------------------------------
# Logging and Analytics Configuration
#-----------------------------------------------------

# Always have the same filter. Leave this at the top level. This will
# capture application *and* agent stuff.
# To be put into an *agent* module...
resource "google_logging_linked_dataset" "logging_linked_dataset" {
  link_id     = "applogs"
  bucket      = google_logging_project_bucket_config.analytics-enabled-bucket.id
  description = "Linked dataset test"
}

resource "google_logging_project_bucket_config" "analytics-enabled-bucket" {
  project          = var.infra_project
  location         = var.region
  enable_analytics = true
  bucket_id        = "applogs"
  lifecycle {
    ignore_changes = [project]
  }
}

resource "google_logging_project_sink" "my-sink" {
  project = var.infra_project
  name    = "my-pubsub-instance-sink"

  # Can export to pubsub, cloud storage, bigquery, log bucket, or another project
  destination = "logging.googleapis.com/${google_logging_project_bucket_config.analytics-enabled-bucket.id}"

  # This depends on the use of GKE and Cloud Run for the filter
  filter = "logName=\"projects/${var.infra_project}/logs/stdout\" OR logName=\"projects/${var.infra_project}/logs/stderr\" OR logName=\"projects/${var.infra_project}/logs/run.googleapis.com%2Fstdout\" OR logName=\"projects/${var.infra_project}/logs/run.googleapis.com%2Fstdout\""

  description = "Local application logs"
}

resource "google_bigquery_dataset" "main" {
  project                    = var.infra_project
  dataset_id                 = "workload"
  location                   = var.region
  delete_contents_on_destroy = true

  depends_on = [module.enabled_google_apis]
}

#
# Logging BigQuery views
#
resource "google_bigquery_table" "log_stats" {
  project             = var.infra_project
  dataset_id          = google_bigquery_dataset.main.dataset_id
  table_id            = "log_stats"
  deletion_protection = false

  view {
    query = templatefile(
      "${path.module}/sql/log_stats.sql", {
        project_id = var.infra_project
        dataset_id = regex("^bigquery.googleapis.com/projects/[^/]+/datasets/(.*)$", google_logging_linked_dataset.logging_linked_dataset.bigquery_dataset[0].dataset_id)[0]
    })
    use_legacy_sql = false
  }
}

# Collect agent statistics
resource "google_bigquery_table" "agent_stats" {
  project             = var.infra_project
  dataset_id          = google_bigquery_dataset.main.dataset_id
  table_id            = "agent_stats"
  deletion_protection = false

  view {
    query = templatefile(
      "${path.module}/sql/agent_stats.sql", {
        project_id = var.infra_project
        dataset_id = google_bigquery_dataset.main.dataset_id
        table_id   = google_bigquery_table.log_stats.table_id
    })
    use_legacy_sql = false
  }
}

# Summarise agent statistics by instance
resource "google_bigquery_table" "agent_summary_by_instance" {
  project             = var.infra_project
  dataset_id          = google_bigquery_dataset.main.dataset_id
  table_id            = "agent_summary_by_instance"
  deletion_protection = false

  view {
    query = templatefile(
      "${path.module}/sql/agent_summary_by_instance.sql", {
        project_id = var.infra_project
        dataset_id = google_bigquery_dataset.main.dataset_id
        table_id   = google_bigquery_table.agent_stats.table_id
    })
    use_legacy_sql = false
  }
}


#-----------------------------------------------------
# PubSub and BigQuery Integration
#-----------------------------------------------------
# All message are assumed to be JSON and captured in a JSON data element
module "bigquery_capture" {
  source     = "./modules/pubsub-subscriptions"
  project_id = var.infra_project
  # region                     = var.region
  bigquery_dataset           = google_bigquery_dataset.main.dataset_id
  bigquery_table             = "pubsub_messages"
  subscriber_service_account = google_service_account.bq_write_service_account.email
  topics = concat(
    length(module.gke) > 0 ? module.gke.topics : []
  )
}

resource "google_pubsub_topic_iam_member" "topic_subscriber" {
  for_each = toset(concat(
    length(module.gke) > 0 ? module.gke.topics : []
  ))

  project = var.infra_project
  topic   = each.value
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.bq_write_service_account.email}"
}

resource "google_service_account" "bq_write_service_account" {
  project      = var.infra_project
  account_id   = "pubsub-bigquery-writer"
  display_name = "BQ Write Service Account"
}

#-----------------------------------------------------
# Quota Requests
#-----------------------------------------------------

module "quota" {
  count  = var.additional_quota_enabled ? 1 : 0
  source = "./modules/quota"

  project_id          = var.infra_project
  quota_contact_email = var.quota_contact_email

  quota_preferences = [
    {
      service         = "compute.googleapis.com"
      quota_id        = "PREEMPTIBLE-CPUS-per-project-region"
      preferred_value = 10000
      region          = var.region
    },
    {
      service         = "compute.googleapis.com"
      quota_id        = "DISKS-TOTAL-GB-per-project-region"
      preferred_value = 65000
      region          = var.region
    },
    {
      service         = "monitoring.googleapis.com"
      quota_id        = "IngestionRequestsPerMinutePerProject"
      preferred_value = 100000
    }
  ]
}

#-----------------------------------------------------
# BigQuery Views for Visualization
#-----------------------------------------------------

# Pub/Sub messages joined by request/response
resource "google_bigquery_table" "messages_joined" {
  project             = var.infra_project
  dataset_id          = google_bigquery_dataset.main.dataset_id
  table_id            = "pubsub_messages_joined"
  deletion_protection = false

  view {
    query = templatefile(
      "${path.module}/sql/pubsub_messages_joined.sql", {
        project_id = var.infra_project
        dataset_id = google_bigquery_dataset.main.dataset_id
        table_id   = "pubsub_messages"
    })
    use_legacy_sql = false
  }

  depends_on = [
    module.bigquery_capture
  ]
}

# Pub/Sub summary by job
resource "google_bigquery_table" "messages_summary" {
  project             = var.infra_project
  dataset_id          = google_bigquery_dataset.main.dataset_id
  table_id            = "pubsub_messages_summary"
  deletion_protection = false

  view {
    query = templatefile(
      "${path.module}/sql/pubsub_messages_summary.sql", {
        project_id      = google_bigquery_table.messages_joined.project
        dataset_id      = google_bigquery_table.messages_joined.dataset_id
        joined_table_id = google_bigquery_table.messages_joined.table_id
    })
    use_legacy_sql = false
  }

  depends_on = [
    google_bigquery_table.messages_joined
  ]
}

# Create Parallel Store
module "parallelstore" {
  for_each        = var.storage_type == "PARALLELSTORE" ? local.storage_locations_map : {}
  source          = "./modules/parallelstore"
  project_id      = var.infra_project
  location        = var.region
  network         = var.network_self_link
  capacity_gib    = var.storage_capacity_gib
  deployment_type = var.parallelstore_deployment_type

  depends_on = [module.enabled_google_apis]
}
