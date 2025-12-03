# Multitenant Infrastructure: environment baseline module

This module defines the per-environment multitenant resources deployed via the multitenant infrastructure pipeline.

The following resources are created:
- GCP Project (cluster project)
- GKE cluster(s)
- Cloud SQL PostgreSQL (accounts-db, ledger-db)
- Cloud Endpoint
- Cloud Armor
- IP addresses (frontend-ip)

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_level\_name | (VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter. | `string` | `null` | no |
| apps | A map, where the key is the application name, defining the application configurations with the following properties:<br>- **acronym** (Required): A short identifier for the application with a maximum of 3 characters in length.<br>- **ip\_address\_names** (Optional): A list of IP address names associated with the application.<br>- **certificates** (Optional): A map of certificate names to a list of certificate values required by the application. | <pre>map(object({<br>    acronym          = string<br>    ip_address_names = optional(list(string))<br>    certificates     = optional(map(list(string)))<br>  }))</pre> | n/a | yes |
| billing\_account | The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ | `string` | n/a | yes |
| cb\_private\_workerpool\_project\_id | Private Worker Pool Project ID used for Cloud Build Triggers. It is going to create an Egress rule from Cluster project to Workerpool project in case you are deploying the solution inside of a VPC-SC. | `string` | `""` | no |
| cluster\_release\_channel | The release channel for the clusters | `string` | `"REGULAR"` | no |
| cluster\_subnetworks | The subnetwork self\_links for clusters. Adding more subnetworks will increase the number of clusters. You will need a IP block defined on `master_ipv4_cidr_blocks` variable for each cluster subnetwork. | `list(string)` | n/a | yes |
| cluster\_type | GKE multi-tenant cluster types: STANDARD, STANDARD-NAP (Standard with node auto-provisioning), AUTOPILOT | `string` | `"STANDARD-NAP"` | no |
| create\_cluster\_project | Create Cluster Project ID, otherwise the Network Project ID is used | `bool` | `true` | no |
| deletion\_protection | Whether or not to allow Terraform to destroy the cluster. | `bool` | `true` | no |
| enable\_confidential\_nodes | An optional flag to enable confidential node config. | `bool` | `false` | no |
| env | The environment to prepare (ex. development) | `string` | n/a | yes |
| folder\_id | Folder ID | `string` | n/a | yes |
| master\_ipv4\_cidr\_blocks | List of IP ranges (One range per cluster) in CIDR notation to use for the hosted master network. This range will be used for assigning private IP addresses to the cluster master(s) and the ILB VIP. This range must not overlap with any other ranges in use within the cluster's network, and it must be a /28 subnet. | `list(string)` | <pre>[<br>  "10.11.10.0/28",<br>  "10.11.20.0/28"<br>]</pre> | no |
| network\_project\_id | Network Project ID | `string` | n/a | yes |
| org\_id | Organization ID | `string` | n/a | yes |
| service\_perimeter\_mode | (VPC-SC) Service perimeter mode: ENFORCE, DRY\_RUN. | `string` | `null` | no |
| service\_perimeter\_name | (VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| app\_certificates | App Certificates. |
| app\_ip\_addresses | App IP Addresses. |
| cloud\_armor | Cloud Armor configuration. |
| cluster\_membership\_ids | GKE cluster membership IDs. |
| cluster\_names | GKE cluster names. |
| cluster\_project\_id | Cluster Project ID. |
| cluster\_project\_number | Cluster Project Number. |
| cluster\_regions | Regions with clusters. |
| cluster\_service\_accounts | The default service accounts used for nodes, if not overridden in node\_pools. |
| cluster\_type | Cluster type. |
| cluster\_zones | GKE cluster zones. |
| fleet\_project\_id | Fleet Project ID. |
| network\_names | Network name. |
| network\_project\_id | Network Project ID. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
