# Google Cloud Lustre Module

This module creates a Lustre filesystem on Google Cloud, a high-performance parallel file system designed for HPC, genomics, and other data-intensive workloads.

## Usage

```hcl
module "lustre" {
  source = "github.com/GoogleCloudPlatform/risk-and-research-blueprints//terraform/modules/lustre"

  project_id          = "your-project-id"
  location            = "us-central1-a"
  network             = google_compute_network.vpc.id
  filesystem          = "lustre-fs"
  capacity_gib        = 18000
  gke_support_enabled = true
}
```

## Features

- Create high-performance Lustre filesystems for data-intensive workloads
- GKE integration for using Lustre with Kubernetes workloads
- Configurable capacity in multiples of 9000 GiB
- Automatic zone selection if only a region is provided
- VPC network connectivity for secure access

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | The GCP project where the resources will be created | `string` | n/a | yes |
| location | The location (zone) where the Lustre instance will be created | `string` | `null` | yes |
| instance_id | The ID of the Lustre instance | `string` | `null` | no |
| filesystem | The name of the Lustre filesystem | `string` | `"lustre-fs"` | no |
| network | The VPC network to which the Lustre instance should be connected | `string` | `"default"` | no |
| capacity_gib | Capacity in GiB for Lustre instance. Must be a multiple of 9000. | `number` | `18000` | no |
| gke_support_enabled | Enable GKE support for Lustre instance | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance | The created Lustre instance |
| instance_id | The ID of the Lustre instance |
| instance_name | The name of the Lustre instance |
| location | The location where the Lustre instance is created |
| filesystem | The name of the Lustre filesystem |

## Notes

- Lustre capacity must be a multiple of 9000 GiB between 18000 GiB and 936000 GiB
- GKE integration allows using Lustre as persistent volumes in Kubernetes
- Requires a properly configured VPC network with Private Service Access
- For best performance, ensure the network MTU is set to 8896
- The module handles automatic selection of a zone if only a region is provided

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
