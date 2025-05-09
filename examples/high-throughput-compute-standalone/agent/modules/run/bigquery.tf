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
  enable_bq_static = var.bq_dataset != "" && var.bq_routine != ""
  bq_config        = local.enable_bq_static ? { "enabled" = true } : {}
}

#
# Cloud Run BigQuery (generic)
#

resource "google_cloud_run_v2_service" "workload_worker" {
  for_each = local.bq_config

  name                = "workload-worker-bigquery"
  project             = var.project_id
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  depends_on = [
    google_project_service.cloudrun
  ]

  template {
    scaling {
      min_instance_count = 0
      max_instance_count = 100
    }
    service_account                  = google_service_account.cloudrun_actor.email
    execution_environment            = "EXECUTION_ENVIRONMENT_GEN2"
    max_instance_request_concurrency = 2
    timeout                          = "3600s"

    # Agent container (pull/push PubSub)
    containers {
      name  = "agent"
      image = var.agent_image
      resources {
        limits = {
          cpu    = "0.1"
          memory = "128Mi"
        }
      }

      # Incoming port (http)
      ports {
        name           = "http1"
        container_port = "8080"
      }

      # per container
      startup_probe {
        tcp_socket {
          port = 8080
        }
      }

      args = [
        "serve", "rdf",
        # Log to JSON
        "--logJSON",
        # Endpoint to dispatch the work
        "--endpoint", var.workload_grpc_endpoint,
        # Log every operation
        "--logAll",
        # Timeout waiting for the gRPC service to be available
        "--timeout", "30s",
      ]
    }

    # Loadtest container
    containers {
      name  = "workload"
      image = var.workload_image
      args  = var.workload_args
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      liveness_probe {
        grpc {
          port = 2002
        }
      }

      volume_mounts {
        name       = "gcs-data"
        mount_path = "/data"
      }
      working_dir = "/data"
    }

    # Volume for data
    volumes {
      name = "gcs-data"
      gcs {
        bucket = google_storage_bucket.gcs_storage_data.name
      }
    }
  }
}


#
# BigQuery connection
#

# Create a BigQuery connection (new service account)
resource "google_bigquery_connection" "gcp_connection" {
  for_each = local.bq_config

  project       = var.project_id
  friendly_name = "BigQuery Remote Defined Function"
  description   = "BigQuery Remote Defined Function service account"
  location      = var.region
  cloud_resource {}
}

# BigQuery connection can access Cloud Run
resource "google_cloud_run_service_iam_binding" "bq_to_run_binding" {
  count = local.enable_bq

  project  = google_cloud_run_v2_service.workload_worker["enabled"].project
  location = google_cloud_run_v2_service.workload_worker["enabled"].location
  service  = google_cloud_run_v2_service.workload_worker["enabled"].name
  role     = "roles/run.invoker"
  members = [
    "serviceAccount:${google_bigquery_connection.gcp_connection["enabled"].cloud_resource[0].service_account_id}"
  ]
}

# BigQuery routine using the connection
resource "google_bigquery_routine" "remote_function" {
  count = local.enable_bq

  project      = var.project_id
  dataset_id   = var.bq_dataset
  routine_id   = var.bq_routine
  routine_type = "SCALAR_FUNCTION"
  return_type  = "{\"typeKind\" :  \"JSON\"}"
  arguments {
    name      = "task"
    data_type = "{\"typeKind\" :  \"JSON\"}"
  }
  definition_body = ""

  remote_function_options {
    endpoint             = google_cloud_run_v2_service.workload_worker["enabled"].uri
    connection           = google_bigquery_connection.gcp_connection["enabled"].id
    max_batching_rows    = "1"
    user_defined_context = {}
  }
  depends_on = [
    google_cloud_run_service_iam_binding.bq_to_run_binding[0],
  ]
}
