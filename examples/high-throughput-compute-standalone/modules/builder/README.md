# Google Cloud Build Module

This module configures and executes Cloud Build jobs to build and push container images to Artifact Registry for risk and research workloads.

## Usage

```hcl
module "builder" {
  source = "github.com/GoogleCloudPlatform/risk-and-research-blueprints//terraform/modules/builder"

  project_id        = "your-project-id"
  region            = "us-central1"
  repository_region = "us-central1"
  repository_id     = "research-images"

  containers = {
    app1 = {
      source = "${path.module}/src/app1"
    },
    app2 = {
      source      = "${path.module}/src/app2"
      config_yaml = file("${path.module}/config/app2-config.yaml")
    }
  }

  service_account_name = "cloudbuild-sa"
}
```

## Features

- Builds container images from source directories
- Pushes built images to Artifact Registry
- Creates and configures service accounts with appropriate permissions
- Supports passing configuration YAML to builds
- Provides status information about builds and resulting images

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | The GCP project ID where resources will be created | `string` | n/a | yes |
| region | The region of the build | `string` | n/a | yes |
| repository_region | Artifact Repository region | `string` | n/a | yes |
| repository_id | Artifact repository ID | `string` | n/a | yes |
| containers | Map of image name to configuration (source) | `map(object)` | n/a | yes |
| service_account_name | Service account name | `string` | `"cloudbuild-actor"` | no |

### Containers Object Structure

```hcl
map(object({
  source      = string       # Path to the source directory containing Dockerfile
  config_yaml = string       # Optional: Configuration YAML to pass to the build
}))
```

## Outputs

| Name | Description |
|------|-------------|
| status | Map of container build status information |
| service_account | The service account created for Cloud Build |

## Notes

- Each source directory should contain a Dockerfile or cloudbuild.yaml
- The module automatically creates a service account with appropriate permissions
- Images are tagged with the short commit hash by default
- Build logs are available in Cloud Build history
- Images are pushed to the specified Artifact Registry repository

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
