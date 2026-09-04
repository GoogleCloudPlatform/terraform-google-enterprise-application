# Enterprise Application Blueprint Deploy Helper

Helper tool to deploy Enterprise Application Blueprint examples (including `standalone-single-project` architectures) using Terraform, Cloud Build, and Cloud Deploy.

## Requirements

- [Go](https://go.dev/doc/install) 1.23 or later
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
   - `eab_code_path`: The full path to your local `terraform-google-enterprise-application` repository.
   - `code_checkout_path`: The full path to your working `deploy-directory`.
   - `project_id`: Your Google Cloud project ID.
   - `region`: Google Cloud region for deployment.

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

- **Agent example:**

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file /path/to/global.tfvars -example agent
    ```

- **LLM Model example:**

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file /path/to/global.tfvars -example llm-model
    ```

- **Standalone Single Project (top-level):**

    ```bash
    $HOME/go/bin/eab-deployer -tfvars_file /path/to/global.tfvars -example standalone_single_project
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
