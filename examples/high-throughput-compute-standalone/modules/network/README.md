# Google Cloud Network Module

This module creates regional network configurations including subnets, secondary ranges for GKE pods and services, firewall rules, and DNS zones for risk and research workloads.

## Usage

```hcl
module "networking" {
  source = "github.com/GoogleCloudPlatform/risk-and-research-blueprints//terraform/modules/network"

  project_id = "your-project-id"
  region     = "us-central1"
  regions    = ["us-central1", "us-east4"]
  vpc_id     = google_compute_network.vpc.id
  vpc_name   = google_compute_network.vpc.name
}
```

## Features

- Creates region-specific subnets with appropriate CIDR ranges
- Configures secondary IP ranges for GKE pods and services
- Automatically calculates non-overlapping IP ranges based on region index
- Sets up firewall rules for internal communication
- Supports multi-region deployments with consistent networking patterns

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | The GCP project where the resources will be created | `string` | n/a | yes |
| region | The region to host the cluster in | `string` | `"us-central1"` | no |
| regions | List of regions where GKE clusters should be created | `list(string)` | `["us-central1"]` | no |
| vpc_id | ID of the shared VPC network | `string` | n/a | yes |
| vpc_name | Name of the shared VPC network | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| subnet_id | The ID of the created subnet |
| subnet_name | The name of the created subnet |
| subnet_cidr | The CIDR range of the created subnet |
| pod_range_name | The name of the secondary range for GKE pods |
| service_range_name | The name of the secondary range for GKE services |
| region | The region where the subnet is created |
| region_index | The index of the region in the provided regions list |

## Notes

- The module calculates CIDR ranges based on the region's index in the provided regions list
- Primary subnet CIDR: 10.{region_index}.0.0/20
- Secondary ranges for pods: 10.{region_index}.16.0/20
- Secondary ranges for services: 10.{region_index}.32.0/20
- For multi-region deployments, ensure you provide a complete list of regions to avoid CIDR overlaps

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
| project\_id | The GCP project where the resources will be created | `string` | n/a | yes |
| region | The region to host the cluster in | `string` | `"us-central1"` | no |
| regions | List of regions where GKE clusters should be created | `list(string)` | <pre>[<br>  "us-central1"<br>]</pre> | no |
| vpc\_id | ID of the shared VPC network | `string` | n/a | yes |
| vpc\_name | Name of the shared VPC network | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| nat\_ip | List of static IP addresses assigned to the Cloud NAT gateway for egress traffic from the private GKE cluster |
| pod\_range\_name | Name of the secondary IP range created for Kubernetes pods in the specified region, used during GKE cluster creation |
| router\_id | Fully qualified identifier of the Cloud Router resource in format projects/{project}/regions/{region}/routers/{name} |
| service\_range\_name | Name of the secondary IP range created for Kubernetes services in the specified region, used during GKE cluster creation |
| subnet\_id | Fully qualified identifier of the created GKE subnet in format projects/{project}/regions/{region}/subnetworks/{name} |
| subnet\_name | Name of the created GKE subnet used for referencing in GKE cluster creation and other resources |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
