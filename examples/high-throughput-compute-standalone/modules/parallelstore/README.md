# Google Cloud Parallelstore Module

This module creates a Google Cloud Parallelstore instance, a high-performance filesystem designed for HPC and ML/AI workloads requiring fast data access across multiple compute nodes.

## Usage

```hcl
module "parallelstore" {
  source = "github.com/GoogleCloudPlatform/risk-and-research-blueprints//terraform/modules/parallelstore"

  project_id      = "your-project-id"
  location        = "us-central1-a"
  network         = google_compute_network.vpc.id
  deployment_type = "SCRATCH"
  capacity_gib    = 12000
}
```

## Features

- Create Parallelstore instances in either SCRATCH or PERSISTENT deployment types
- Automatically select a zone if only a region is provided
- Customizable capacity based on workload requirements
- Default capacity values optimized for each deployment type
- VPC network connectivity for secure access

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | The GCP project where the resources will be created | `string` | n/a | yes |
| location | The location (zone) where the Parallelstore instance will be created | `string` | `null` | yes |
| instance_id | The ID of the Parallelstore instance | `string` | `null` | no |
| network | The VPC network to which the Parallelstore instance should be connected | `string` | `"default"` | no |
| deployment_type | Parallelstore Instance deployment type (SCRATCH or PERSISTENT) | `string` | `"SCRATCH"` | no |
| capacity_gib | Custom capacity in GiB for Parallelstore instance | `number` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance | The created Parallelstore instance |
| instance_id | The ID of the Parallelstore instance |
| instance_name | The name of the Parallelstore instance |
| location | The location where the Parallelstore instance is created |

## Notes

- SCRATCH deployment type is optimized for temporary, high-performance workloads
- PERSISTENT deployment type is designed for long-term data storage with durability
- If no capacity is specified, defaults to 12000 GiB for SCRATCH and 27000 GiB for PERSISTENT
- Requires a properly configured VPC network with Private Service Access
- For best performance, ensure the network MTU is set to 8896

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
