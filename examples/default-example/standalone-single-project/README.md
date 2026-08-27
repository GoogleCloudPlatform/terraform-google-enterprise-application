# Standalone Single-Project Example
The Standalone Single Project Example deploys the core Enterprise Application Blueprint into a single project for the purposes of simplified demonstration.

**Do not use this example for production deployments, as it lacks robust separation of duties and least-privileged permissions present in the standard multi-stage deployment.**

This example creates:

- 1-harness
    - Enable required APIs
    - Cluster network
    - Private Worker Pool
        - Network + NAT
    - Binary Authorization attestor image
- 2-multitenant
    - GKE cluster(s)
    - Cloud Armor
    - App IP addresses (see below for details)
- 3-Fleetscope
    - Fleet namespace
    - Cloud Source Repo
    - Config Management
    - Service Mesh
    - Multicluster Ingress
    - Multicluster Service
- 5-Appinfra
    - Private Worker Pool
    - Cloud Build Trigger
    - Artifact Registry
    - Cloud Deploy
    - Cloud Deploy Pipelines
    - Cloud Build Service Account
    - Cloud Deploy Service Account
    - Cloud Storage


## Pre-requisites

This example requires a single project already created. The following APIs will be enabled:

- `accesscontextmanager.googleapis.com`
- `anthos.googleapis.com`
- `anthosconfigmanagement.googleapis.com`
- `apikeys.googleapis.com`
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
- `servicemanagement.googleapis.com`
- `servicenetworking.googleapis.com`
- `serviceusage.googleapis.com`
- `sqladmin.googleapis.com`
- `storage-api.googleapis.com`
- `trafficdirector.googleapis.com`

But if you are using a service account to deploy this example, you must enable at least the `cloudresourcemanager.googleapis.com` API:

 ```bash
   gcloud services enable \
   cloudresourcemanager.googleapis.com \
   --project=YOUR_PROJECT_ID
```

The entity used to deploy this example must have the following roles at Project level:

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
- Viewer: `roles/viewer`
- Secret Manager Editor: `roles/secretmanager.editor`

The entity used to deploy this example must have the following roles at Organization level:

- Organization Administrator: `roles/resourcemanager.organizationAdmin`
- Access Context Manager Policy Admin: `roles/accesscontextmanager.policyAdmin`

If you are going to use Github or Gitlab, you must enable the `secretmanager.googleapis.com` API:

 ```bash
   gcloud services enable \
   secretmanager.googleapis.com \
   --project=YOUR_PROJECT_ID
```

####  KMS Key for Bucket Encryption

A KMS key will be used to encrypt the contents of the created Cloud Storage buckets.

####  KMS Key for Binary Authorization Attestation

A KMS key will be used to sign images during building time.

### Logging Bucket

You can optionally specify an existing Cloud Storage bucket to store logs from:

- Build logs
- Terraform state bucket

The bucket will use the KMS Key provided to encrypt the content. In this case, the code will grant the Storage Service Agent:

   - Cloud KMS CryptoKey Encrypter: `roles/cloudkms.cryptoKeyEncrypter`
   - Cloud KMS CryptoKey Decrypter: `roles/cloudkms.cryptoKeyDecrypter`

If a Key is not provided, a new one will be created at the same project to encrypt the content.

### VPC Service Controls (VPC-SC)

This module supports deployment within a VPC-SC perimeter.

This module does not create the Service Perimeter or Access Level. However, it can add projects to the Service Perimeter, create directional rules, and add identities to the Access Level.

To enable VPC-SC integration, you must provide the following:

- An existing Access Level name. Since the module will be adding access level conditions, your access level need to be configured with 'OR' as the combining function.
- An existing Service Perimeter name.
- The deployment mode (`DRY_RUN` or `ENFORCED`).

The identity deploying the module must be a member of the specified Access Level.

- __IAM Roles:__ The identity deploying the module requires the following IAM role at the organization level:

   - __Access Context Manager Admin:__ `roles/accesscontextmanager.policyAdmin`

   ```bash
   export SERVICE_ACCOUNT_EMAIL='YOUR_SERVICE_ACCOUNT_EMAIL'
   gcloud organizations add-iam-policy-binding YOUR_ORGANIZATION_ID \
   --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
   --role="roles/accesscontextmanager.policyAdmin"
   ```

#### Cloud Build with Github Pre-requisites

To proceed with GitHub as your git provider you will need:

- An authenticated GitHub account. The steps in this documentation assumes you have a configured SSH key for cloning and modifying repositories.
- A **private** [GitHub repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository) for each one of the repositories below:
  - eab-default-example-hello-world (`eab-default-example-hello-world`)

   > Note: Default name for the repository is: `eab-default-example-hello-world`; If you choose other name for your repository make sure you update `terraform.tfvars` the repository names under `cloudbuildv2_repository_config` variable.

- [Install Cloud Build App on Github](https://github.com/apps/google-cloud-build). After the installation, take note of the application id, it will be used later. Your instalarion id can be foundt in [https://github.com/settings/installations](https://github.com/settings/installations).
- [Create Personal Access Token (classic) on Github](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic)
   - Grant `repo` and `read:user` (or if app is installed in org use `read:org`)
   - After creating the token in Secret Manager, you will use the secret id in the `terraform.tfvars` file.
- Create a secret for the Github Cloud Build App ID:

   ```bash
   APP_ID_VALUE=<replace_with_app_id>
   printf $APP_ID_VALUE | gcloud secrets create github-app-id --project=$GIT_SECRET_PROJECT --data-file=-
   ```

- Take note of the secret id, it will be used in `terraform.tfvars` later on:

   ```bash
   gcloud secrets describe github-app-id --project=$GIT_SECRET_PROJECT --format="value(name)"
   ```

- Create a secret for the Github Personal Access Token:

   ```bash
   GITHUB_TOKEN=<replace_with_token>
   printf $GITHUB_TOKEN | gcloud secrets create github-pat --project=$GIT_SECRET_PROJECT --data-file=-
   ```

- Take note of the secret id, it will be used in `terraform.tfvars` later on:

   ```bash
   gcloud secrets describe github-pat --project=$GIT_SECRET_PROJECT --format="value(name)"
   ```

- Populate your `terraform.tfvars` file with the Cloud Build 2nd Gen configuration variable, here is an example:

   ```hcl
   cloudbuildv2_repository_config = {
      repo_type = "GITHUBv2"

      repositories = {
         eab-default-example-hello-world = {
            repository_name = "eab-default-example-hello-world"
            repository_url  = "https://github.com/your-org/eab-default-example-hello-world.git"
         }
      }

      github_secret_id                            = "projects/REPLACE_WITH_SECRET_PRJ_NUMBER/secrets/REPLACE_WITH_GITHUB_PAT_SECRET_NAME" # Personal Access Token Secret
      github_app_id_secret_id                     = "projects/REPLACE_WITH_SECRET_PRJ_NUMBER/secrets/REPLACE_WITH_GITHUB_APP_ID_SECRET_NAME" # App ID value secret
      secret_project_id                           = "REPLACE_WITH_SECRET_PROJECT_ID"
   }
   ```

#### Cloud Build with Gitlab Pre-requisites

To proceed with Gitlab as your git provider you will need:

- An authenticated Gitlab account. The steps in this documentation assumes you have a configured SSH key for cloning and modifying repositories.
- A **private** GitLab repository for each one of the repositories below:
  - Hello World (`eab-default-example-hello-world`)

  > Note: Default name for the repository is: `eab-default-example-hello-world`; If you choose other name for your repository make sure you update `terraform.tfvars` the repository names under `cloudbuildv2_repository_config` variable.

- An access token with the `api` scope to use for connecting and disconnecting repositories.

- An access token with the `read_api` scope to ensure Cloud Build repositories can access source code in repositories.

- Create a secret for the Gitlab API Access Token:

   ```bash
   GITLAB_API_TOKEN=<replace_with_app_id>
   printf $GITLAB_API_TOKEN | gcloud secrets create gitlab-api-token --project=$GIT_SECRET_PROJECT --data-file=-
   ```

- Take note of the secret id, it will be used in `terraform.tfvars` later on:

   ```bash
   gcloud secrets describe gitlab-api-token --project=$GIT_SECRET_PROJECT --format="value(name)"
   ```

- Create a secret for the Gitlab Read API Access Token:

   ```bash
   GITLAB_READ_API_TOKEN=<replace_with_token>
   printf $GITLAB_READ_API_TOKEN | gcloud secrets create gitlab-read-api-token --project=$GIT_SECRET_PROJECT --data-file=-
   ```

- Take note of the secret id, it will be used in `terraform.tfvars` later on:

   ```bash
   gcloud secrets describe gitlab-read-api-token --project=$GIT_SECRET_PROJECT --format="value(name)"
   ```

- Generate a random 36 character string that will be used as the Webhook Secret:

   ```bash
   GITLAB_WEBHOOK=<replace_with_webhook>
   printf $GITLAB_WEBHOOK | gcloud secrets create gitlab-webhook --project=$GIT_SECRET_PROJECT --data-file=-
   ```

   > NOTE: for testing purposes, you may use the following command to generate the webhook in bash: `GITLAB_WEBHOOK=$(cat /dev/urandom | tr -dc "[:alnum:]" | head -c 36)`

- Take note of the secret id, it will be used in `terraform.tfvars` later on:

   ```bash
   gcloud secrets describe gitlab-webhook --project=$GIT_SECRET_PROJECT --format="value(name)"
   ```

- Populate your `terraform.tfvars` file with the Cloud Build 2nd Gen configuration variable, here is an example:

   ```hcl
   cloudbuildv2_repository_config = {
      repo_type = "GITLABv2"

      repositories = {
         eab-default-example-hello-world = {
            repository_name = "eab-default-example-hello-world"
            repository_url  = "https://gitlab.com/your-group/eab-default-example-hello-world.git"
         }
      }

      gitlab_authorizer_credential_secret_id         = "projects/REPLACE_WITH_SECRET_PRJ_NUMBER/secrets/REPLACE_WITH_GITLAB_API_TOKEN_SECRET_NAME"
      gitlab_read_authorizer_credential_secret_id    = "projects/REPLACE_WITH_SECRET_PRJ_NUMBER/secrets/REPLACE_WITH_GITLAB_READ_API_TOKEN_SECRET_NAME"
      gitlab_webhook_secret_id                       = "projects/REPLACE_WITH_SECRET_PRJ_NUMBER/secrets/REPLACE_WITH_WEBHOOK_SECRET_NAME"

      secret_project_id                           = "REPLACE_WITH_SECRET_PROJECT_ID"

      # If you are using a self-hosted instance, you may change the URL below accordingly
      gitlab_enterprise_host_uri = "https://gitlab.com"

      gitlab_enterprise_service_directory = "projects/PROJECT/locations/LOCATION/namespaces/NAMESPACE/services/SERVICE"

      # .pem string
      gitlab_enterprise_ca_certificate = <<EOF
      REPLACE_WITH_SSL_CERT
      EOF
   }
   ```

## Usage

the steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` directory:

```txt
.
├── terraform-google-enterprise-application
└── .
```

1. Enter at Single Project example folder:

    ```bash
    cd terraform-google-enterprise-application/examples/default-example/standalone-single-project
    ```

1. Update `terraform.tfvars`.

1. Run `terraform plan` and check the information

1. Run `terraform apply`.

1. Clone the source repository

    - Cloud Source Repository only

    ```bash
    gcloud source repos clone eab-default-example-hello-world --project=REPLACE_WITH_ADMIN_PROJECT
    ```

    - Github Repository only

    ```bash
    git clone https://github.com/your-org/eab-default-example-hello-world.git
    ```

    - Gitlab Repository only

    ```bash
    git clone https://gitlab.com/your-group/eab-default-example-hello-world.git
    ```

1. Copy the contents of this directory to the repository:

```bash
cp -r terraform-google-enterprise-application/examples/default-example/6-appsource/default-example/* eab-default-example-hello-world
```

1. Commit changes

```bash
cd eab-default-example-hello-world
git checkout -b main
git add .
git commit -m "Add source code to the repository"
git push origin main
```

1. After pushing the code to the main branch, the CI (build) pipeline will be triggered on the `hello-world-admin` project under the common folder. You can view the results on the Cloud Build Page.

1. After the CI build successfully runs, it will automatically trigger the CD pipeline using Cloud Deploy on the same project.

1. Once the CD pipeline successfully runs, you should be able to see a pod named `getting-started` on your cluster that prints the "Hello world!" message.


## Troubleshooting

You can refer to the [Troubleshooting doc](docs/TROUBLESHOOTING.md).



<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_level\_name | (VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter. | `string` | `null` | no |
| attestation\_kms\_key | The KMS Key ID to be used by attestor. | `string` | n/a | yes |
| bucket\_kms\_key | KMS Key id to be used to encrypt bucket. | `string` | `null` | no |
| cloudbuildv2\_repository\_config | Configuration for integrating repositories with Cloud Build v2:<br>  - repo\_type: Specifies the type of repository. Supported types are 'GITHUBv2', 'GITLABv2', and 'CSR'.<br>  - repositories: A map of repositories to be created. The key must match the exact name of the repository. Each repository is defined by:<br>      - repository\_name: The name of the repository.<br>      - repository\_url: The URL of the repository.<br>  - github\_secret\_id: (Optional) The personal access token for GitHub authentication.<br>  - github\_app\_id\_secret\_id: (Optional) The application ID for a GitHub App used for authentication.<br>  - gitlab\_read\_authorizer\_credential\_secret\_id: (Optional) The read authorizer credential for GitLab access.<br>  - gitlab\_authorizer\_credential\_secret\_id: (Optional) The authorizer credential for GitLab access.<br>  - gitlab\_webhook\_secret\_id: (Optional) The secret ID for the GitLab WebHook.<br>  - gitlab\_enterprise\_host\_uri: (Optional) The URI of the GitLab Enterprise host this connection is for. If not specified, the default value is https://gitlab.com.<br>  - gitlab\_enterprise\_service\_directory: (Optional) Configuration for using Service Directory to privately connect to a GitLab Enterprise server. This should only be set if the GitLab Enterprise server is hosted on-premises and not reachable by public internet. If this field is left empty, calls to the GitLab Enterprise server will be made over the public internet. Format: projects/{project}/locations/{location}/namespaces/{namespace}/services/{service}.<br>  - gitlab\_enterprise\_ca\_certificate: (Optional) SSL certificate to use for requests to GitLab Enterprise.<br>Note: When using GITLABv2, specify `gitlab_read_authorizer_credential` and `gitlab_authorizer_credential` and `gitlab_webhook_secret_id`.<br>Note: When using GITHUBv2, specify `github_pat` and `github_app_id`.<br>Note: If 'cloudbuildv2\_repository\_config' variable is not configured, CSR (Cloud Source Repositories) will be used by default. | <pre>object({<br>    repo_type = string # Supported values are: GITHUBv2, GITLABv2 and CSR<br>    # repositories to be created<br>    repositories = map(<br>      object({<br>        repository_name = string<br>        repository_url  = string<br>      })<br>    )<br>    # Credential Config for each repository type<br>    github_secret_id                            = optional(string)<br>    github_app_id_secret_id                     = optional(string)<br>    gitlab_read_authorizer_credential_secret_id = optional(string)<br>    gitlab_authorizer_credential_secret_id      = optional(string)<br>    gitlab_webhook_secret_id                    = optional(string)<br>    gitlab_enterprise_host_uri                  = optional(string)<br>    gitlab_enterprise_service_directory         = optional(string)<br>    gitlab_enterprise_ca_certificate            = optional(string)<br>  })</pre> | n/a | yes |
| create\_nat | Enables Cloud NAT creation for Private Worker Pool, disable if your network already has one created. | `bool` | `true` | no |
| enables\_network\_connection\_and\_peering\_routes | Enables Network connection and peering routes. | `bool` | `true` | no |
| logging\_bucket | Bucket to store logging. | `string` | `null` | no |
| ncc\_config | Configuration block for Google Cloud Network Connectivity Center (NCC) Spokes.<br>- enable\_ncc: (bool) Toggles whether to create a new NCC spoke.<br>- hub\_uri: (string) The URI of an existing Hub. [Required if enable\_ncc is TRUE]<br>- spoke\_group: (string) The NCC group the spoke belongs to (default: "default").<br>- spoke\_name: (string) Name for the main VPC spoke.<br>- spoke\_description: (string) Description for the main VPC spoke.<br>- spoke\_labels: (map) Labels for the main VPC spoke.<br>- spoke\_exclude\_export\_ranges: (set of strings) IP ranges to exclude from route export.<br>- spoke\_include\_export\_ranges: (set of strings) IP ranges to explicitly include in route export. | <pre>object({<br>    enable_ncc                  = optional(bool, false)<br>    hub_uri                     = optional(string)<br>    spoke_group                 = optional(string, "default")<br>    spoke_name                  = optional(string, "vpc-spoke")<br>    spoke_description           = optional(string)<br>    spoke_labels                = optional(map(string))<br>    spoke_exclude_export_ranges = optional(set(string), [])<br>    spoke_include_export_ranges = optional(set(string), [])<br>  })</pre> | n/a | yes |
| network\_id | The network ID where the private worker pool is going to be peered. If not provided, a new network is going to be created. | `string` | `null` | no |
| project\_id | Google Cloud project ID in which to deploy all example resources | `string` | n/a | yes |
| region | Google Cloud region for deployments | `string` | `"us-central1"` | no |
| service\_perimeter\_mode | (VPC-SC) Service perimeter mode: ENFORCE, DRY\_RUN. | `string` | `"ENFORCE"` | no |
| service\_perimeter\_name | (VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter. | `string` | `null` | no |
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
