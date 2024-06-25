# 2. Multitenant Infrastructure phase

## Purpose

This phase deploys the per-environment multitenant resources deployed via the multitenant infrastructure pipeline.

An overview of the multitenant infrastructure pipeline is shown below.
![Enterprise Application multitenant infrastructure diagram](assets/eab-multitenant.png)

The following resources are created:
- GCP Project (cluster project)
- GKE cluster(s)
- Cloud Armor
- App IP addresses (see below for details)

## Prerequisites

1. Provision of the per-environment folder, network project, network, and subnetwork(s).
1. 1-bootstrap phase executed successfully.

## Usage

### Running Terraform locally

1. The next instructions assume that you are in the `terraform-google-enterprise-application/3-appfactory` folder.

   ```bash
   cd terraform-google-enterprise-application/3-appfactory
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

  ```
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
   terraform init -chdir=./envs/production
   terraform plan -chdir=./envs/production
   ```

1. Run `apply production`.

   ```bash
   terraform apply -chdir=./envs/production
   ```

If you receive any errors or made any changes to the Terraform config or `terraform.tfvars`, re-run `terraform plan -chdir=./envs/production` before you run `terraform apply -chdir=./envs/production`.
