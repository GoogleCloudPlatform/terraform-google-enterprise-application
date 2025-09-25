# Deploying GKE, Artifact Registry & Parallelstore

This Terraform example demonstrates how to deploy a core infrastructure setup including a Google Kubernetes Engine (GKE) cluster, Artifact Registry, and Parallelstore instance. It provides a foundation for running risk and research workloads on Google Cloud.

## Features

* **GKE Cluster**: Deploy a Google Kubernetes Engine cluster with options for Standard or Autopilot mode
* **Artifact Registry**: Set up a repository for storing container images
* **Parallelstore**: Configure high-performance file storage for computational workloads
* **Network Setup**: Create a properly configured VPC network with necessary firewall rules
* **IAM Configuration**: Set up appropriate service accounts and permissions

## Prerequisites

* **Google Cloud Project:** A Google Cloud project with billing enabled
* **Terraform:** Terraform CLI (version 1.0+) installed and configured
* **Google Cloud SDK:** gcloud CLI configured with appropriate permissions
* **Required IAM Permissions:** User deploying must have sufficient permissions (typically Owner or Editor role)


## Deployment Instructions

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/GoogleCloudPlatform/risk-and-research-blueprints.git
   cd risk-and-research-blueprints/examples/infrastructure
   ```

2. **Configure Variables:**
   * Create a `terraform.tfvars` file with your configuration:
     ```hcl
     project_id = "your-project-id"
     regions    = ["us-central1"]  # Specify your preferred region

     # Optional configurations
     quota_contact_email = "your-email@example.com"  # For quota requests
     ```

3. **Deploy with Terraform:**

   * Authorize gcloud and set up application default credentials:
     ```bash
     gcloud auth login --activate --no-launch-browser --quiet --update-adc
     ```

   * Initialize, plan, and apply the Terraform configuration:
     ```bash
     terraform init
     terraform plan -var-file="terraform.tfvars" -out=tfplan
     terraform apply tfplan
     ```

4. **Access the GKE Cluster:**
   ```bash
   gcloud container clusters get-credentials gke-risk-research-[REGION]-0 --region [REGION]
   kubectl get nodes  # Verify connectivity
   ```

5. **Clean Up Resources:**
   When you're done with the environment, destroy the resources:
   ```bash
   terraform destroy -var-file="terraform.tfvars"
   ```

## What's Deployed

* GKE cluster configured for high-performance computing workloads
* Artifact Registry repository for container images
* Parallelstore file storage instance (if enabled)
* VPC network with appropriate subnets and firewall rules
* Service accounts with least-privilege permissions

## Advanced Configuration

For more advanced scenarios, you can modify the Terraform variables to:

* Deploy to multiple regions
* Enable/disable specific components
* Adjust performance settings for GKE and Parallelstore
* Configure custom networking options

See the `variables.tf` file for all available configuration options.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| additional\_service\_account\_roles | Additional IAM roles to assign to the cluster service account | `list(string)` | `[]` | no |
| artifact\_registry\_cleanup\_policy\_keep\_count | Number of most recent container image versions to keep in Artifact Registry | `number` | `10` | no |
| artifact\_registry\_name | Name of the Artifact Registry repository to create | `string` | `"research-images"` | no |
| cluster\_max\_cpus | Maximum CPU cores in cluster autoscaling resource limits | `number` | `100` | no |
| cluster\_max\_memory | Maximum memory (in GB) in cluster autoscaling resource limits | `number` | `1024` | no |
| cluster\_service\_account | Service Account ID to use for GKE clusters | `string` | `"gke-risk-research-cluster-sa"` | no |
| clusters\_per\_region | Map of regions to number of clusters to create in each (maximum 4 per region) | `map(number)` | <pre>{<br>  "us-central1": 1<br>}</pre> | no |
| create\_ondemand\_nodepool | Whether to create the on-demand node pool | `bool` | `true` | no |
| create\_spot\_nodepool | Whether to create the spot node pool | `bool` | `true` | no |
| datapath\_provider | The datapath provider for the GKE cluster (DATAPATH\_PROVIDER\_UNSPECIFIED, LEGACY\_DATAPATH, or ADVANCED\_DATAPATH) | `string` | `"LEGACY_DATAPATH"` | no |
| enable\_csi\_filestore | Enable the Filestore CSI Driver | `bool` | `false` | no |
| enable\_csi\_gcs\_fuse | Enable the GCS Fuse CSI Driver | `bool` | `true` | no |
| enable\_csi\_parallelstore | Enable the Parallelstore CSI Driver | `bool` | `true` | no |
| enable\_log\_analytics | Enable log analytics with BigQuery linking | `bool` | `true` | no |
| enable\_mesh\_certificates | Enable mesh certificates for the GKE cluster | `bool` | `false` | no |
| enable\_private\_endpoints | Enable private endpoints for GKE clusters (restricts access to private networks) | `bool` | `false` | no |
| enable\_secure\_boot | Enable Secure Boot for GKE nodes | `bool` | `true` | no |
| enable\_shielded\_nodes | Enable Shielded GKE Nodes for enhanced security | `bool` | `true` | no |
| enable\_workload\_identity | Enable Workload Identity for GKE clusters | `bool` | `true` | no |
| gke\_standard\_cluster\_name | Base name for GKE clusters (will be suffixed with region and index) | `string` | `"gke-risk-research"` | no |
| lustre\_filesystem | The name of the Lustre filesystem | `string` | `"lustre-fs"` | no |
| lustre\_gke\_support\_enabled | Enable GKE support for Lustre instance | `bool` | `true` | no |
| maintenance\_end\_time | The end time for the maintenance window in RFC3339 format (e.g., '2024-09-18T04:00:00Z') | `string` | `"2024-09-18T04:00:00Z"` | no |
| maintenance\_recurrence | The recurrence of the maintenance window in RRULE format (e.g., 'FREQ=WEEKLY;BYDAY=SA,SU') | `string` | `"FREQ=WEEKLY;BYDAY=SA,SU"` | no |
| maintenance\_start\_time | The start time for the maintenance window in RFC3339 format (e.g., '2024-09-17T04:00:00Z') | `string` | `"2024-09-17T04:00:00Z"` | no |
| max\_nodes\_ondemand | Maximum number of on-demand nodes in the node pool | `number` | `1` | no |
| max\_nodes\_spot | Maximum number of spot nodes in the node pool | `number` | `1` | no |
| min\_nodes\_ondemand | Minimum number of on-demand nodes in the node pool | `number` | `0` | no |
| min\_nodes\_spot | Minimum number of spot nodes in the node pool | `number` | `0` | no |
| node\_machine\_type\_ondemand | Machine type for on-demand node pools in GKE clusters | `string` | `"e2-standard-2"` | no |
| node\_machine\_type\_spot | Machine type for spot node pools in GKE clusters | `string` | `"e2-standard-2"` | no |
| parallelstore\_deployment\_type | Parallelstore Instance deployment type (SCRATCH or PERSISTENT) | `string` | `"SCRATCH"` | no |
| project\_id | The GCP project ID where resources will be created. | `string` | `"YOUR_PROJECT_ID"` | no |
| regions | List of regions where GKE clusters should be created. Used for multi-region deployments. | `list(string)` | <pre>[<br>  "us-central1"<br>]</pre> | no |
| release\_channel | GKE release channel for clusters (RAPID, REGULAR, STABLE) | `string` | `"RAPID"` | no |
| scaled\_control\_plane | Deploy a larger initial nodepool to ensure larger control plane nodes are provisioned | `bool` | `false` | no |
| storage\_capacity\_gib | Capacity in GiB for the selected storage system (Parallelstore or Lustre). | `number` | `null` | no |
| storage\_ip\_range | IP range for Storage peering, in CIDR notation | `string` | `"172.16.0.0/16"` | no |
| storage\_locations | Map of region to location (zone) for storage instances e.g. {"us-central1" = "us-central1-a"}. If not specified, the first zone in each region will be used. | `map(string)` | `{}` | no |
| storage\_type | The type of storage system to deploy. Set to PARALLELSTORE or LUSTRE to enable storage creation. If null (default), no storage system will be deployed by these module blocks. | `string` | `null` | no |
| vpc\_mtu | Maximum Transmission Unit (MTU) for the VPC network. 8896 recommended for Parallelstore and Lustre for 10% performance gain. | `number` | `8896` | no |
| vpc\_name | Name of the VPC network to create | `string` | `"research-vpc"` | no |

## Outputs

| Name | Description |
|------|-------------|
| artifact\_registry | Details of the Artifact Registry repository for storing container images |
| artifact\_registry\_docker\_command | Command to configure Docker to push to this Artifact Registry repository |
| artifact\_registry\_push\_command | Example command to tag and push a Docker image to this Artifact Registry repository |
| cluster\_service\_account | Service account details used by GKE clusters for workload identity and resource access |
| diagnostics | Diagnostic information to help troubleshoot deployment issues |
| gke\_cluster\_count | Total number of GKE clusters deployed across all regions |
| gke\_clusters | List of GKE cluster details including names, regions, and endpoints for connecting via kubectl |
| gke\_clusters\_by\_region | Map of regions to GKE clusters deployed in each |
| gke\_credentials\_command | gcloud commands to fetch credentials for each GKE cluster |
| helper\_commands | Useful commands for working with the deployed infrastructure |
| lustre\_count | Total number of Lustre instances deployed |
| lustre\_instances | Map of Lustre instances per region with connection details and specifications |
| lustre\_mount\_points | Map of regions to Lustre mount points for client configuration |
| parallelstore\_access\_points | Map of regions to Parallelstore access points for client configuration |
| parallelstore\_count | Total number of Parallelstore instances deployed |
| parallelstore\_instances | Map of Parallelstore instances per region with connection details and specifications |
| peering\_config | VPC Network Peering configuration for service networking (used by high-performance storage) |
| project\_info | Information about the Google Cloud project where resources are deployed |
| subnets | Map of networking resources per region including subnets and IP ranges for Kubernetes |
| terraform\_configuration | Summary of main Terraform configuration parameters used for this deployment |
| vpc | Details of the VPC network resources created for the deployment |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
