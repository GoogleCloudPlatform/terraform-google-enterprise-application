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
# Pub/Sub topics and subscriptions
#

resource "google_pubsub_topic" "topic_req" {
  count   = local.enable_jobs
  project = var.project_id
  name    = var.run_job_request
  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

resource "google_pubsub_subscription" "sub_req" {
  count                        = local.enable_jobs
  project                      = google_pubsub_topic.topic_req[0].project
  topic                        = google_pubsub_topic.topic_req[0].name
  name                         = "${var.run_job_request}_sub"
  enable_exactly_once_delivery = var.pubsub_exactly_once
  ack_deadline_seconds         = 60
  expiration_policy {
    ttl = ""
  }
  retry_policy {
    minimum_backoff = "30s"
    maximum_backoff = "600s"
  }
}

resource "google_pubsub_topic" "topic_resp" {
  count   = local.enable_jobs
  project = var.project_id
  name    = var.run_job_response
  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

resource "google_pubsub_subscription" "sub_resp" {
  count                        = local.enable_jobs
  project                      = google_pubsub_topic.topic_resp[0].project
  topic                        = google_pubsub_topic.topic_resp[0].name
  name                         = "${var.run_job_response}_sub"
  enable_exactly_once_delivery = true
  ack_deadline_seconds         = 60
  expiration_policy {
    ttl = ""
  }
  retry_policy {
    minimum_backoff = "30s"
    maximum_backoff = "600s"
  }
}

resource "google_pubsub_topic_iam_member" "cloudrun_publisher" {
  count   = local.enable_jobs
  project = google_pubsub_topic.topic_resp[0].project
  topic   = google_pubsub_topic.topic_resp[0].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.cloudrun_actor.email}"
}

resource "google_pubsub_topic_iam_member" "cloudrun_publisher_reqs" {
  count   = local.enable_jobs
  project = google_pubsub_topic.topic_req[0].project
  topic   = google_pubsub_topic.topic_req[0].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.cloudrun_actor.email}"
}

resource "google_pubsub_subscription_iam_member" "cloudrun_subscriber" {
  count        = local.enable_jobs
  project      = google_pubsub_subscription.sub_req[0].project
  subscription = google_pubsub_subscription.sub_req[0].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.cloudrun_actor.email}"
}

resource "google_pubsub_subscription_iam_member" "cloudrun_subscriber_resps" {
  count        = local.enable_jobs
  project      = google_pubsub_subscription.sub_resp[0].project
  subscription = google_pubsub_subscription.sub_resp[0].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.cloudrun_actor.email}"
}


#
# Cloud Run jobs
#

resource "google_cloud_run_v2_job" "workload_worker" {
  count = local.enable_jobs

  name                = "workload-worker"
  project             = var.project_id
  location            = var.region
  deletion_protection = false

  depends_on = [
    google_project_service.cloudrun
  ]

  template {
    template {
      service_account       = google_service_account.cloudrun_actor.email
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
      timeout               = "86400s"
      max_retries           = 0

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
        args = [
          "serve",
          "pubsub-pull",
          google_pubsub_subscription.sub_req[0].name,
          google_pubsub_topic.topic_resp[0].name,
          # Log to JSON
          "--logJSON",
          # Log every task
          "--logAll",
          # Text encode protobuf on PubSub
          "--jsonPubSub=true",
          # Endpoint to dispatch the work
          "--endpoint", var.workload_grpc_endpoint,
          # Timeout waiting for the gRPC service to be available
          "--timeout", "30s",
          # Timeout when there's no more work from Pub/Sub -- stop everything.
          "--idleTimeout", "120s",
          # NOTE: These are important so that only a small number of messages (tasks)
          # are pulled from Pub/Sub, as if they are chunky in size they need to be
          # evenly distributed.
          # Maximum number of goroutines executing
          "--goroutines", "1",
          # Maximum number of outstanding messages
          "--maxoutstandingmessages", "1",
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
}
