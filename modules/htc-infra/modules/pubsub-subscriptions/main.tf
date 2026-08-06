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
# BigQuery persistence
#

# resource "google_service_account" "bq_write_service_account" {
#   project      = var.project_id
#   account_id   = "pubsub-bigquery-writer"
#   display_name = "BQ Write Service Account"
# }

data "local_file" "pubsub_json_schema" {
  filename = "${path.module}/pubsub_json_schema.txt"
}

resource "google_bigquery_table" "messages" {
  project             = var.project_id
  deletion_protection = false
  table_id            = var.bigquery_table
  dataset_id          = var.bigquery_dataset

  # 90 days
  time_partitioning {
    expiration_ms = 90 * 24 * 60 * 60 * 1000
    field         = "publish_time"
    type          = "DAY"
  }

  schema = data.local_file.pubsub_json_schema.content
}

# Permission for metadata on the table
resource "google_bigquery_table_iam_member" "message_metadata" {
  project    = var.project_id
  dataset_id = google_bigquery_table.messages.dataset_id
  table_id   = google_bigquery_table.messages.table_id
  role       = "roles/bigquery.metadataViewer"
  # member     = "serviceAccount:${google_service_account.bq_write_service_account.email}"
  member = "serviceAccount:${var.subscriber_service_account}"
}

# Permission for inserting into the table
resource "google_bigquery_table_iam_member" "message_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_table.messages.dataset_id
  table_id   = google_bigquery_table.messages.table_id
  role       = "roles/bigquery.dataEditor"
  # member     = "serviceAccount:${google_service_account.bq_write_service_account.email}"
  member = "serviceAccount:${var.subscriber_service_account}"
}


#
# Want JSON-based PubSub subscriptions.
#

# resource "google_pubsub_topic_iam_member" "topic_subscriber" {
#   for_each = toset(var.topics)

#   project = var.project_id
#   topic   = each.value
#   role    = "roles/pubsub.subscriber"
#   member  = "serviceAccount:${google_service_account.bq_write_service_account.email}"
# }

resource "google_pubsub_subscription" "bq_sub" {
  for_each = toset(var.topics)

  depends_on = [
    google_bigquery_table_iam_member.message_editor,
    google_bigquery_table_iam_member.message_metadata,
    # google_pubsub_topic_iam_member.topic_subscriber,
  ]

  project = var.project_id
  name    = "${each.value}_bq"
  topic   = each.value

  bigquery_config {
    table                 = "${google_bigquery_table.messages.project}.${google_bigquery_table.messages.dataset_id}.${google_bigquery_table.messages.table_id}"
    service_account_email = var.subscriber_service_account
    write_metadata        = true
  }
}
