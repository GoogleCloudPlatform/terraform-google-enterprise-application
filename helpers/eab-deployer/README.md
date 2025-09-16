# Enterprise Application Blueprint deploy helper

Helper tool to deploy the Enterprise Application Blueprint using Cloud Build and Cloud Source repositories.

## Usage

## Requirements

- [Go](https://go.dev/doc/install) 1.22 or later
- [Google Cloud SDK](https://cloud.google.com/sdk/install) version 393.0.0 or later
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) version 2.28.0 or later
- [Terraform](https://www.terraform.io/downloads.html) version 1.5.7 or later
- See `1-bootstrap` README for additional IAM [requirements](../../1-bootstrap/README.md#prerequisites) on the user deploying the Foundation.
- To enable Security Command Center, choose a Security Command Center tier and create and grant permissions for the Security Command Center service account as described in [Setting up Security Command Center](https://cloud.google.com/security-command-center/docs/quickstart-security-command-center).

Your environment need to use the same [Terraform](https://www.terraform.io/downloads.html) version used on the build pipeline.
Otherwise, you might experience Terraform state snapshot lock errors.

Version 1.5.7 is the last version before the license model change. To use a later version of Terraform, ensure that the Terraform version used in the Operational System to manually execute part of the steps in `3-networks` and `4-projects` is the same version configured in the following code

- 1-bootstrap/modules/jenkins-agent/variables.tf
   ```
   default     = "1.5.7"
   ```

- 1-bootstrap/cb.tf
   ```
   terraform_version = "1.5.7"
   ```

- scripts/validate-requirements.sh
   ```
   TF_VERSION="1.5.7"
   ```

- build/github-tf-apply.yaml
   ```
   terraform_version: '1.5.7'
   ```

- github-tf-pull-request.yaml

   ```
   terraform_version: "1.5.7"
   ```

- 1-bootstrap/Dockerfile
   ```
   ARG TERRAFORM_VERSION=1.5.7
   ```

### Validate required tools

- Check if required tools, Go 1.22.0+, Terraform 1.5.7+, gcloud 393.0.0+, and Git 2.28.0+, are installed:

    ```bash
    go version

    terraform -version

    gcloud --version

    git --version
    ```

- check if required components of `gcloud` are installed:

    ```bash
    gcloud components list --filter="id=beta OR id=terraform-tools"
    ```

- Follow the instructions in the output of the command if components `beta` and `terraform-tools` are not installed to install them.

### Prepare the deploy environment

- Create a directory in the file system to host the Cloud Source repositories the will be created and a copy of the Enterprise Application Blueprint.
- Clone the `terraform-example-foundation` repository on this directory.

    ```text
    deploy-directory/
    └── terraform-example-foundation
    ```

- Copy the file [global.tfvars.example](./global.tfvars.example) as `global.tfvars` to the same directory.

    ```text
    deploy-directory/
    └── global.tfvars
    └── terraform-example-foundation
    ```

- Update `global.tfvars` with values from your environment.
- The `1-bootstrap` README [prerequisites](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/blob/main/1-bootstrap/README.md#prerequisites)  section has additional prerequisites needed to run this helper.
- Variable `code_checkout_path` is the full path to `deploy-directory` directory.
- Variable `foundation_code_path` is the full path to `terraform-example-foundation` directory.
- See the READMEs for the stages for additional information:
  - [1-bootstrap](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/blob/main/1-bootstrap/README.md)
  - [2-multitenant](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/blob/main/2-multitenant/README.md)
  - [3-fleetscope](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/blob/main/3-fleetscope/README.md)
  - [4-appfactory](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/blob/main/4-appfactory/README.md)
  - [5-appinfra](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/blob/main/5-appinfra/README.md)
  - [6-appsource](https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/blob/main/6-appsource/hello-world/README.md)

### Location

By default the foundation regional resources are deployed in `us-west1` and `us-central1` regions and multi-regional resources are deployed in the `US` multi-region.

In addition to the variables declared in the file `global.tfvars` for configuring location, there are two locals, `default_region1` and `default_region2`, in each one of the environments (`production`, `nonproduction`, and `development`) in the network steps (`3-networks-svpc` and `3-networks-hub-and-spoke`).
They are located in the [main.tf](../../3-networks-svpc/envs/production/main.tf#L20-L21) files for each environments.
Change the two locals **before** starting the deployment to deploy in other regions.

**Note:** the region used for the variable `default_region` in the file `global.tfvars` **MUST** be one of the regions used for the `default_region1` and `default_region2` locals.

### Application default credentials

- Set the billing quota project in the `gcloud` configuration

    ```
    gcloud config set billing/quota_project <QUOTA-PROJECT>

    gcloud services enable \
    "cloudresourcemanager.googleapis.com" \
    "iamcredentials.googleapis.com" \
    "cloudbuild.googleapis.com" \
    "securitycenter.googleapis.com" \
    "accesscontextmanager.googleapis.com" \
    --project <QUOTA-PROJECT>
    ```

- Configure [Application Default Credentials](https://cloud.google.com/sdk/gcloud/reference/auth/application-default/login)

    ```bash
    gcloud auth application-default login
    ```

### Run the helper

- Install the helper:

    ```bash
    go install
    ```

- Validate the tfvars file.

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file <PATH TO 'global.tfvars' FILE> -validate
    ```

- Run the helper:

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file <PATH TO 'global.tfvars' FILE>
    ```

- To Suppress additional output use:

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file <PATH TO 'global.tfvars' FILE> -quiet
    ```

- To destroy the deployment run:

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file <PATH TO 'global.tfvars' FILE> -destroy
    ```

- After deployment:

    ```text
    deploy-directory/
    └── gcp-multitenant
    └── gcp-fleetscope
    └── gcp-appfactory
    └── hello-world-admin
    └── hello-world-i-r
    └── global.tfvars
    └── terraform-google-enterprise-application
    ```

### Supported flags

```bash
  -tfvars_file file
        Full path to the Terraform .tfvars file with the configuration to be used.
  -steps_file file
        Path to the steps file to be used to save progress. (default ".steps.json")
  -list_steps
        List the existing steps.
  -reset_step step
        Name of a step to be reset. The step will be marked as pending.
  -validate
        Validate tfvars file inputs
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

See [troubleshooting](../../docs/TROUBLESHOOTING.md) if you run into issues during this deploy.
