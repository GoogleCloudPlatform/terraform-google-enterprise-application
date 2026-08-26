# Standalone Harness Module

This module provisions the foundational harness infrastructure for single-project / standalone deployments in the Enterprise Application Blueprint.

It provisions:
* Essential Google Cloud APIs
* A private Cloud Build Worker Pool (optional if `workerpool_id` is passed)
* Binary Authorization attestor image build
* Cluster VPC Network and subnets with secondary ranges

## Usage

```hcl
module "standalone_harness" {
  source = "../../modules/standalone-harness"

  project_id          = var.project_id
  region              = var.region
  workerpool_id       = var.workerpool_id
  network_id          = var.network_id
  create_nat          = var.create_nat
  additional_services = ["modelarmor.googleapis.com"]
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| additional\_services | Additional GCP services to enable in the project. | `list(string)` | `[]` | no |
| attestation\_repository\_name | The Artifact repository name to store the BinAuthz image. | `string` | n/a | yes |
| billing\_account | Billing to be used by a new project. (Required if `create_project` is `true`). | `string` | `null` | no |
| build\_image\_module\_dependencies | A list of dependencies to wait for before running the gcloud script | `list(any)` | `[]` | no |
| create\_nat | Enables Cloud NAT creation for Private Worker Pool. | `bool` | `true` | no |
| create\_project | Enables creation of a new project to deploy all harness resources. | `bool` | `true` | no |
| enable\_proxy\_subnet | Enables proxy subnet | `bool` | `false` | no |
| enables\_network\_connection\_and\_peering\_routes | Enables Network connection and peering routes. | `bool` | `true` | no |
| folder\_id | The folder to deploy create the new project | `string` | `null` | no |
| logging\_bucket | Bucket to store logging. | `string` | `null` | no |
| network\_id | The network ID where the private worker pool is going to be peered. | `string` | `null` | no |
| org\_id | The numeric organization id | `string` | `null` | no |
| private\_service\_connect\_ip | Private service IP | `string` | `"10.3.0.5"` | no |
| private\_workerpool\_name | The private workerpool name | `string` | n/a | yes |
| project\_id | An already Google Cloud project ID in which to deploy all harness resources. | `string` | `null` | no |
| project\_name | A project name to be used. | `string` | `null` | no |
| region | Google Cloud region for deployments. | `string` | `"us-central1"` | no |
| secondary\_ip\_cidr\_range\_01 | Secondary CIDR range 1 for pods/services. | `string` | `"192.168.0.0/18"` | no |
| secondary\_ip\_cidr\_range\_02 | Secondary CIDR range 2 for pods/services. | `string` | `"192.168.64.0/18"` | no |
| service\_perimeter\_mode | (VPC-SC) Service perimeter mode: ENFORCE, DRY\_RUN. | `string` | `"ENFORCE"` | no |
| service\_perimeter\_name | (VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter. | `string` | `null` | no |
| subnet\_ip | Primary subnet CIDR block. | `string` | `"10.1.20.0/24"` | no |
| vpc\_name | Name of the VPC to create. | `string` | `"eab-cluster"` | no |
| worker\_range\_ip | The global IP do be reserved for peering. | `string` | `"10.3.0.0"` | no |
| workerpool\_id | Specifies the Cloud Build Worker Pool that will be utilized for triggers. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| binary\_authorization\_image | Binary Authorization attestor image. |
| binary\_authorization\_repository\_id | Binary Authorization repository ID. |
| project\_id | The Project ID to be created the resources. |
| required\_services | The required Google project service resources. |
| subnets | Self links of the created subnets. |
| subnets\_self\_links | Self links of the created subnets. |
| workerpool\_id | The Cloud Build Worker Pool ID. |
| workerpool\_network\_project\_id | The network project ID for the workerpool. |
| workerpool\_project\_id | The Cloud Build Worker Pool Project ID. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
