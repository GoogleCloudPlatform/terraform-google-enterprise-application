# Google Cloud Project Setup Module

This module configures a Google Cloud project with the necessary API services, IAM permissions, and settings required for risk and research workloads.

## Usage

```hcl
module "project_setup" {
  source = "github.com/GoogleCloudPlatform/risk-and-research-blueprints//terraform/modules/project"

  project_id          = "your-project-id"
  enable_log_analytics = true
}
```

## Features

- Enables required Google Cloud APIs for risk and research workloads
- Configures log analytics for enhanced observability
- Sets up IAM permissions for service accounts
- Enables API services for containers, storage, networking, and more
- Configures default project settings optimal for analytics workloads

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | The GCP project where the resources will be created | `string` | n/a | yes |
| enable_log_analytics | Enable log analytics in the project | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| project_id | The ID of the configured project |
| project_number | The numeric project number |
| enabled_apis | List of enabled API services |

## Enabled API Services

The module enables the following API services:

- artifactregistry.googleapis.com
- cloudresourcemanager.googleapis.com
- compute.googleapis.com
- container.googleapis.com
- containeranalysis.googleapis.com
- containerfilesystem.googleapis.com
- containerregistry.googleapis.com
- containersecurity.googleapis.com
- iam.googleapis.com
- iamcredentials.googleapis.com
- logging.googleapis.com
- monitoring.googleapis.com
- networksecurity.googleapis.com
- parallelstore.googleapis.com
- pubsub.googleapis.com
- servicenetworking.googleapis.com
- storage-api.googleapis.com
- storage.googleapis.com

## Notes

- Some API enablement may take time to propagate, and Terraform may need to be run multiple times
- When destroying the Terraform configuration, API services will not be disabled to prevent disruption to other services
- Log analytics configuration creates linked BigQuery datasets for log analysis

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
