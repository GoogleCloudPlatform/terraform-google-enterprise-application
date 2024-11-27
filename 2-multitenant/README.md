# 2. Multitenant Infrastructure phase

## Purpose

This phase deploys the per-environment multitenant resources deployed via the multitenant infrastructure pipeline.

An overview of the multitenant infrastructure pipeline is shown below.
![Enterprise Application multitenant infrastructure diagram](../assets/eab-multitenant.png)

The following resources are created:

- GCP Project (cluster project)
- GKE cluster(s)
- Cloud Armor
- App IP addresses (see below for details)

## Prerequisites

1. Provision of the per-environment folder, network project, network, and subnetwork(s).
1. 1-bootstrap phase executed successfully.

## Usage

### Deploying with Google Cloud Build

The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

> NOTE: If you don't have the foundation codebase, you can clone it by running the following command: `git clone --branch v4.1.0 https://github.com/terraform-google-modules/terraform-example-foundation.git`

Please note that some steps in this documentation are specific to the selected Git provider. These steps are clearly marked at the beginning of each instruction. For example, if a step applies only to GitHub users, it will be labeled with "(GitHub only)."

1. Retrieve Multi-tenant administration project variable value from 1-bootstrap:

    ```bash
    export multitenant_admin_project=$(terraform -chdir=./terraform-google-enterprise-application/1-bootstrap output -raw project_id)

    echo multitenant_admin_project=$multitenant_admin_project
    ```

1. (CSR Only) Clone the infrastructure pipeline repository:

    ```bash
    gcloud source repos clone eab-multitenant --project=$multitenant_admin_project
    ```

1. (Github Only) When using Github with Cloudbuild, clone the repository with the following command.

    ```bash
    git clone git@github.com:<GITHUB-OWNER or ORGANIZATION>/eab-multitenant.git
    ```

1. Initialize the git repository, copy `2-multitenant` code into the repository, cloudbuild yaml files and terraform wrapper script:

    ```bash
    cd eab-multitenant
    git checkout -b plan

    cp -r ../terraform-google-enterprise-application/2-multitenant/* .
    cp ../terraform-example-foundation/build/cloudbuild-tf-* .
    cp ../terraform-example-foundation/build/tf-wrapper.sh .
    chmod 755 ./tf-wrapper.sh

    cp -RT ../terraform-example-foundation/policy-library/ ./policy-library
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' cloudbuild-tf-*
    ```

1. Disable all policies validation:

    ```bash
    rm -rf policy-library/policies/constraints/*
    ```

1. Rename `terraform.example.tfvars` to `terraform.tfvars`.

    ```bash
    mv terraform.example.tfvars terraform.tfvars
    ```

1. Update the file with values for your environment. See any of the envs folder
[README.md](./envs/production/README.md#inputs) files for additional information
on the values in the `terraform.tfvars` file. In addition to `envs` from
prerequisites, each App must have it's own entry under `apps` with a list of any
dedicated IP address to be provisioned. For the default hello world example, use the following values

    ```terraform
    apps = {
      "default-example" : {
        "acronym" = "de",
      }
    }
    ```

1. Commit and push changes. Because the plan branch is not a named environment branch, pushing your plan branch triggers terraform plan but not terraform apply. Review the plan output in your Cloud Build project. https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git add .
    git commit -m 'Initialize multitenant repo'
    git push --set-upstream origin plan
    ```

1. Merge changes to development. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git checkout -b development
    git push origin development
    ```

1. Merge changes to nonproduction. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git checkout -b nonproduction
    git push origin nonproduction
    ```

1. Merge changes to production. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git checkout -b production
    git push origin production
    ```

### Running Terraform locally

1. The next instructions assume that you are in the `terraform-google-enterprise-application/2-multitenant` folder.

   ```bash
   cd ../2-multitenant
   ```

1. Rename `terraform.example.tfvars` to `terraform.tfvars`.

   ```bash
   mv terraform.example.tfvars terraform.tfvars
   ```

1. Update the file with values for your environment. See any of the envs folder
[README.md](./envs/production/README.md#inputs) files for additional information
on the values in the `terraform.tfvars` file. In addition to `envs` from
prerequisites, each App must have it's own entry under `apps` with a list of any
dedicated IP address to be provisioned.

  ```terraform
  apps = {
    "my-app" : {
      "ip_address_names" : [
        "my-app-ip",
      ]
      "certificates" : {
        "my-app-cert" : ["my-domain"]
      }
    }
  }
  ```

You can now deploy each of your environments (e.g. production).

1. Run `init` and `plan` and review the output.

   ```bash
   terraform -chdir=./envs/production init
   terraform -chdir=./envs/production plan
   ```

1. Run `apply production`.

   ```bash
   terraform -chdir=./envs/production apply
   ```

If you receive any errors or made any changes to the Terraform config or `terraform.tfvars`, re-run `terraform -chdir=./envs/production plan` before you run `terraform -chdir=./envs/production apply`.

1. Repeat the same series of terraform commands but replace `-chdir=./envs/production` with `-chdir=./envs/nonproduction` to deploy the nonproduction environment.

1. Repeat the same series of terraform commands but replace `-chdir=./envs/production` with `-chdir=./envs/development` to deploy the development environment.
