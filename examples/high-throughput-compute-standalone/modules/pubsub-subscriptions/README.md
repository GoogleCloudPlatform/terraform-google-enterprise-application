# Google Cloud Pub/Sub to BigQuery Module

This module creates Pub/Sub subscriptions that automatically write messages to BigQuery tables, enabling real-time data analytics for risk and research workloads.

## Usage

```hcl
module "pubsub_bigquery" {
  source = "github.com/GoogleCloudPlatform/risk-and-research-blueprints//terraform/modules/pubsub-subscriptions"

  project_id                 = "your-project-id"
  region                     = "us-central1"
  bigquery_dataset           = "analytics_dataset"
  bigquery_table             = "pubsub_messages"
  topics                     = ["topic-1", "topic-2", "topic-3"]
  subscriber_service_account = google_service_account.pubsub_sa.email
}
```

## Features

- Creates BigQuery subscriptions for multiple Pub/Sub topics
- Automatically writes Pub/Sub messages to BigQuery tables
- Configures appropriate IAM permissions
- Supports schema validation for messages
- Enables real-time data analytics on streaming data

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | The GCP project ID where resources will be created | `string` | n/a | yes |
| region | The Region of the Pub/Sub topic and subscriptions | `string` | n/a | yes |
| bigquery_dataset | The Dataset for capturing BigQuery data | `string` | n/a | yes |
| bigquery_table | The BigQuery table for capturing Pub/Sub data | `string` | n/a | yes |
| topics | List of topics to persist to BigQuery | `list(string)` | n/a | yes |
| subscriber_service_account | Service account that will be granted subscriber role on topics | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| subscriptions | List of created BigQuery subscriptions |
| subscription_paths | Full paths of the created subscriptions |

## Notes

- The module expects the BigQuery dataset and table to exist already
- Messages are written to BigQuery in near real-time
- Pub/Sub messages should be in JSON format for optimal BigQuery integration
- Schema validation can help ensure data quality
- The subscriber service account needs appropriate permissions to read from Pub/Sub and write to BigQuery

## License

Copyright 2024 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
