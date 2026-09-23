# Cymbal Bank Standalone Single-Project Example
The Standalone Single Project Example deploys the core Enterprise Application Blueprint with the 6 Cymbal Bank microservices into a single project for simplified demonstration and testing.

**Do not use this example for production deployments, as it lacks robust separation of duties and least-privileged permissions present in the standard multi-stage deployment.**

This example creates:

- 1-harness
    - Enable required Google Cloud APIs
    - Cluster network & subnets
    - Private Cloud Build Worker Pool (Network + Cloud NAT)
    - Binary Authorization attestor build image & artifact registry
- 2-gke
    - GKE cluster(s) (Autopilot or Standard)
    - Cloud Armor security policy
    - Application external IP addresses & SSL certificates
- 3-fleetscope
    - GKE Fleet memberships & features (Config Sync, Service Mesh)
    - Team Fleet namespaces (`frontend`, `accounts`, `ledger`)
    - Binary Authorization Attestor & Cloud KMS CryptoKey
- 5-secure-pipeline
    - Cloud Build v2 Triggers for all 6 Cymbal Bank microservices
    - Cloud Deploy Delivery Pipelines & Targets
    - IAM permissions with 30s propagation barrier
    - Storage buckets for release artifacts and build logs

## Pre-requisites

This example requires a single project already created. The following APIs will be enabled automatically by `1-harness`:

- `accesscontextmanager.googleapis.com`
- `anthos.googleapis.com`
- `anthosconfigmanagement.googleapis.com`
- `apikeys.googleapis.com`
- `artifactregistry.googleapis.com`
- `binaryauthorization.googleapis.com`
- `certificatemanager.googleapis.com`
- `cloudbilling.googleapis.com`
- `cloudbuild.googleapis.com`
- `clouddeploy.googleapis.com`
- `cloudfunctions.googleapis.com`
- `cloudresourcemanager.googleapis.com`
- `cloudtrace.googleapis.com`
- `compute.googleapis.com`
- `container.googleapis.com`
- `gkehub.googleapis.com`
- `iam.googleapis.com`
- `iap.googleapis.com`
- `mesh.googleapis.com`
- `monitoring.googleapis.com`
- `multiclusteringress.googleapis.com`
- `multiclusterservicediscovery.googleapis.com`
- `networkmanagement.googleapis.com`
- `secretmanager.googleapis.com`
- `servicemanagement.googleapis.com`
- `servicenetworking.googleapis.com`
- `serviceusage.googleapis.com`
- `sqladmin.googleapis.com`
- `storage-api.googleapis.com`
- `trafficdirector.googleapis.com`

If you are using a service account to deploy this example, you must enable at least the `cloudresourcemanager.googleapis.com` API beforehand:

```bash
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  --project=YOUR_PROJECT_ID
```

### IAM Roles Required

The deploying identity must have the following roles at Project level:

- Artifact Registry Admin: `roles/artifactregistry.admin`
- Certificate Manager Owner: `roles/certificatemanager.owner`
- Cloud Build Builder: `roles/cloudbuild.builds.builder`
- Cloud Build Worker Pool Owner: `roles/cloudbuild.workerPoolOwner`
- Cloud Deploy Service Agent: `roles/clouddeploy.serviceAgent`
- Cloud Deploy Admin: `roles/clouddeploy.admin`
- Compute Admin: `roles/compute.admin`
- Network Admin: `roles/compute.networkAdmin`
- Security Admin: `roles/compute.securityAdmin`
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
- Source Repository Admin: `roles/source.admin` (if using CSR)
- Storage Admin: `roles/storage.admin`
- Secret Manager Editor: `roles/secretmanager.editor`
- Viewer: `roles/viewer`

At Organization level (if using VPC Service Controls):

- Organization Administrator: `roles/resourcemanager.organizationAdmin`
- Access Context Manager Policy Admin: `roles/accesscontextmanager.policyAdmin`

### KMS Keys

- **Bucket KMS Key:** Used to encrypt Cloud Storage buckets (build logs, release artifacts).
- **Attestation KMS Key:** Used by the Binary Authorization attestor to sign build artifacts.

### VPC Service Controls (VPC-SC)

This module supports deployment within a VPC-SC perimeter (`DRY_RUN` or `ENFORCE`). To enable VPC-SC integration, provide:
- `service_perimeter_name`: Full name of the Access Context Manager Service Perimeter.
- `service_perimeter_mode`: `DRY_RUN` or `ENFORCE`.
- `access_level_name`: Full name of the Access Level to which deploying identities are added.

### Network Connectivity Center (NCC) Connection (Optional)

This module supports connecting the standalone cluster VPC network as a spoke to an existing NCC Hub:

```hcl
ncc_config = {
  enable_ncc        = true
  hub_uri           = "projects/YOUR_HUB_PROJECT_ID/locations/global/hubs/YOUR_HUB_NAME"
  spoke_group       = "edge"
  spoke_name        = "vpc-spoke-cymbal-bank"
  spoke_description = "NCC Spoke for Cymbal Bank standalone cluster network"
}
```

### Git Providers & Cloud Build v2 Configuration

Configure `cloudbuildv2_repository_config` in `terraform.tfvars` for your repository provider:

#### 1. Cloud Source Repositories (CSR)
```hcl
cloudbuildv2_repository_config = {
  repo_type = "CSR"
  repositories = {
    "eab-cymbal-bank-frontend" = {
      repository_name = "eab-cymbal-bank-frontend"
      repository_url  = ""
    }
    "eab-cymbal-bank-accounts-contacts" = {
      repository_name = "eab-cymbal-bank-accounts-contacts"
      repository_url  = ""
    }
    "eab-cymbal-bank-accounts-userservice" = {
      repository_name = "eab-cymbal-bank-accounts-userservice"
      repository_url  = ""
    }
    "eab-cymbal-bank-ledger-balancereader" = {
      repository_name = "eab-cymbal-bank-ledger-balancereader"
      repository_url  = ""
    }
    "eab-cymbal-bank-ledger-ledgerwriter" = {
      repository_name = "eab-cymbal-bank-ledger-ledgerwriter"
      repository_url  = ""
    }
    "eab-cymbal-bank-ledger-transactionhistory" = {
      repository_name = "eab-cymbal-bank-ledger-transactionhistory"
      repository_url  = ""
    }
  }
}
```

#### 2. GitLab / GitHub
Refer to the secret configuration parameters (`gitlab_authorizer_credential_secret_id`, `gitlab_read_authorizer_credential_secret_id`, `gitlab_webhook_secret_id`, or `github_secret_id`, `github_app_id_secret_id`).

## Usage

1. Change directory to the Cymbal Bank standalone single project folder:

    ```bash
    cd terraform-google-enterprise-application/examples/cymbal-bank/standalone-single-project
    ```

2. Update `terraform.tfvars`.

3. Initialize and apply Terraform:

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_level\_name | (VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter. | `string` | `null` | no |
| attestation\_kms\_key | The KMS Key ID to be used by attestor. | `string` | n/a | yes |
| bucket\_kms\_key | KMS Key id to be used to encrypt bucket. | `string` | `null` | no |
| cloudbuildv2\_repository\_config | Configuration for integrating repositories with Cloud Build v2:<br>  - repo\_type: Specifies the type of repository. Supported types are 'GITHUBv2', 'GITLABv2', and 'CSR'.<br>  - repositories: A map of repositories to be created. The key must match the exact name of the repository. Each repository is defined by:<br>      - repository\_name: The name of the repository.<br>      - repository\_url: The URL of the repository.<br>  - github\_secret\_id: (Optional) The personal access token for GitHub authentication.<br>  - github\_app\_id\_secret\_id: (Optional) The application ID for a GitHub App used for authentication.<br>  - gitlab\_read\_authorizer\_credential\_secret\_id: (Optional) The read authorizer credential for GitLab access.<br>  - gitlab\_authorizer\_credential\_secret\_id: (Optional) The authorizer credential for GitLab access.<br>  - gitlab\_webhook\_secret\_id: (Optional) The secret ID for the GitLab WebHook.<br>  - gitlab\_enterprise\_host\_uri: (Optional) The URI of the GitLab Enterprise host this connection is for. If not specified, the default value is https://gitlab.com.<br>  - gitlab\_enterprise\_service\_directory: (Optional) Configuration for using Service Directory to privately connect to a GitLab Enterprise server. This should only be set if the GitLab Enterprise server is hosted on-premises and not reachable by public internet. If this field is left empty, calls to the GitLab Enterprise server will be made over the public internet. Format: projects/{project}/locations/{location}/namespaces/{namespace}/services/{service}.<br>  - gitlab\_enterprise\_ca\_certificate: (Optional) SSL certificate to use for requests to GitLab Enterprise.<br>  - secret\_project\_id: (Optional) The project id where the secret is stored.<br>Note: When using GITLABv2, specify `gitlab_read_authorizer_credential` and `gitlab_authorizer_credential` and `gitlab_webhook_secret_id`.<br>Note: When using GITHUBv2, specify `github_pat` and `github_app_id`.<br>Note: If 'cloudbuildv2\_repository\_config' variable is not configured, CSR (Cloud Source Repositories) will be used by default. | <pre>object({<br>    repo_type = string # Supported values are: GITHUBv2, GITLABv2 and CSR<br>    # repositories to be created<br>    repositories = map(<br>      object({<br>        repository_name = string<br>        repository_url  = string<br>      })<br>    )<br>    # Credential Config for each repository type<br>    github_secret_id                            = optional(string)<br>    github_app_id_secret_id                     = optional(string)<br>    gitlab_read_authorizer_credential_secret_id = optional(string)<br>    gitlab_authorizer_credential_secret_id      = optional(string)<br>    gitlab_webhook_secret_id                    = optional(string)<br>    gitlab_enterprise_host_uri                  = optional(string)<br>    gitlab_enterprise_service_directory         = optional(string)<br>    gitlab_enterprise_ca_certificate            = optional(string)<br>    secret_project_id                           = optional(string)<br>  })</pre> | n/a | yes |
| create\_nat | Enables Cloud NAT creation for Private Worker Pool, disable if your network already has one created. | `bool` | `true` | no |
| enables\_network\_connection\_and\_peering\_routes | Enables Network connection and peering routes. | `bool` | `true` | no |
| logging\_bucket | Bucket to store logging. | `string` | `null` | no |
| ncc\_config | Configuration block for Google Cloud Network Connectivity Center (NCC) Spokes.<br>- enable\_ncc: (bool) Toggles whether to create a new NCC spoke.<br>- hub\_uri: (string) The URI of an existing Hub. [Required if enable\_ncc is TRUE]<br>- spoke\_group: (string) The NCC group the spoke belongs to (default: "default").<br>- spoke\_name: (string) Name for the main VPC spoke.<br>- spoke\_description: (string) Description for the main VPC spoke.<br>- spoke\_labels: (map) Labels for the main VPC spoke.<br>- spoke\_exclude\_export\_ranges: (set of strings) IP ranges to exclude from route export.<br>- spoke\_include\_export\_ranges: (set of strings) IP ranges to explicitly include in route export. | <pre>object({<br>    enable_ncc                  = optional(bool, false)<br>    hub_uri                     = optional(string)<br>    spoke_group                 = optional(string, "default")<br>    spoke_name                  = optional(string, "vpc-spoke")<br>    spoke_description           = optional(string)<br>    spoke_labels                = optional(map(string))<br>    spoke_exclude_export_ranges = optional(set(string), [])<br>    spoke_include_export_ranges = optional(set(string), [])<br>  })</pre> | `{}` | no |
| network\_id | The network ID where the private worker pool is going to be peered. If not provided, a new network is going to be created. | `string` | `null` | no |
| project\_id | Google Cloud project ID in which to deploy all example resources | `string` | n/a | yes |
| region | Google Cloud region for deployments | `string` | `"us-central1"` | no |
| service\_perimeter\_mode | (VPC-SC) Service perimeter mode: ENFORCE, DRY\_RUN. | `string` | `"ENFORCE"` | no |
| service\_perimeter\_name | (VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter. | `string` | `null` | no |
| teams | A map of string at the format {"namespace" = "groupEmail"} | `map(string)` | <pre>{<br>  "cb-accounts": "accounts-team@example.com",<br>  "cb-frontend": "frontend-team@example.com",<br>  "cb-ledger": "ledger-team@example.com"<br>}</pre> | no |
| workerpool\_id | Specifies the Cloud Build Worker Pool that will be utilized for triggers created in this step.<br><br>The expected format is:<br>`projects/PROJECT/locations/LOCATION/workerPools/POOL_NAME`.<br><br>If you are using worker pools from a different project, ensure that you grant the<br>`roles/cloudbuild.workerPoolUser` role on the workerpool project to the Cloud Build Service Agent and the Cloud Build Service Account of the trigger project:<br>`service-PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com`, `PROJECT_NUMBER@cloudbuild.gserviceaccount.com` | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| acronyms | App Acronyms |
| app\_certificates | App Certificates |
| app\_ip\_addresses | App IP Addresses |
| clouddeploy\_targets\_names | Cloud deploy targets names. |
| cluster\_membership\_ids | GKE cluster membership IDs |
| cluster\_project\_id | Cluster Project ID |
| cluster\_project\_number | Cluster Project Number |
| cluster\_regions | Regions with clusters |
| cluster\_service\_accounts | The default service accounts used for nodes, if not overridden in node\_pools. |
| cluster\_type | Cluster type |
| env | Environment |
| fleet\_project\_id | Fleet Project ID |
| network\_project\_id | Network Project ID |
| service\_repository\_name | The Source Repository name. |
| service\_repository\_project\_id | The Source Repository project id. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
