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

  test_script_keys = flatten([
    for config in local.test_configs : [
      "run_${config.name}.sh",
      "gke_${config.name}.sh"
    ]
  ])

  local_test_scripts = {
    for key in local.test_script_keys : key => (
      startswith(key, "run_") ? (
        var.cloudrun_enabled && length(module.cloudrun) > 0 ?
        try(module.cloudrun[0].test_scripts[trimprefix(key, "run_")], null) : null
        ) : (
        length(module.gke) > 0 ?
        try(module.gke[module.default_region.default_region].test_scripts[trimprefix(key, "gke_")], null) : null
      )
    )
  }

  ui_config_file = yamlencode({
    "project_id" : var.project_id,
    "region" : module.default_region.default_region,
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
      (!var.cloudrun_enabled || length(module.cloudrun) == 0) ? [] : [
        for config in local.test_configs : {
          "name"        = "Cloud Run ${config.name}",
          "script"      = module.cloudrun[0].test_scripts[config.name],
          "parallel"    = config.parallel,
          "description" = config.description,
        }
      ],
    ),
  })
}

data "google_project" "environment" {
  project_id = var.project_id
}

module "default_region" {
  source  = "./modules/region-analysis"
  regions = var.regions
}

#-----------------------------------------------------
# Container Image Building
#-----------------------------------------------------

module "agent" {
  source = "./modules/builder"

  project_id        = var.project_id
  region            = module.default_region.default_region
  repository_region = module.infrastructure.artifact_registry.location
  repository_id     = module.infrastructure.artifact_registry.name


  containers = {
    agent = {
      source = "${path.module}/agent/src"
    },
    loadtest = {
      source = "${path.module}/src"
    },
    american_option = {
      source = "${path.module}/american-option"
    }
  }

  depends_on = [
    google_service_account.cloudbuild_actor,
    null_resource.depends_on_vpc_sc_rules
  ]
}


#-----------------------------------------------------
# Cloud Run Deployment
#-----------------------------------------------------

module "cloudrun" {
  source = "./agent/modules/run"
  count  = var.cloudrun_enabled ? 1 : 0
  # var.bq_dataset is defined?

  project_id  = var.project_id
  region      = module.default_region.default_region
  agent_image = module.agent.status["agent"].image

  # Cloud Run specific options
  bq_dataset = google_bigquery_dataset.main.dataset_id

  # Pub/Sub configuration
  pubsub_exactly_once = var.pubsub_exactly_once

  # Workload options
  workload_image         = module.agent.status["loadtest"].image
  workload_args          = local.workload_args
  workload_grpc_endpoint = local.workload_grpc_endpoint
  workload_init_args     = local.workload_init_args
  test_configs           = local.test_configs_dict

  depends_on = [google_service_account.cloudrun_actor]
}


#-----------------------------------------------------
# GKE Deployment
#-----------------------------------------------------

module "gke" {
  source = "./agent/modules/gke"

  project_id  = var.project_id
  regions     = var.regions
  agent_image = module.agent.status["agent"].image
  # GCS specific options
  hsn_bucket = var.hsn_bucket
  # GKE specific options
  gke_clusters = module.infrastructure.gke_clusters

  # Pub/Sub configuration
  pubsub_exactly_once = var.pubsub_exactly_once

  # Workload options
  # TODO: Other configuration for the workload - needs to be standardized
  workload_image         = module.agent.status["loadtest"].image
  workload_args          = local.workload_args
  workload_grpc_endpoint = local.workload_grpc_endpoint
  workload_init_args     = local.workload_init_args
  test_configs           = local.test_configs_dict

  # Parallelstore Config
  parallelstore_enabled   = var.storage_type == "PARALLELSTORE"
  parallelstore_instances = module.infrastructure.parallelstore_instances
  vpc_name                = module.infrastructure.vpc.name

  depends_on = [
    module.infrastructure,
    module.agent,
    google_project_iam_member.gke_hpa,
    google_project_iam_member.metrics_writer
  ]
}

#-----------------------------------------------------
# Logging and Analytics Configuration
#-----------------------------------------------------

# Always have the same filter. Leave this at the top level. This will
# capture application *and* agent stuff.
# To be put into an *agent* module...
resource "google_logging_project_bucket_config" "analytics-enabled-bucket" {
  project          = var.project_id
  location         = module.default_region.default_region
  enable_analytics = true
  bucket_id        = "applogs"
  lifecycle {
    ignore_changes = [project]
  }
}

resource "google_logging_linked_dataset" "logging_linked_dataset" {
  link_id     = "applogs"
  bucket      = google_logging_project_bucket_config.analytics-enabled-bucket.id
  description = "Linked dataset test"
  depends_on = [
    module.infrastructure
  ]
}

resource "google_logging_project_sink" "my-sink" {
  project = var.project_id
  name    = "my-pubsub-instance-sink"

  # Can export to pubsub, cloud storage, bigquery, log bucket, or another project
  destination = "logging.googleapis.com/${google_logging_project_bucket_config.analytics-enabled-bucket.id}"

  # This depends on the use of GKE and Cloud Run for the filter
  filter = "logName=\"projects/${var.project_id}/logs/stdout\" OR logName=\"projects/${var.project_id}/logs/stderr\" OR logName=\"projects/${var.project_id}/logs/run.googleapis.com%2Fstdout\" OR logName=\"projects/${var.project_id}/logs/run.googleapis.com%2Fstdout\""

  description = "Local application logs"
}

resource "google_bigquery_dataset" "main" {
  project                    = var.project_id
  dataset_id                 = "workload"
  location                   = module.default_region.default_region
  delete_contents_on_destroy = true

  depends_on = [
    module.infrastructure
  ]
}

#
# Logging BigQuery views
#

# Create an abstraction across Cloud Run Jobs, Cloud Run Services, and K8S pods
resource "google_bigquery_table" "log_stats" {
  project             = var.project_id
  dataset_id          = google_bigquery_dataset.main.dataset_id
  table_id            = "log_stats"
  deletion_protection = false

  view {
    query = templatefile(
      "${path.module}/sql/log_stats.sql", {
        project_id = var.project_id
        dataset_id = regex("^bigquery.googleapis.com/projects/[^/]+/datasets/(.*)$", google_logging_linked_dataset.logging_linked_dataset.bigquery_dataset[0].dataset_id)[0]
    })
    use_legacy_sql = false
  }
}

# Collect agent statistics
resource "google_bigquery_table" "agent_stats" {
  project             = var.project_id
  dataset_id          = google_bigquery_dataset.main.dataset_id
  table_id            = "agent_stats"
  deletion_protection = false

  view {
    query = templatefile(
      "${path.module}/sql/agent_stats.sql", {
        project_id = var.project_id
        dataset_id = google_bigquery_dataset.main.dataset_id
        table_id   = google_bigquery_table.log_stats.table_id
    })
    use_legacy_sql = false
  }
}

# Summarise agent statistics by instance
resource "google_bigquery_table" "agent_summary_by_instance" {
  project             = var.project_id
  dataset_id          = google_bigquery_dataset.main.dataset_id
  table_id            = "agent_summary_by_instance"
  deletion_protection = false

  view {
    query = templatefile(
      "${path.module}/sql/agent_summary_by_instance.sql", {
        project_id = var.project_id
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
  project_id = var.project_id
  # region                     = module.default_region.default_region
  bigquery_dataset           = google_bigquery_dataset.main.dataset_id
  bigquery_table             = "pubsub_messages"
  subscriber_service_account = google_service_account.bq_write_service_account.email
  topics = concat(
    var.cloudrun_enabled && length(module.cloudrun) > 0 ? module.cloudrun[0].topics : [],
    length(module.gke) > 0 ? module.gke.topics : []
  )
}

resource "google_pubsub_topic_iam_member" "topic_subscriber" {
  for_each = toset(concat(
    var.cloudrun_enabled && length(module.cloudrun) > 0 ? module.cloudrun[0].topics : [],
    length(module.gke) > 0 ? module.gke.topics : []
  ))

  project = var.project_id
  topic   = each.value
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.bq_write_service_account.email}"
}

resource "google_service_account" "bq_write_service_account" {
  project      = var.project_id
  account_id   = "pubsub-bigquery-writer"
  display_name = "BQ Write Service Account"
}

# Apply needed permission to GCP service account (workload identity)
# for reading Pub/Sub metrics
resource "google_project_iam_member" "gke_hpa" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "principal://iam.googleapis.com/projects/${data.google_project.environment.number}/locations/global/workloadIdentityPools/${data.google_project.environment.project_id}.svc.id.goog/subject/ns/custom-metrics/sa/custom-metrics-stackdriver-adapter"

  depends_on = [module.infrastructure]
}

resource "google_project_iam_member" "metrics_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "principal://iam.googleapis.com/projects/${data.google_project.environment.number}/locations/global/workloadIdentityPools/${data.google_project.environment.project_id}.svc.id.goog/subject/ns/default/sa/default"

  depends_on = [module.infrastructure]
}

#-----------------------------------------------------
# Quota Requests
#-----------------------------------------------------

module "quota" {
  count  = var.additional_quota_enabled ? 1 : 0
  source = "./modules/quota"

  project_id          = var.project_id
  quota_contact_email = var.quota_contact_email

  quota_preferences = [
    {
      service         = "compute.googleapis.com"
      quota_id        = "PREEMPTIBLE-CPUS-per-project-region"
      preferred_value = 10000
      region          = module.default_region.default_region
    },
    {
      service         = "compute.googleapis.com"
      quota_id        = "DISKS-TOTAL-GB-per-project-region"
      preferred_value = 65000
      region          = module.default_region.default_region
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
  project             = var.project_id
  dataset_id          = google_bigquery_dataset.main.dataset_id
  table_id            = "pubsub_messages_joined"
  deletion_protection = false

  view {
    query = templatefile(
      "${path.module}/sql/pubsub_messages_joined.sql", {
        project_id = var.project_id
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
  project             = var.project_id
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


#-----------------------------------------------------
# UI Configuration and Test Scripts
#-----------------------------------------------------

resource "local_file" "test_scripts" {
  for_each = (var.scripts_output == "") ? {} : {
    for config in local.test_configs : "gke_${config.name}.sh" => join("\n\n",
      [for script in module.gke.test_scripts_list : script if strcontains(script, replace(config.name, "_", "-"))]
    ) if length(module.gke) > 0
  }
  filename = "${var.scripts_output}/${each.key}"
  content  = each.value
}

resource "local_file" "test_scripts_cloudrun" {
  for_each = (var.scripts_output == "" || !var.cloudrun_enabled) ? {} : {
    for k, v in module.cloudrun[0].test_scripts : "run_${k}.sh" => v
    if length(module.cloudrun) > 0
  }
  content  = each.value
  filename = "${var.scripts_output}/${each.key}"
}

# Create UI config file
resource "local_file" "ui_config" {
  filename = "${var.scripts_output}/config.yaml"
  content  = local.ui_config_file
}

# Build the container (Docker file Cloudbuild)
module "ui_image" {
  count = var.ui_image_enabled ? 1 : 0

  source = "./modules/builder"

  project_id        = var.project_id
  region            = module.default_region.default_region
  repository_region = module.infrastructure.artifact_registry.location
  repository_id     = module.infrastructure.artifact_registry.name

  containers = {
    ui = {
      source      = "${path.module}/ui"
      config_yaml = local.ui_config_file
    }
  }
  # service_account_name = "ui-cloudbuild"

  depends_on = [
    google_service_account.cloudbuild_actor,
    null_resource.depends_on_vpc_sc_rules
  ]
}
