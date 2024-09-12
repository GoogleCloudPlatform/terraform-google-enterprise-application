# 3. Fleet Scope phase

The Fleet Scope phase defines the resources used to create the GKE Fleet Scopes, Fleet namespaces, and some Fleet features.

## Purpose

This phase deploys the per-environment fleet resources deployed via the fleetscope infrastructure pipeline.

An overview of the fleet-scope  pipeline is shown below.
![Enterprise Application fleet-scope  diagram](../assets/eab-multitenant.png)

The following resources are created:

- Fleet scope
- Fleet namespace
- Cloud Source Repo
- Config Management
- Service Mesh
- Multicluster Ingress
- Multicluster Service

## Prerequisites

1. Provision of the per-environment folder, network project, network, and subnetwork(s).
1. 1-bootstrap phase executed successfully.
1. 2-multitenant phase executed successfully.

## Usage

### Running Terraform locally

1. The next instructions assume that you are in the `terraform-google-enterprise-application/3-fleetscope` folder.

   ```bash
   cd ../3-fleetscope
   ```

1. Rename `terraform.example.tfvars` to `terraform.tfvars`.

   ```bash
   mv terraform.example.tfvars terraform.tfvars
   ```

1. Update the `namespace_ids` variables with Google Groups respective to each namespace/team.

1. Use `terraform output` to get the state bucket value from 1-bootstrap output and replace the placeholder in `terraform.tfvars`.

   ```bash
   export remote_state_bucket=$(terraform -chdir="../1-bootstrap/" output -raw state_bucket)

   echo "remote_state_bucket = ${remote_state_bucket}"

   sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" ./terraform.tfvars
   ```

1. Update the file with values for your environment. See any of the envs folder [README.md](./envs/production/README.md#inputs) files for additional information on the values in the `terraform.tfvars` file.

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
