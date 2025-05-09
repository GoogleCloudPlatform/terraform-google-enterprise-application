# Google Artifact Registry Module

This module creates a Google Artifact Registry repository to store container images for risk and research workloads. It configures the repository with appropriate cleanup policies to manage image versions.

## Usage

```hcl
module "artifact_registry" {
  source = "github.com/GoogleCloudPlatform/risk-and-research-blueprints//terraform/modules/artifact-registry"

  project_id        = "your-project-id"
  regions           = ["us-central1", "us-east4"]
  name              = "research-images"
  cleanup_keep_count = 10
}
```

## Features

- Creates a Docker container registry in Artifact Registry
- Automatically determines the best multi-region location based on provided regions
- Configures cleanup policies to maintain a specific number of recent image versions
- Enables vulnerability scanning for container images

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | The GCP project where the resources will be created | `string` | n/a | yes |
| regions | List of regions where resources will be deployed - used to determine the multi-region location | `list(string)` | `["us-central1"]` | no |
| name | Name of the Artifact Registry | `string` | `"research-images"` | no |
| cleanup_keep_count | Number of most recent container image versions to keep in Artifact Registry cleanup policy | `number` | `10` | no |

## Outputs

| Name | Description |
|------|-------------|
| artifact_registry | The Artifact Registry repository object |
| location | The location of the Artifact Registry repository |
| repository_url | The URL of the Artifact Registry repository |

## Notes

- The module automatically determines whether to use a regional or multi-regional location for the repository based on the regions provided.
- Cleanup policies are configured to keep the specified number of most recent container image versions.
- Vulnerability scanning is enabled by default to enhance container security.

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
