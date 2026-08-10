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

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| capacity\_gib | Custom capacity in GiB for Parallelstore instance. If null, defaults to 12000 for SCRATCH and 27000 for PERSISTENT. | `number` | `null` | no |
| deployment\_type | Parallelstore Instance deployment type (SCRATCH or PERSISTENT) | `string` | `"SCRATCH"` | no |
| instance\_id | The ID of the Parallelstore instance. If null, will be set to 'parallelstore-{location}'. | `string` | `null` | no |
| location | The location (zone) where the Parallelstore instance will be created, in the format 'region-zone' e.g., 'us-central1-a' | `string` | `"null"` | no |
| network | The VPC network to which the Parallelstore instance should be connected | `string` | `"default"` | no |
| project\_id | The GCP project where the resources will be created | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| access\_points | List of IPv4 addresses for the Parallelstore access points, required for client-side configuration including Kubernetes PersistentVolumes and Daemonsets |
| capacity\_gib | Provisioned storage capacity of the Parallelstore instance in Gibibytes (GiB), useful for capacity planning and cost estimation |
| daos\_version | Version of the Distributed Application Object Storage (DAOS) software running in the Parallelstore instance, useful for compatibility checks and documentation |
| id | Fully qualified identifier for the Parallelstore resource in format projects/{{project}}/locations/{{location}}/instances/{{instance\_id}}, used in API calls and scripts |
| instance\_id | ID of the Parallelstore instance |
| location | Zone location where the Parallelstore instance is deployed (format: {region}-{zone}), important for co-locating with compute resources |
| name | Fully qualified name of the Parallelstore instance in format projects/{{project}}/locations/{{location}}/instances/{{name}}, used in Google Cloud API calls |
| name\_short | Resource name in the format {{name}} |
| region | Region extracted from the location |
| reserved\_ip\_range | Identifier of the allocated IP address range associated with the Parallelstore private service access connection, used for network planning and troubleshooting |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
