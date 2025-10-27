# Standalone Single-Project Confidential Nodes Example
The Standalone Single Project Confidential Nodes Example deploys the core Enterprise Application Blueprint into a single project for the purposes of simplified demonstration. This examples uses the same infrastructure from Standalone Single Project Example, the main difference is the Confidential Nodes being enabled in the cluster.

**Do not use this example for production deployments, as it lacks robust separation of duties and least-privileged permissions present in the standard multi-stage deployment.**

This example creates:

- 2-multitenant
    - GKE cluster(s)
    - Cloud Armor
    - App IP addresses (see below for details)

## Pre-requisites

This examples requires one project already created with the following APIs enabled:

- accesscontextmanager.googleapis.com
- anthos.googleapis.com
- anthosconfigmanagement.googleapis.com
- apikeys.googleapis.com
- certificatemanager.googleapis.com
- cloudbilling.googleapis.com
- cloudbuild.googleapis.com
- clouddeploy.googleapis.com
- cloudfunctions.googleapis.com
- cloudresourcemanager.googleapis.com
- cloudtrace.googleapis.com
- compute.googleapis.com
- container.googleapis.com
- gkehub.googleapis.com
- iam.googleapis.com
- iap.googleapis.com
- mesh.googleapis.com
- monitoring.googleapis.com
- multiclusteringress.googleapis.com
- multiclusterservicediscovery.googleapis.com
- networkmanagement.googleapis.com
- secretmanager.googleapis.com
- servicemanagement.googleapis.com
- servicenetworking.googleapis.com
- serviceusage.googleapis.com
- sqladmin.googleapis.com
- storage-api.googleapis.com
- trafficdirector.googleapis.com

The entity used to deploy this examples must have the following roles at Project level:

- Artifact Registry Admin: `roles/artifactregistry.admin`
- Certificate Manager Owner: `roles/certificatemanager.owner`
- Cloud Build Builder: `roles/cloudbuild.builds.builder`
- Cloud Build Worker Pool Owner: `roles/cloudbuild.workerPoolOwner`
- Cloud Deploy Service Agent: `roles/clouddeploy.serviceAgent`
- Cloud Deploy Admin: `roles/clouddeploy.admin`
- Compute Admin: `roles/compute.admin`
- Network Admin: `roles/compute.networkAdmin `
- Security Admin: `roles/compute.securityAdmin`
- Container Admin: `roles/container.admin  `
- Cluster Admin: `roles/container.clusterAdmin`
- DNS Admin: `roles/dns.admin`
- GKE Hub Admin: `roles/gkehub.editor`
- GKE Hub Scope Admin: `roles/gkehub.scopeAdmin`
- Service Account Admin: `roles/iam.serviceAccountAdmin`
- Service Account User: `roles/iam.serviceAccountUser`
- Logging LogWriter: `roles/logging.logWriter`
- Project IAM Admin: `roles/resourcemanager.projectIamAdmin`
- Service Usage Admin: `roles/serviceusage.serviceUsageAdmin`
- Source Repository Admin: `roles/source.admin` (if using CSR)
- Storage Admin: `roles/storage.admin`
- Project AdminL `roles/resourcemanager.projectIamAdmin`
- Viewer: `roles/viewer`

The entity used to deploy this examples must have the following roles at Organization level:

- Organization Administrator: `roles/resourcemanager.organizationAdmin`
- Access Context Manager Policy Admin: `roles/accesscontextmanager.policyAdmin`

This example requires a Single network configured:

- One subnet for Cluster
- One subnet for a NAT
- DNS Policy With inbound fowarding enabled
- A [VM Proxy machine configured for Private Worker Pool](https://cloud.google.com/build/docs/private-pools/access-external-resources-using-static-external-ip#access_external_resources_in_a_private_network)
- [Private Service Connect Configured](https://cloud.google.com/build/docs/private-pools/using-vpc-service-controls)

This examples also require a VPC-SC Perimeter created and [configured with project](https://cloud.google.com/vpc-service-controls/docs/set-up-service-perimeter).

## Usage

the steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` directory:

```txt
.
├── terraform-google-enterprise-application
└── .
```

1. Enter at Single Project example folder:

    ```bash
    cd terraform-google-enterprise-application/examples/standalone_single_project_confidential_nodes
    ```

1. Update `terraform.tfvars`.

1. Run `terraform plan` and check the information

1. Run `terraform apply`.


<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_level\_name | (VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter. | `string` | `null` | no |
| attestation\_kms\_key | The KMS Key ID to be used by attestor. | `string` | n/a | yes |
| binary\_authorization\_image | The Binary Authorization image to be used to create attestation. | `string` | n/a | yes |
| binary\_authorization\_repository\_id | The Binary Authorization artifact registry where the image to be used to create attestation is stored with format `projects/{{project}}/locations/{{location}}/repositories/{{repository_id}}`. | `string` | n/a | yes |
| bucket\_kms\_key | KMS Key id to be used to encrypt bucket. | `string` | `null` | no |
| logging\_bucket | Bucket to store logging. | `string` | `null` | no |
| project\_id | Google Cloud project ID in which to deploy all example resources | `string` | n/a | yes |
| region | Google Cloud region for deployments | `string` | `"us-central1"` | no |
| service\_perimeter\_mode | (VPC-SC) Service perimeter mode: ENFORCE, DRY\_RUN. | `string` | `"ENFORCE"` | no |
| service\_perimeter\_name | (VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter. | `string` | `null` | no |
| subnetwork\_self\_link | Sub-Network self-link | `string` | n/a | yes |
| teams | A map of string at the format {"namespace" = "groupEmail"} | `map(string)` | n/a | yes |
| workerpool\_id | Specifies the Cloud Build Worker Pool that will be utilized for triggers created in this step.<br><br>The expected format is:<br>`projects/PROJECT/locations/LOCATION/workerPools/POOL_NAME`.<br><br>If you are using worker pools from a different project, ensure that you grant the<br>`roles/cloudbuild.workerPoolUser` role on the workerpool project to the Cloud Build Service Agent and the Cloud Build Service Account of the trigger project:<br>`service-PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com`, `PROJECT_NUMBER@cloudbuild.gserviceaccount.com` | `string` | `null` | no |
| workerpool\_network\_id | Network id | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| acronyms | App Acronyms |
| app\_certificates | App Certificates |
| app\_infos | App infos (name, services, team). |
| app\_ip\_addresses | App IP Addresses |
| clouddeploy\_targets\_names | Cloud deploy targets names. |
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
