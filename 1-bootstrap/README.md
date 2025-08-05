# 1. Bootstrap phase

## Purpose

The bootstrap phase streamlines the bootstrapping process for Enterprise Applications on Google Cloud Platform (GCP). It automates the creation of essential infrastructure components, including:

- Cloud Build repositories and triggers
- Service accounts with necessary IAM bindings
- Artifact Registry for storing Terraform images
- Cloud Storage buckets for storing Terraform state, plans and logs.

An overview of the deployment methodology for the Enterprise Application blueprint is shown below.
![Enterprise Application blueprint deployment diagram](../assets/eab-deployment.svg)

The folloging organization is expected by this phase:

```txt
.
└── fldr-seed/
    ├── fldr-common/
    │   ├── ...
    ├── fldr-development/
    │   ├── prj-vpc-dev
    │   └── ...
    ├── fldr-nonproduction/
    │   ├── prj-vpc-nonprod
    │   └── ...
    ├── fldr-prod/
    │   ├── prj-vpc-prod
    │   └── ...
    ├── prj-seed
```

### Features

__Automated Infrastructure Provisioning:__ Easily deploy a standardized and secure foundation for your enterprise applications.

__Cloud Build Integration:__ Automates Terraform plan and apply operations via Cloud Build triggers, enabling CI/CD workflows.

__Service Account Management:__ Creates and configures service accounts with the appropriate IAM roles for secure access to GCP resources.

__Artifact Registry:__ Provides a private Docker registry for storing custom Terraform images, ensuring consistent execution environments.

__Cloud Storage Buckets:__ Sets up dedicated Cloud Storage buckets for storing Terraform state files, execution plans, and logs, enhancing security and traceability.

__VPC Service Controls (VPC-SC) Support:__ Integrates with VPC-SC by allowing you to specify an access level and service perimeter for enhanced security (optional).

__Customizable Environments:__ Supports multiple environments (e.g., development, non-production, production) with configurable settings for billing accounts, folders, and networks.

__Cloud Build v2 Repository Integration:__ Integrates with Cloud Build v2 for repository management, supporting GitHub, GitLab, and Cloud Source Repositories (CSR).


## Usage

This section outlines the prerequisites and steps required to successfully deploy the module.

### Prerequisites

Before deploying the module, ensure the following prerequisites are met:

#### Seed Project

The seed project is the GCP project where the initial infrastructure resources will be created.

- __Billing Account:__ The seed project must have a billing account linked.

- __APIs Enabled:__ The following Google Cloud APIs must be enabled in the seed project. You can enable them using the gcloud command provided below.

   - `accesscontextmanager.googleapis.com`
   - `artifactregistry.googleapis.com`
   - `anthos.googleapis.com`
   - `anthosconfigmanagement.googleapis.com`
   - `apikeys.googleapis.com`
   - `binaryauthorization.googleapis.com`
   - `certificatemanager.googleapis.com`
   - `cloudbilling.googleapis.com`
   - `cloudbuild.googleapis.com`
   - `clouddeploy.googleapis.com`
   - `cloudfunctions.googleapis.com`
   - `cloudkms.googleapis.com`
   - `cloudresourcemanager.googleapis.com`
   - `cloudtrace.googleapis.com`
   - `compute.googleapis.com`
   - `container.googleapis.com`
   - `containeranalysis.googleapis.com`
   - `containerscanning.googleapis.com`
   - `gkehub.googleapis.com`
   - `iam.googleapis.com`
   - `iap.googleapis.com`
   - `mesh.googleapis.com`
   - `monitoring.googleapis.com`
   - `multiclusteringress.googleapis.com`
   - `multiclusterservicediscovery.googleapis.com`
   - `networkmanagement.googleapis.com`
   - `orgpolicy.googleapis.com`
   - `secretmanager.googleapis.com`
   - `servicedirectory.googleapis.com`
   - `servicemanagement.googleapis.com`
   - `servicenetworking.googleapis.com`
   - `serviceusage.googleapis.com`
   - `sqladmin.googleapis.com`
   - `storage.googleapis.com`
   - `trafficdirector.googleapis.com`

   To enable these APIs, execute the following command, replacing `YOUR_PROJECT_ID` with your actual project ID:

   ```bash
   gcloud services enable \
   accesscontextmanager.googleapis.com \
   artifactregistry.googleapis.com \
   anthos.googleapis.com \
   anthosconfigmanagement.googleapis.com \
   apikeys.googleapis.com \
   binaryauthorization.googleapis.com \
   certificatemanager.googleapis.com \
   cloudbilling.googleapis.com \
   cloudbuild.googleapis.com \
   clouddeploy.googleapis.com \
   cloudfunctions.googleapis.com \
   cloudkms.googleapis.com \
   cloudresourcemanager.googleapis.com \
   cloudtrace.googleapis.com \
   compute.googleapis.com \
   container.googleapis.com \
   containeranalysis.googleapis.com \
   containerscanning.googleapis.com \
   gkehub.googleapis.com \
   iam.googleapis.com \
   iap.googleapis.com \
   mesh.googleapis.com \
   monitoring.googleapis.com \
   multiclusteringress.googleapis.com \
   multiclusterservicediscovery.googleapis.com \
   networkmanagement.googleapis.com \
   orgpolicy.googleapis.com \
   secretmanager.googleapis.com \
   servicedirectory.googleapis.com \
   servicemanagement.googleapis.com \
   servicenetworking.googleapis.com \
   serviceusage.googleapis.com \
   sqladmin.googleapis.com \
   storage.googleapis.com \
   trafficdirector.googleapis.com \
   --project=YOUR_PROJECT_ID
   ```

- __IAM Roles:__ The identity deploying the module requires the following IAM roles on the seed project:

   - Cloud Build Connection Admin: `roles/cloudbuild.connectionAdmin`
   - Compute Network Admin: `roles/compute.networkAdmin`
   - Project IAM Admin: `roles/resourcemanager.projectIamAdmin`

### Secrets Project

A separate Google Cloud project is required to store Git credentials securely using Secret Manager. This project will be referenced as $GIT_SECRET_PROJECT throughout the documentation.

- __IAM Roles:__ The identity deploying the module requires the following IAM role on the secrets project:

   - Secret Manager Admin: `roles/secretmanager.admin`

- __API Enabled:__ The following API must be enabled in the secrets project:

   - `secretmanager.googleapis.com`

   To enable the API, execute the following command, replacing YOUR_PROJECT_ID with your actual project ID:

   ```bash
   gcloud services enable \
   secretmanager.googleapis.com \
   --project=YOUR_PROJECT_ID
   ```

### KMS Project

A separate Google Cloud project is required to store the KMS key used for attestation.

- __IAM Roles:__ The identity deploying the module requires the following IAM role on the KMS project:

   - Project IAM Admin: `roles/resourcemanager.projectIamAdmin`

- __API Enabled:__ The following API must be enabled in the KMS project:

   - `cloudkms.googleapis.com`

   To enable the API, execute the following command, replacing `YOUR_PROJECT_ID` with your actual project ID:

   ```bash
   gcloud services enable \
   cloudkms.googleapis.com \
   --project=YOUR_PROJECT_ID
   ```

### KMS Key for Bucket Encryption

A KMS key will be used to encrypt the contents of the created Cloud Storage buckets. This key should reside in the KMS Project.

- __IAM Roles:__ The Storage service agent for the KMS Project requires the following IAM roles:

   - Cloud KMS CryptoKey Encrypter: `roles/cloudkms.cryptoKeyEncrypter`
   - Cloud KMS CryptoKey Decrypter: `roles/cloudkms.cryptoKeyDecrypter`

### Logging Bucket

You can optionally specify an existing Cloud Storage bucket to store logs from:

- Build logs
- Terraform state bucket

### VPC Service Controls (VPC-SC)

This module supports deployment within a VPC-SC perimeter.

__Important:__ The Cloud Build project (seed project) __cannot__ be within the perimeter. This is because the module creates new projects, and errors will occur when accessing services (e.g., enabling APIs) before the new project is added to the perimeter.

This module does not create the Service Perimeter or Access Level. However, it can add projects to the Service Perimeter, create directional rules, and add identities to the Access Level.

To enable VPC-SC integration, you must provide the following:

- An existing Access Level name.
- An existing Service Perimeter name.
- The deployment mode (`DRY_RUN` or `ENFORCED`).

The identity deploying the module must be a member of the specified Access Level.

- __IAM Roles:__ The identity deploying the module requires the following IAM role at the organization level:

- __Access Context Manager Admin:__ `roles/accesscontextmanager.policyAdmin`

### Private Worker Pool Requirements

A private worker pool is required to run within a VPC-SC perimeter.

A sample Worker Pool configuration without external IP, peered network, and NAT is provided in the `test/setup/modules/private_workerpool/` folder. This sample includes a project, a Private Worker Pool in its own project, a peered VPC with a NAT VM that allows internet egress for external dependencies, and the necessary firewall rules and configurations.

The same pool can be used across multiple steps. Reserving a wider IP range allows for more concurrent builds. A /24 range supports 254 hosts.

- __IAM Roles:__ The identity deploying the module must have the following IAM roles on the Private Worker Pool project:

- __Cloud Build WorkerPool User:__ `roles/cloudbuild.workerPoolUser`
- __Project IAM Admin:__ `roles/resourcemanager.projectIamAdmin`

### Environments Infrastructure

The following infrastructure is required for the different environments:

#### Folders

You need to pre-create the following folders:

- A common folder.
- A folder per environment (e.g., development, nonproduction, production).
- __IAM Roles:__ The identity deploying the module requires the following IAM roles on the folders:
   - Folder Admin: `roles/resourcemanager.folderAdmin`
   - Project Creator: `roles/resourcemanager.projectCreator`
   - Compute Network Admin: `roles/compute.networkAdmin`
   - Compute Shared VPC Admin: `roles/compute.xpnAdmin`

### Shared Network

You need a Shared VPC per environment already created.

The networks must meet the following requirements:

- Two subnets in different regions.
- Each subnet must have two secondary ranges.
- Ingress firewall rule allowing SSH.

A sample network configuration can be found in the `test/setup/harness/multitenant` module.

#### Cloud Build with Github Pre-requisites

To proceed with GitHub as your git provider you will need:

- An authenticated GitHub account. The steps in this documentation assumes you have a configured SSH key for cloning and modifying repositories.
- A **private** [GitHub repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository) for each one of the repositories below:
  - Multitenant (`eab-multitenant`)
  - Fleetscope (`eab-fleetscope`)
  - Application Factory (`eab-applicationfactory`)

   > Note: Default names for the repositories are, in sequence: `eab-multitenant`, `eab-fleetscope` and `eab-applicationfactory`; If you choose other names for your repository make sure you update `terraform.tfvars` the repository names under `cloudbuildv2_repository_config` variable.

- [Install Cloud Build App on Github](https://github.com/apps/google-cloud-build). After the installation, take note of the application id, it will be used later.
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

- Populate your `terraform.tfvars` file in `1-bootstrap` with the Cloud Build 2nd Gen configuration variable, here is an example:

   ```hcl
   cloudbuildv2_repository_config = {
      repo_type = "GITHUBv2"

      repositories = {
         multitenant = {
            repository_name = "eab-multitenant"
            repository_url  = "https://github.com/your-org/eab-multitenant.git"
         }

         applicationfactory = {
            repository_name = "eab-applicationfactory"
            repository_url  = "https://github.com/your-org/eab-applicationfactory.git"
         }

         fleetscope = {
            repository_name = "eab-fleetscope"
            repository_url  = "https://github.com/your-org/eab-fleetscope.git"
         }
      }

      github_secret_id                            = "projects/REPLACE_WITH_PRJ_NUMBER/secrets/github-pat" # Personal Access Token Secret
      github_app_id_secret_id                     = "projects/REPLACE_WITH_PRJ_NUMBER/secrets/github-app-id" # App ID value secret
      secret_project_id                           = "REPLACE_WITH_SECRET_PROJECT_ID"
   }
   ```

#### Cloud Build with Gitlab Pre-requisites

To proceed with Gitlab as your git provider you will need:

- An authenticated Gitlab account. The steps in this documentation assumes you have a configured SSH key for cloning and modifying repositories.
- A **private** GitLab repository for each one of the repositories below:
  - Multitenant (`eab-multitenant`)
  - Fleetscope (`eab-fleetscope`)
  - Application Factory (`eab-applicationfactory`)

   > Note: Default names for the repositories are, in sequence: `eab-multitenant`, `eab-fleetscope` and `eab-applicationfactory`; If you choose other names for your repository make sure you update `terraform.tfvars` the repository names under `cloudbuildv2_repository_config` variable.

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

- Populate your `terraform.tfvars` file in `1-bootstrap` with the Cloud Build 2nd Gen configuration variable, here is an example:

   ```hcl
   cloudbuildv2_repository_config = {
      repo_type = "GITLABv2"

      repositories = {
         multitenant = {
            repository_name = "eab-multitenant"
            repository_url  = "https://gitlab.com/your-group/eab-multitenant.git"
         }

         applicationfactory = {
            repository_name = "eab-applicationfactory"
            repository_url  = "https://gitlab.com/your-group/eab-applicationfactory.git"
         }

         fleetscope = {
            repository_name = "eab-fleetscope"
            repository_url  = "https://gitlab.com/your-group/eab-fleetscope.git"
         }
      }

      gitlab_authorizer_credential_secret_id         = "projects/REPLACE_WITH_PRJ_NUMBER/secrets/gitlab-api-token"
      gitlab_read_authorizer_credential_secret_id    = "projects/REPLACE_WITH_PRJ_NUMBER/secrets/gitlab-read-api-token"
      gitlab_webhook_secret_id                       = "projects/REPLACE_WITH_PRJ_NUMBER/secrets/gitlab-webhook"

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


### Deploying with Cloud Build

#### Deploying on Enterprise Foundation blueprint

If you have previously deployed the Enterprise Foundation blueprint, create the pipelines in this phase by pushing the contents of this folder to a [workload repo created at stage 5](https://github.com/terraform-google-modules/terraform-example-foundation/blob/master/5-app-infra/README.md). Instead of deploying to multiple environments, create these pipelines in the common folder of the foundation.

Start at "5. Clone the `bu1-example-app` repo". Replace the contents of that repo with the contents of this folder.

### Running Terraform locally

#### Step-by-Step

1. The next instructions assume that you are in the `terraform-google-enterprise-application/1-bootstrap` folder.

   ```bash
   cd terraform-google-enterprise-application/1-bootstrap
   ```

1. Rename `terraform.example.tfvars` to `terraform.tfvars`.

   ```bash
   mv terraform.example.tfvars terraform.tfvars
   ```

1. Update the `terraform.tfvars` file with your project id. If you are using Github or Gitlab as your Git provider for Cloud Build, you will need to configure the `cloudbuildv2_repository_config` variable as described in the following sections:
   - [Cloud Build with Github Pre-requisites](#cloud-build-with-github-pre-requisites)
   - [Cloud Build with Gitlab Pre-requisites](#cloud-build-with-gitlab-pre-requisites)

You can now deploy the common environment for these pipelines.

1. Run `init` and `plan` and review the output.

   ```bash
   terraform init
   terraform plan
   ```

1. Run `apply`.

   ```bash
   terraform apply
   ```

If you receive any errors or made any changes to the Terraform config or `terraform.tfvars`, re-run `terraform plan` before you run `terraform apply`.

### Updating `backend.tf` files on the repository

Within the repository, you'll find `backend.tf` files that define the GCS bucket for storing the Terraform state. By running the commands below, instances of `UPDATE_ME` placeholders in these files will be automatically replaced with the actual name of your GCS bucket.

1. Running the series of commands below will update the remote state bucket for `backend.tf` files on the repository.

   ```bash
   export backend_bucket=$(terraform output -raw state_bucket)
   echo "backend_bucket = ${backend_bucket}"

   cp backend.tf.example backend.tf
   cd ..

   for i in `find . -name 'backend.tf'`; do sed -i'' -e "s/UPDATE_ME/${backend_bucket}/" $i; done
   ```

1. Re-run `terraform init`. When you're prompted, agree to copy Terraform state to Cloud Storage.

   ```bash
   cd 1-bootstrap

   terraform init
   ```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_level\_name | (VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter. | `string` | `null` | no |
| attestation\_kms\_project | KMS Key project where the key for attestation is stored. | `string` | `null` | no |
| bucket\_force\_destroy | When deleting a bucket, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects. | `bool` | `false` | no |
| bucket\_kms\_key | KMS Key id to be used to encrypt bucket. | `string` | `null` | no |
| bucket\_prefix | Name prefix to use for buckets created. | `string` | `"bkt"` | no |
| cloudbuildv2\_repository\_config | Configuration for integrating repositories with Cloud Build v2:<br>  - repo\_type: Specifies the type of repository. Supported types are 'GITHUBv2', 'GITLABv2', and 'CSR'.<br>  - repositories: A map of repositories to be created. The key must match the exact name of the repository. Each repository is defined by:<br>      - repository\_name: The name of the repository.<br>      - repository\_url: The URL of the repository.<br>  - github\_secret\_id: (Optional) The personal access token for GitHub authentication.<br>  - github\_app\_id\_secret\_id: (Optional) The application ID for a GitHub App used for authentication.<br>  - gitlab\_read\_authorizer\_credential\_secret\_id: (Optional) The read authorizer credential for GitLab access.<br>  - gitlab\_authorizer\_credential\_secret\_id: (Optional) The authorizer credential for GitLab access.<br>  - gitlab\_webhook\_secret\_id: (Optional) The secret ID for the GitLab WebHook.<br>  - gitlab\_enterprise\_host\_uri: (Optional) The URI of the GitLab Enterprise host this connection is for. If not specified, the default value is https://gitlab.com.<br>  - gitlab\_enterprise\_service\_directory: (Optional) Configuration for using Service Directory to privately connect to a GitLab Enterprise server. This should only be set if the GitLab Enterprise server is hosted on-premises and not reachable by public internet. If this field is left empty, calls to the GitLab Enterprise server will be made over the public internet. Format: projects/{project}/locations/{location}/namespaces/{namespace}/services/{service}.<br>  - gitlab\_enterprise\_ca\_certificate: (Optional) SSL certificate to use for requests to GitLab Enterprise.<br>  - secret\_project\_id: (Optional) The project id where the secret is stored.<br>Note: When using GITLABv2, specify `gitlab_read_authorizer_credential` and `gitlab_authorizer_credential` and `gitlab_webhook_secret_id`.<br>Note: When using GITHUBv2, specify `github_pat` and `github_app_id`.<br>Note: If 'cloudbuildv2\_repository\_config' variable is not configured, CSR (Cloud Source Repositories) will be used by default. | <pre>object({<br>    repo_type = string # Supported values are: GITHUBv2, GITLABv2 and CSR<br>    # repositories to be created<br>    repositories = object({<br>      multitenant = object({<br>        repository_name = optional(string, "eab-multitenant")<br>        repository_url  = string<br>      }),<br>      applicationfactory = object({<br>        repository_name = optional(string, "eab-applicationfactory")<br>        repository_url  = string<br>      }),<br>      fleetscope = object({<br>        repository_name = optional(string, "eab-fleetscope")<br>        repository_url  = string<br>      }),<br>    })<br>    # Credential Config for each repository type<br>    github_secret_id                            = optional(string)<br>    github_app_id_secret_id                     = optional(string)<br>    gitlab_read_authorizer_credential_secret_id = optional(string)<br>    gitlab_authorizer_credential_secret_id      = optional(string)<br>    gitlab_webhook_secret_id                    = optional(string)<br>    gitlab_enterprise_host_uri                  = optional(string)<br>    gitlab_enterprise_service_directory         = optional(string)<br>    gitlab_enterprise_ca_certificate            = optional(string)<br>    secret_project_id                           = optional(string)<br>  })</pre> | <pre>{<br>  "repo_type": "CSR",<br>  "repositories": {<br>    "applicationfactory": {<br>      "repository_url": ""<br>    },<br>    "fleetscope": {<br>      "repository_url": ""<br>    },<br>    "multitenant": {<br>      "repository_url": ""<br>    }<br>  }<br>}</pre> | no |
| common\_folder\_id | Folder ID in which to create all application admin projects, must be prefixed with 'folders/' | `string` | n/a | yes |
| envs | Environments | <pre>map(object({<br>    billing_account    = string<br>    folder_id          = string<br>    network_project_id = string<br>    network_self_link  = string<br>    org_id             = string<br>    subnets_self_links = list(string)<br>  }))</pre> | n/a | yes |
| location | Location for build buckets. | `string` | `"us-central1"` | no |
| logging\_bucket | Bucket to store logging. | `string` | `null` | no |
| org\_id | Organization ID | `string` | n/a | yes |
| project\_id | Project ID for initial resources | `string` | n/a | yes |
| service\_perimeter\_mode | (VPC-SC) Service perimeter mode: ENFORCE, DRY\_RUN. | `string` | n/a | yes |
| service\_perimeter\_name | (VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter. | `string` | `null` | no |
| tf\_apply\_branches | List of git branches configured to run terraform apply Cloud Build trigger. All other branches will run plan by default. | `list(string)` | <pre>[<br>  "development",<br>  "nonproduction",<br>  "production"<br>]</pre> | no |
| trigger\_location | Location of for Cloud Build triggers created in the workspace. If using private pools should be the same location as the pool. | `string` | `"us-central1"` | no |
| workerpool\_id | Specifies the Cloud Build Worker Pool that will be utilized for triggers created in this step.<br><br>The expected format is:<br>`projects/PROJECT/locations/LOCATION/workerPools/POOL_NAME`.<br><br>If you are using worker pools from a different project, ensure that you grant the<br>`roles/cloudbuild.workerPoolUser` role on the workerpool project to the Cloud Build Service Agent and the Cloud Build Service Account of the trigger project:<br>`service-PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com`, `PROJECT_NUMBER@cloudbuild.gserviceaccount.com` | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| artifacts\_bucket | Bucket for storing TF plans |
| binary\_authorization\_image | Image build to create attestations. |
| binary\_authorization\_repository\_id | The ID of the Repository where binary attestation image is stored. |
| cb\_private\_workerpool\_id | Private Worker Pool ID used for Cloud Build Triggers. |
| cb\_service\_accounts\_emails | Service Accounts for the Multitenant Administration Cloud Build Triggers |
| logs\_bucket | Bucket for storing TF logs |
| project\_id | Project ID |
| source\_repo\_urls | Source repository URLs |
| state\_bucket | Bucket for storing TF state |
| tf\_project\_id | Google Artifact registry terraform project id. |
| tf\_repository\_name | Name of Artifact Registry repository for Terraform image. |
| tf\_tag\_version\_terraform | Docker tag version terraform. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
