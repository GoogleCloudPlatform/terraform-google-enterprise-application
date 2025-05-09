# Google Cloud Quota Preferences Module

This module allows you to request multiple quota preferences for your Google Cloud project using the `google_cloud_quotas_quota_preference` resource. It provides a flexible way to request various quota increases across different Google Cloud services and regions.

## Usage

```hcl
module "quota" {
  source = "github.com/GoogleCloudPlatform/risk-and-research-blueprints//terraform/modules/quota"

  project_id          = "your-project-id"
  quota_contact_email = "your-email@example.com"

  quota_preferences = [
    {
      service         = "compute.googleapis.com"
      quota_id        = "PREEMPTIBLE-CPUS-per-project-region"
      preferred_value = 10000
      region          = "us-central1"
    },
    {
      service         = "compute.googleapis.com"
      quota_id        = "DISKS-TOTAL-GB-per-project-region"
      preferred_value = 65000
      region          = "us-central1"
    },
    {
      service         = "monitoring.googleapis.com"
      quota_id        = "IngestionRequestsPerMinutePerProject"
      preferred_value = 100000
    }
  ]
}
```

## Features

- Request multiple quota preferences in one module
- Automatically handle region-specific quotas
- Skip quota requests when no contact email is provided
- Customizable quota preference names

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | The GCP project where the resources will be created | `string` | n/a | yes |
| region | The default region to host resources in | `string` | `"us-central1"` | no |
| quota_contact_email | Contact email for quota requests | `string` | `""` | no |
| quota_preferences | List of quota preferences to request | `list(object)` | `[]` | no |

### Quota Preferences Object Structure

```hcl
object({
  service         = string        # Service name (e.g., "compute.googleapis.com")
  quota_id        = string        # Quota ID (e.g., "PREEMPTIBLE-CPUS-per-project-region")
  preferred_value = number        # Requested quota value
  dimensions      = map(string)   # Optional dimensions (will include region if specified)
  region          = string        # Optional region (will be added to dimensions)
  custom_name     = string        # Optional custom name for the resource
})
```

## Outputs

| Name | Description |
|------|-------------|
| quota_preferences | Map of created quota preferences |
| requested_quota_count | Number of quota preferences requested |

## Examples

An example implementation can be found in the [examples/infrastructure/multi-quota](../../examples/infrastructure/multi-quota) directory, demonstrating how to request quotas for multiple regions and services in a single module call.

## Notes

- If `quota_contact_email` is empty, no quota preferences will be created
- The module uses a lifecycle configuration to ignore all changes after creation, as quota updates are handled by Google Cloud
- For region-specific quotas, provide the region in the `region` field and it will be properly added to dimensions
- This module sends quota **requests** that must be approved by Google Cloud. Check the [Quotas documentation](https://cloud.google.com/docs/quotas) for more information
- Quota requests may take time to process and are not guaranteed to be approved

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
