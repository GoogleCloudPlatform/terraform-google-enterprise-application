# Google Kubernetes Engine (GKE) Standard Module

This module creates a regional Google Kubernetes Engine (GKE) Standard cluster optimized for risk and research workloads. It provides configuration options for advanced networking, security, and observability features.

## Usage

```hcl
module "gke_standard" {
  source = "github.com/GoogleCloudPlatform/risk-and-research-blueprints//terraform/modules/gke-standard"

  project_id           = "your-project-id"
  region               = "us-central1"
  zones                = ["a", "b", "c"]
  cluster_name         = "risk-research-cluster"
  network              = google_compute_network.vpc.id
  subnet               = google_compute_subnetwork.subnet.id
  ip_range_services    = "gke-services-range"
  ip_range_pods        = "gke-pods-range"
  cluster_service_account = {
    email = google_service_account.gke_sa.email
    id    = google_service_account.gke_sa.id
  }

  # Optional advanced configuration
  datapath_provider = "ADVANCED_DATAPATH"
  enable_advanced_datapath_observability_metrics = true
  enable_intranode_visibility = false

  # Node pool configuration
  node_machine_type_ondemand = "n2-standard-16"
  node_machine_type_spot     = "n2-standard-64"
  min_nodes_ondemand         = 0
  max_nodes_ondemand         = 32
  min_nodes_spot             = 1
  max_nodes_spot             = 3000
}
```

## Features

- Regional GKE cluster deployment
- Support for both on-demand and spot node pools
- Advanced security features (shielded nodes, secure boot, workload identity)
- Comprehensive monitoring and logging configuration
- Built-in KMS encryption for cluster data
- Support for CSI drivers (Parallelstore, Filestore, GCS Fuse)
- Customizable cluster autoscaling
- Advanced datapath configuration options

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | The GCP project where the resources will be created | `string` | n/a | yes |
| region | The region to host the cluster in | `string` | n/a | yes |
| zones | The GCP zone letters to deploy resources to within specified regions | `list(string)` | `["a", "b", "c"]` | no |
| cluster_name | Name of GKE cluster | `string` | `"gke-risk-research"` | no |
| network | The VPC network ID where the cluster will be created | `string` | n/a | yes |
| subnet | The subnetwork ID where the cluster will be created | `string` | n/a | yes |
| ip_range_services | The secondary IP range name for services | `string` | n/a | yes |
| ip_range_pods | The secondary IP range name for pods | `string` | n/a | yes |
| cluster_service_account | The service account for the GKE cluster | `object` | n/a | yes |
| scaled_control_plane | Deploy a larger initial nodepool to ensure larger control plane nodes | `bool` | `false` | no |
| cluster_max_cpus | Maximum CPU cores in cluster autoscaling resource limits | `number` | `10000` | no |
| cluster_max_memory | Maximum memory (in GB) in cluster autoscaling resource limits | `number` | `80000` | no |
| datapath_provider | The datapath provider for the GKE cluster | `string` | `"LEGACY_DATAPATH"` | no |
| enable_advanced_datapath_observability_metrics | Enable advanced datapath observability metrics | `bool` | `true` | no |
| enable_advanced_datapath_observability_relay | Enable advanced datapath observability relay | `bool` | `false` | no |
| enable_intranode_visibility | Enable intranode visibility for the GKE cluster | `bool` | `false` | no |
| enable_cilium_clusterwide_network_policy | Enable Cilium clusterwide network policy | `bool` | `false` | no |
| node_machine_type_ondemand | Machine type for on-demand node pools | `string` | `"n2-standard-16"` | no |
| node_machine_type_spot | Machine type for spot node pools | `string` | `"n2-standard-64"` | no |
| min_nodes_ondemand | Minimum number of on-demand nodes | `number` | `0` | no |
| max_nodes_ondemand | Maximum number of on-demand nodes | `number` | `32` | no |
| min_nodes_spot | Minimum number of spot nodes | `number` | `1` | no |
| max_nodes_spot | Maximum number of spot nodes | `number` | `3000` | no |
| create_ondemand_nodepool | Whether to create the on-demand node pool | `bool` | `true` | no |
| create_spot_nodepool | Whether to create the spot node pool | `bool` | `true` | no |
| enable_shielded_nodes | Enable Shielded GKE Nodes | `bool` | `true` | no |
| enable_secure_boot | Enable Secure Boot for GKE nodes | `bool` | `true` | no |
| enable_workload_identity | Enable Workload Identity for GKE clusters | `bool` | `true` | no |
| enable_private_endpoint | Enable private endpoint for GKE control plane | `bool` | `false` | no |
| enable_csi_parallelstore | Enable the Parallelstore CSI Driver | `bool` | `false` | no |
| enable_csi_filestore | Enable the Filestore CSI Driver | `bool` | `false` | no |
| enable_csi_gcs_fuse | Enable the GCS Fuse CSI Driver | `bool` | `true` | no |
| enable_mesh_certificates | Enable mesh certificates for the GKE cluster | `bool` | `false` | no |
| maintenance_start_time | Start time for maintenance window (RFC3339) | `string` | `"2024-09-17T04:00:00Z"` | no |
| maintenance_end_time | End time for maintenance window (RFC3339) | `string` | `"2024-09-18T04:00:00Z"` | no |
| maintenance_recurrence | Recurrence of maintenance window (RRULE) | `string` | `"FREQ=WEEKLY;BYDAY=SA,SU"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | The ID of the created GKE cluster |
| cluster_name | The name of the created GKE cluster |
| cluster_location | The location (region) of the GKE cluster |
| cluster_endpoint | The endpoint for the GKE cluster |
| cluster_ca_certificate | The CA certificate for the GKE cluster |
| cluster_self_link | The self-link of the GKE cluster |
| kms_crypto_key | The KMS key used to encrypt the GKE cluster |

## Notes

- The module creates a KMS key for cluster encryption
- The default node count for scaled_control_plane (700) is higher to ensure larger control plane nodes are provisioned
- Both on-demand and spot node pools can be created with customizable machine types and autoscaling parameters
- When datapath_provider is set to ADVANCED_DATAPATH, advanced datapath observability features will be enabled based on configuration

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
| cluster\_index | Index of this cluster within its region (0-3) | `number` | n/a | yes |
| cluster\_max\_cpus | Max CPU in cluster autoscaling resource limits | `number` | `100` | no |
| cluster\_max\_memory | Max memory in cluster autoscaling resource limits | `number` | `1024` | no |
| cluster\_name | Name of GKE cluster | `string` | `"gke-risk-research"` | no |
| cluster\_service\_account | The service account for the GKE cluster | <pre>object({<br>    email = string<br>    id    = string<br>  })</pre> | n/a | yes |
| create\_ondemand\_nodepool | Whether to create the on-demand node pool | `bool` | `true` | no |
| create\_spot\_nodepool | Whether to create the spot node pool | `bool` | `true` | no |
| datapath\_provider | The datapath provider for the GKE cluster (DATAPATH\_PROVIDER\_UNSPECIFIED, LEGACY\_DATAPATH, or ADVANCED\_DATAPATH) | `string` | `"LEGACY_DATAPATH"` | no |
| enable\_advanced\_datapath\_observability\_metrics | Enable advanced datapath observability metrics when datapath\_provider is ADVANCED\_DATAPATH | `bool` | `true` | no |
| enable\_advanced\_datapath\_observability\_relay | Enable advanced datapath observability relay when datapath\_provider is ADVANCED\_DATAPATH | `bool` | `false` | no |
| enable\_cilium\_clusterwide\_network\_policy | Enable Cilium clusterwide network policy for the GKE cluster | `bool` | `false` | no |
| enable\_csi\_filestore | Enable the Filestore CSI Driver | `bool` | `false` | no |
| enable\_csi\_gcs\_fuse | Enable the GCS Fuse CSI Driver | `bool` | `true` | no |
| enable\_csi\_parallelstore | Enable the Parallelstore CSI Driver | `bool` | `true` | no |
| enable\_intranode\_visibility | Enable intranode visibility for the GKE cluster | `bool` | `false` | no |
| enable\_mesh\_certificates | Enable mesh certificates for the GKE cluster | `bool` | `false` | no |
| enable\_private\_endpoint | Enable private endpoint for GKE control plane (restricts access to private networks) | `bool` | `false` | no |
| enable\_secure\_boot | Enable Secure Boot for GKE nodes | `bool` | `true` | no |
| enable\_shielded\_nodes | Enable Shielded GKE Nodes for enhanced security | `bool` | `true` | no |
| enable\_workload\_identity | Enable Workload Identity for GKE clusters | `bool` | `true` | no |
| ip\_range\_pods | The _name_ of the secondary subnet ip range to use for pods | `string` | n/a | yes |
| ip\_range\_services | The _name_ of the secondary subnet range to use for services | `string` | n/a | yes |
| maintenance\_end\_time | The end time for the maintenance window in RFC3339 format (e.g., '2024-09-18T04:00:00Z') | `string` | `"2024-09-18T04:00:00Z"` | no |
| maintenance\_recurrence | The recurrence of the maintenance window in RRULE format (e.g., 'FREQ=WEEKLY;BYDAY=SA,SU') | `string` | `"FREQ=WEEKLY;BYDAY=SA,SU"` | no |
| maintenance\_start\_time | The start time for the maintenance window in RFC3339 format (e.g., '2024-09-17T04:00:00Z') | `string` | `"2024-09-17T04:00:00Z"` | no |
| max\_nodes\_ondemand | Maximum number of on-demand nodes in the node pool | `number` | `1` | no |
| max\_nodes\_spot | Maximum number of spot nodes in the node pool | `number` | `1` | no |
| min\_master\_version | The minimum version of the master. GKE will auto-update the master to new versions, so this does not guarantee the current master version. | `string` | `"1.32.3"` | no |
| min\_nodes\_ondemand | Minimum number of on-demand nodes in the node pool | `number` | `0` | no |
| min\_nodes\_spot | Minimum number of spot nodes in the node pool | `number` | `0` | no |
| network | The vpc the cluster should be deployed to | `string` | `"default"` | no |
| node\_machine\_type\_ondemand | Machine type for on-demand node pools in GKE clusters | `string` | `"e2-standard-2"` | no |
| node\_machine\_type\_spot | Machine type for spot node pools in GKE clusters | `string` | `"e2-standard-2"` | no |
| project\_id | The GCP project where the resources will be created | `string` | n/a | yes |
| region | The region to host the cluster in | `string` | `"us-central1"` | no |
| release\_channel | GKE release channel for clusters (RAPID, REGULAR, STABLE) | `string` | `"RAPID"` | no |
| scaled\_control\_plane | Deploy a larger initial nodepool to ensure larger control plane nodes are provisied | `bool` | `false` | no |
| subnet | The subnet the cluster should be deployed to | `string` | `"default"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_config | Configuration details for the GKE cluster |
| cluster\_name | Name of the deployed GKE Standard cluster for use in kubectl commands and referencing in other resources |
| endpoint | Control plane endpoint configuration for the GKE Standard cluster including DNS endpoints and external access configuration |
| node\_pools | Node pools created for the cluster |
| region | GCP region where the GKE Standard cluster is deployed, useful for region-scoped commands and resources |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
