# Region Analysis Module

This module analyzes a list of GCP regions to determine the optimal multi-region or default region for deploying resources across multiple geographies.

## Usage

```hcl
module "region_analysis" {
  source = "github.com/GoogleCloudPlatform/risk-and-research-blueprints//terraform/modules/region-analysis"

  regions = ["us-central1", "us-east4", "europe-west4"]
}

# Use the determined multi-region
resource "google_storage_bucket" "multi_region_bucket" {
  name          = "my-bucket"
  location      = module.region_analysis.multi_region
  force_destroy = true
}

# Use the default region when needed
resource "google_pubsub_topic" "topic" {
  name     = "my-topic"
  project  = "my-project"
  location = module.region_analysis.default_region
}
```

## Features

- Determines the optimal multi-region (us, europe, asia) based on region distribution
- Provides a default region for resources that must be in a single region
- Handles tie-breaking with a preference for US > Europe > Asia
- Maps individual regions to their corresponding multi-region parent

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| regions | List of regions to determine multi region choice | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| multi_region | The optimal multi-region based on the provided regions |
| default_region | The first region in the provided list, to be used as a default |

## Algorithm

The module determines the optimal multi-region using the following logic:

1. Map each region to its parent multi-region (us, europe, asia)
2. Count the number of regions in each multi-region
3. Select the multi-region with the highest count
4. In case of ties, use a preference order: US > Europe > Asia
5. If no regions match known patterns, default to "us"

## Notes

- This module is useful for determining optimal locations for global resources
- The multi-region output is ideal for storage buckets and other multi-region resources
- The default_region output is useful for services that must exist in a single region
- This approach ensures that resources are created in regions that are geographically close to your compute resources

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
