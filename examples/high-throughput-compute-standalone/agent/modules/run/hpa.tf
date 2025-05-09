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


#
# Create Pub/Sub topics and subscriptions
#

resource "google_pubsub_topic" "hpa_topic_req" {
  count   = local.enable_jobs
  project = var.project_id
  name    = var.run_hpa_request
  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

resource "google_pubsub_topic" "hpa_topic_resp" {
  count   = local.enable_jobs
  project = var.project_id
  name    = var.run_hpa_response
  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

resource "google_pubsub_subscription" "hpa_sub_resp" {
  count                        = local.enable_jobs
  project                      = google_pubsub_topic.hpa_topic_resp[0].project
  topic                        = google_pubsub_topic.hpa_topic_resp[0].name
  name                         = "${var.run_hpa_response}_sub"
  enable_exactly_once_delivery = true
  ack_deadline_seconds         = 60
}

resource "google_pubsub_subscription" "hpa_sub_req" {
  count                = local.enable_jobs
  project              = google_pubsub_topic.hpa_topic_req[0].project
  topic                = google_pubsub_topic.hpa_topic_req[0].name
  name                 = "${var.run_hpa_request}_sub"
  ack_deadline_seconds = 600
  push_config {
    push_endpoint = google_cloud_run_v2_service.workload_pubsub_worker.uri
    oidc_token {
      service_account_email = google_service_account.pubsub_pusher.email
    }
  }
}


#
# Pub/Sub pusher to the endpoint
#

resource "google_service_account" "pubsub_pusher" {
  project      = var.project_id
  account_id   = "pubsub-pusher"
  display_name = "Pub/Sub to Cloud Run pusher"
}

resource "google_pubsub_topic_iam_member" "hpa_cloudrun_publisher" {
  count   = local.enable_jobs
  project = google_pubsub_topic.hpa_topic_resp[0].project
  topic   = google_pubsub_topic.hpa_topic_resp[0].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.cloudrun_actor.email}"
}
resource "google_pubsub_topic_iam_member" "hpa_cloudrun_publisher_reqs" {
  count   = local.enable_jobs
  project = google_pubsub_topic.hpa_topic_req[0].project
  topic   = google_pubsub_topic.hpa_topic_req[0].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.cloudrun_actor.email}"
}
resource "google_pubsub_subscription_iam_member" "hpa_cloudrun_subscriber_resps" {
  count        = local.enable_jobs
  project      = google_pubsub_subscription.hpa_sub_resp[0].project
  subscription = google_pubsub_subscription.hpa_sub_resp[0].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.cloudrun_actor.email}"
}

# Pub/Sub publisher can call Cloud Run
resource "google_cloud_run_service_iam_binding" "pubsub_to_run_binding" {
  project  = google_cloud_run_v2_service.workload_pubsub_worker.project
  location = google_cloud_run_v2_service.workload_pubsub_worker.location
  service  = google_cloud_run_v2_service.workload_pubsub_worker.name
  role     = "roles/run.invoker"
  members = [
    "serviceAccount:${google_service_account.pubsub_pusher.email}"
  ]
}

resource "google_cloud_run_v2_service" "workload_pubsub_worker" {
  name                = "workload-worker-pubsub"
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
        "serve", "pubsub-push",
        google_pubsub_topic.hpa_topic_resp[0].name,

        # Enable debug
        "--debug",
        # Log to JSON
        "--logJSON",
        # Log every task
        "--logAll",
        # Text encoding on json Pub/Sub
        "--jsonPubSub=true",
        # Endpoint to dispatch the work
        "--endpoint", var.workload_grpc_endpoint,
        # Timeout waiting for the gRPC service to be available
        "--timeout", "30s",
      ]
    }

    # Workload container
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
