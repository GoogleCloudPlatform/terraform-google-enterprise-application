# Multi-Cluster Discovery Example

This example deploys multi-region GKE Autopilot clusters with Multi-Cluster Service Discovery (MCSD), Multi-Cluster Ingress (MCI), Cloud Service Mesh (ASM), and Config Sync using the Enterprise Application Blueprint modules.

> **Note:** This example is designed for demonstration and testing purposes within a single Google Cloud project. For production deployments, follow the multi-project/multi-stage blueprint architecture.

## Overview

This example provisions:

- **Network Infrastructure (`modules/cluster_network`)**:
  - A custom VPC network (`vpc-eab-cluster`)
  - Subnets across configured regions with primary IP ranges
  - Secondary IP ranges dedicated for Kubernetes Pods and Services

- **Multi-Tenant GKE Infrastructure (`modules/gke`)**:
  - Multi-region GKE Autopilot clusters
  - Cloud Armor security policy (`eab-cloud-armor`)
  - Reserved external IP addresses and SSL certificates for hosted applications

- **Fleet Scope Infrastructure (`modules/fleetscope`)**:
  - GKE Fleet registration across cluster locations
  - Fleet scopes and namespaces for tenant teams
  - Config Sync setup with Git repository synchronization
  - Managed Cloud Service Mesh (Anthos Service Mesh)
  - Multi-Cluster Ingress (MCI) configuration
  - Multi-Cluster Service Discovery (`enable_multicluster_discovery = true`) enabled across the Fleet

## Pre-requisites

### Required APIs

This example requires a Google Cloud project with the following APIs enabled:

```bash
gcloud services enable \
  accesscontextmanager.googleapis.com \
  anthos.googleapis.com \
  anthosconfigmanagement.googleapis.com \
  apikeys.googleapis.com \
  certificatemanager.googleapis.com \
  cloudbilling.googleapis.com \
  cloudresourcemanager.googleapis.com \
  cloudtrace.googleapis.com \
  compute.googleapis.com \
  container.googleapis.com \
  containeranalysis.googleapis.com \
  containerscanning.googleapis.com \
  dns.googleapis.com \
  gkehub.googleapis.com \
  iam.googleapis.com \
  iap.googleapis.com \
  mesh.googleapis.com \
  monitoring.googleapis.com \
  multiclusteringress.googleapis.com \
  multiclusterservicediscovery.googleapis.com \
  networkmanagement.googleapis.com \
  secretmanager.googleapis.com \
  servicemanagement.googleapis.com \
  servicenetworking.googleapis.com \
  serviceusage.googleapis.com \
  sqladmin.googleapis.com \
  storage-api.googleapis.com \
  trafficdirector.googleapis.com \
  --project=YOUR_PROJECT_ID
```

### Required IAM Roles

The deployment identity requires the following project-level IAM roles:

- Certificate Manager Owner: `roles/certificatemanager.owner`
- Compute Admin: `roles/compute.admin`
- Compute Network Admin: `roles/compute.networkAdmin`
- Compute Security Admin: `roles/compute.securityAdmin`
- Container Admin: `roles/container.admin`
- Cluster Admin: `roles/container.clusterAdmin`
- DNS Admin: `roles/dns.admin`
- GKE Hub Admin: `roles/gkehub.editor`
- GKE Hub Scope Admin: `roles/gkehub.scopeAdmin`
- Service Account Admin: `roles/iam.serviceAccountAdmin`
- Service Account User: `roles/iam.serviceAccountUser`
- Logging LogWriter: `roles/logging.logWriter`
- Project IAM Admin: `roles/resourcemanager.projectIamAdmin`
- Service Usage Admin: `roles/serviceusage.serviceUsageAdmin`
- Storage Admin: `roles/storage.admin`

If deploying within an enforced VPC Service Controls perimeter, additional access context manager permissions are required:
- Organization Administrator: `roles/resourcemanager.organizationAdmin`
- Access Context Manager Policy Admin: `roles/accesscontextmanager.policyAdmin`

## Usage

1. Navigate to the example directory:

   ```bash
   cd terraform-google-enterprise-application/examples/cluster-multicluster-discovery
   ```

2. Create a `terraform.tfvars` file with the required variables:

   ```hcl
   project_id          = "YOUR_PROJECT_ID"
   regions             = ["us-central1", "us-east4"]
   attestation_kms_key = "projects/YOUR_PROJECT_ID/locations/global/keyRings/YOUR_RING/cryptoKeys/YOUR_KEY"
   teams = {
     "frontend" = "frontend-team@example.com"
     "backend"  = "backend-team@example.com"
   }
   ```

3. Initialize Terraform:

   ```bash
   terraform init
   ```

4. Review the execution plan:

   ```bash
   terraform plan
   ```

5. Apply the infrastructure:

   ```bash
   terraform apply
   ```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_level\_name | (VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter. | `string` | `null` | no |
| attestation\_kms\_key | The KMS Key ID to be used by attestor. | `string` | n/a | yes |
| base\_cidr | Base CIDR for the VPC primary ranges | `string` | `"10.1.0.0/16"` | no |
| pods\_base\_cidr | Base CIDR for Kubernetes Pods secondary ranges | `string` | `"10.2.0.0/16"` | no |
| project\_id | Google Cloud project ID in which to deploy all example resources | `string` | n/a | yes |
| regions | Google Cloud regions for cluster | `list(string)` | n/a | yes |
| service\_perimeter\_mode | (VPC-SC) Service perimeter mode: ENFORCE, DRY\_RUN. | `string` | `"ENFORCE"` | no |
| service\_perimeter\_name | (VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter. | `string` | `null` | no |
| services\_base\_cidr | Base CIDR for Kubernetes Services secondary ranges | `string` | `"10.3.0.0/16"` | no |
| teams | A map of string at the format {"namespace" = "groupEmail"} | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| app\_certificates | App Certificates |
| app\_ip\_addresses | App IP Addresses |
| cluster\_membership\_ids | GKE cluster membership IDs |
| cluster\_project\_id | Cluster Project ID |
| cluster\_project\_number | Cluster Project ID |
| cluster\_regions | Regions with clusters |
| cluster\_service\_accounts | The default service accounts used for nodes, if not overridden in node\_pools. |
| cluster\_type | Cluster type |
| env | Environment |
| fleet\_project\_id | Fleet Project ID |
| network\_project\_id | Network Project ID |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
