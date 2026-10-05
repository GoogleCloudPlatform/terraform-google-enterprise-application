# Enterprise Application Blueprint Deploy Helper

Helper tool to deploy Enterprise Application Blueprint examples (including `standalone-single-project` architectures) using Terraform, Cloud Build, and Cloud Deploy.

## Requirements

- [Go](https://go.dev/doc/install) 1.25 or later
- [Google Cloud SDK](https://cloud.google.com/sdk/install) version 393.0.0 or later
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) version 2.28.0 or later
- [Terraform](https://www.terraform.io/downloads.html) version 1.5.7 or later

### Validate required tools

Check that the required tools are installed:

```bash
go version
terraform -version
gcloud --version
git --version
```

Verify that required `gcloud` components are installed:

```bash
gcloud components list --filter="id=beta OR id=terraform-tools"
```

### Prepare the deploy environment

1. Create a working directory in your file system to host the repositories and blueprint code:

    ```text
    deploy-directory/
    └── terraform-google-enterprise-application
    ```

2. Copy the sample variable configuration file:

    ```bash
    cp helpers/eab-deployer/global.tfvars.example deploy-directory/global.tfvars
    ```

3. Update `global.tfvars` with the specific values for your Google Cloud environment:

   **Helper Tool Configuration:**
   - `eab_code_path`: The full path to your local `terraform-google-enterprise-application` repository.
   - `code_checkout_path`: The full path to your working `deploy-directory` where repositories will be checked out and initialized.

   **Core GCP & Networking Configuration:**
   - `project_id`: Your Google Cloud project ID in which to deploy all infrastructure, cluster, and CI/CD resources.
   - `region`: Google Cloud region for deployments (e.g., `us-central1`).
   - `workerpool_id`: Cloud Build Private Worker Pool ID (`projects/PROJECT/locations/LOCATION/workerPools/POOL_NAME`).
   - `network_id` *(optional)*: Existing VPC Network ID or self-link for private worker pool peering. If omitted, a new network is created.
   - `subnetwork_self_link` *(optional)*: Existing Subnetwork self-link.
   - `create_nat` *(optional, bool)*: Enables Cloud NAT creation for Private Worker Pool network (defaults to `true`).
   - `enables_network_connection_and_peering_routes` *(optional, bool)*: Enables network connection and peering routes (defaults to `true`).
   - `logging_bucket` *(optional)*: Cloud Storage bucket name for Cloud Build and deployment logs.
   - `bucket_kms_key` *(optional)*: Customer-managed KMS Key ID to encrypt the logging bucket.
   - `ncc_config` *(optional)*: Configuration block for connecting the cluster network to a Network Connectivity Center (NCC) Hub.

   **Security & Binary Authorization:**
   - `attestation_kms_key`: The KMS Key ID to be used for Binary Authorization attestor signatures.
   - `service_perimeter_name` *(optional)*: VPC Service Controls (VPC-SC) service perimeter name.
   - `service_perimeter_mode` *(optional)*: VPC-SC perimeter mode (`ENFORCE` or `DRY_RUN`, defaults to `ENFORCE`).
   - `access_level_name` *(optional)*: Access Level name for identities operating inside an enforced VPC-SC perimeter.
   - `binary_authorization_image` *(optional)*: Container image URI for Binary Authorization attestor image builder.
   - `binary_authorization_repository_id` *(optional)*: Artifact Registry repository ID for attestor builder container images.

   **Teams & CI/CD Repository Configuration:**
   - `teams`: Map of namespace keys to team group email addresses (e.g., `{"cb-frontend" = "frontend-team@example.com", ...}`).
   - `cloudbuildv2_repository_config`: Configuration block for integrating service repositories with Cloud Build v2:
     - `repo_type`: Supported types are `CSR` (Cloud Source Repositories), `GITHUBv2`, or `GITLABv2`.
     - `repositories`: Map of service keys to repository definitions (`repository_name` and `repository_url`).
     - Credential secret IDs for GitHub App / GitLab personal access tokens and authorizer credentials.

   **Upstream Application Source (Optional Overrides):**
   - `app_source_repo_url` *(optional)*: Upstream repository URL to clone application source code from. If omitted, the default defined in the example's `variables.tf` is used (e.g., `https://github.com/GoogleCloudPlatform/bank-of-anthos.git` for Cymbal Bank or `https://github.com/GoogleCloudPlatform/microservices-demo.git` for Cymbal Shop).
   - `app_version` *(optional)*: Upstream release tag or branch to clone and deploy. If omitted, the default defined in the example's `variables.tf` is used (e.g., `"v0.6.9"` for Cymbal Bank or `"v0.10.5"` for Cymbal Shop).

#### Network Connectivity Center (NCC) Configuration

To connect the cluster VPC to an existing Network Connectivity Center Hub via a VPC spoke, configure the `ncc_config` object in `global.tfvars`:

```hcl
ncc_config = {
  enable_ncc                  = true
  hub_uri                     = "projects/YOUR_HUB_PROJECT/locations/global/hubs/YOUR_HUB_NAME"
  spoke_group                 = "default"
  spoke_name                  = "vpc-spoke"
  spoke_description           = "NCC Spoke for standalone cluster network"
  spoke_labels                = { env = "dev" }
  spoke_exclude_export_ranges = []
  spoke_include_export_ranges = []
}
```

* `enable_ncc`: (bool) Toggles whether to create the NCC spoke.
* `hub_uri`: (string) The full resource URI of the target NCC Hub. Required when `enable_ncc` is `true`.
* `spoke_group`: (string) The NCC group the spoke belongs to (defaults to `"default"`).
* `spoke_name`: (string) The name for the VPC spoke (defaults to `"vpc-spoke"`).
* `spoke_description`: (string, optional) Description for the spoke.
* `spoke_labels`: (map, optional) Key-value pairs for spoke labels.
* `spoke_exclude_export_ranges`: (list of strings, optional) IP CIDR ranges to exclude from route export.
* `spoke_include_export_ranges`: (list of strings, optional) IP CIDR ranges to explicitly export.


### Application default credentials

1. Configure Application Default Credentials:

    ```bash
    gcloud auth application-default login
    ```

2. Set the billing quota project in the `gcloud` configuration:

    ```bash
    gcloud config set billing/quota_project <QUOTA-PROJECT>
    ```

### Run the helper

1. Install the helper binary:

    ```bash
    cd helpers/eab-deployer
    go install
    ```

2. Validate your `global.tfvars` file and dependencies:

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file /path/to/global.tfvars -validate
    ```

3. Run the helper to deploy:

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file /path/to/global.tfvars
    ```

### Choosing Which Example to Deploy

By default, the helper deploys `default-example` (located in `examples/default-example/standalone-single-project`).

Use the `-example` flag to choose another example:

- **Default Hello World example:**

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file /path/to/global.tfvars -example default-example
    ```

- **Cymbal Bank example:**

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file /path/to/global.tfvars -example cymbal-bank
    ```

- **Cymbal Shop example:**

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file /path/to/global.tfvars -example cymbal-shop
    ```

- **Agent example:**

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file /path/to/global.tfvars -example agent
    ```

- **LLM Model example:**

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file /path/to/global.tfvars -example llm-model
    ```

- **Destroy the deployment:**

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file /path/to/global.tfvars -destroy
    ```

### Supported flags

```text
  -tfvars_file file
        Full path to the Terraform .tfvars file with the configuration to be used.
  -example name
        Name of the example to deploy (default "default-example").
  -steps_file file
        Path to the steps file used to save progress. (default ".steps.json")
  -list_steps
        List the existing steps.
  -reset_step step
        Name of a step to be reset. The step will be marked as pending.
  -validate
        Validate tfvars file inputs and local dependencies.
  -quiet
        If true, additional output is suppressed.
  -disable_prompt
        Disable interactive prompt.
  -destroy
        Destroy the deployment.
  -help
        Prints this help text and exits.
```

## Troubleshooting

See [Troubleshooting](../../docs/TROUBLESHOOTING.md) if you encounter issues during deployment.
