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

  # Whether to enable different patterns
  enable_bq   = (var.bq_dataset != "" && var.bq_routine != "") ? 1 : 0
  enable_jobs = (var.run_job_request != "" && var.run_job_response != "") ? 1 : 0
  enable_hpa  = (var.run_hpa_request != "" && var.run_hpa_response != "") ? 1 : 0

  # Pub/Sub topics created (for output)
  topics = concat(
    local.enable_jobs == 1 ? [
      google_pubsub_topic.topic_req[0].name,
      google_pubsub_topic.topic_resp[0].name,
    ] : [],
    local.enable_hpa == 1 ? [
      google_pubsub_topic.hpa_topic_req[0].name,
      google_pubsub_topic.hpa_topic_resp[0].name,
    ] : [],
  )

  # Test scripts for output
  test_scripts = {
    for id, cfg in var.test_configs :
    id => templatefile(
      "${path.module}/test_config.sh.templ", {
        parallel = cfg.parallel,
        testfile = cfg.testfile,

        # Common across all
        project              = var.project_id
        region               = var.region
        run_hpa_request      = var.run_hpa_request
        run_hpa_response_sub = google_pubsub_subscription.hpa_sub_resp[0].name
        run_job_request      = var.run_job_request
        run_job_response_sub = google_pubsub_subscription.sub_resp[0].name
    })
  }
}


#
# General Cloud Run
#

# Enable Cloud Run service
resource "google_project_service" "cloudrun" {
  project = var.project_id
  service = "run.googleapis.com"

}

# Cloud Run service account
resource "google_service_account" "cloudrun_actor" {
  project      = var.project_id
  account_id   = "cloudrun-actor"
  display_name = "Cloud Run custom service account"
}

resource "google_project_iam_member" "cloudrun_gcs_member" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloudrun_actor.email}"
}


#
# GCS Bucket for Testing
#

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "google_storage_bucket" "gcs_storage_data" {
  project                     = var.project_id
  location                    = var.region
  name                        = "${var.project_id}-${var.region}-run-data-${random_string.suffix.id}"
  uniform_bucket_level_access = true
  force_destroy               = true
}

# Admin access to GCS bucket
resource "google_storage_bucket_iam_member" "cloudrun_gcs_member" {
  bucket = google_storage_bucket.gcs_storage_data.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.cloudrun_actor.email}"
}


#
# Job definition for agent controller
# (Always)
#
resource "google_cloud_run_v2_job" "agent" {
  name                = "controller"
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
      max_retries           = 0
      timeout               = "86400s"

      containers {
        name  = "controller"
        image = var.agent_image
        resources {
          limits = {
            cpu    = "1"
            memory = "1024Mi"
          }
        }
        volume_mounts {
          name       = "gcs-data"
          mount_path = "/data"
        }
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


#
# Job definition for workload
# (Always)
#
resource "google_cloud_run_v2_job" "workload_workload" {
  name                = "workload"
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
      max_retries           = 0
      timeout               = "86400s"

      containers {
        name  = "workload"
        image = var.workload_image
        resources {
          limits = {
            cpu    = "1"
            memory = "1024Mi"
          }
        }
        volume_mounts {
          name       = "gcs-data"
          mount_path = "/data"
        }
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


#
# Initialization
#
resource "null_resource" "workload_init" {
  for_each = toset([
    for args in var.workload_init_args : join(",", args)
  ])

  depends_on = [
    google_cloud_run_v2_job.workload_workload,
    google_storage_bucket_iam_member.cloudrun_gcs_member
  ]

  triggers = {
    image = var.workload_image
    args  = each.value
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
    gcloud run jobs execute \
      workload \
      --wait \
      --project ${var.project_id} \
      --region ${var.region} \
      --tasks=1 \
      --args=${each.value}
    EOT
  }
}
