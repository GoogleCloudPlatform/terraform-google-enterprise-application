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

### Configuring Git Access for Config Sync Repository

With [Config Sync](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/overview), you can manage Kubernetes resources with configuration files stored in a source of truth. Config Sync supports Git repositories, that are used as the source of truth in this example.

Config Sync is installed in this step when running the Terraform code. Before installing, you must grant access to Git.

Config Sync supports the following mechanisms for authentication:

* SSH key pair (ssh)
* Cookiefile (cookiefile)
* Token (token)
* Google service account (gcpserviceaccount)
* Compute Engine default service account (gcenode)
* GitHub App (githubapp)

The example below shows configuration steps for the `token` mechanism, using Gitlab as the Git provider, for more information please check the [following documentation](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync).

#### Git access: Gitlab using Token

After you create and obtain the personal access token in Gitlab, add it to a new `Secret` in the cluster.

- (No HTTPS-Proxy) If you don't use an HTTPS proxy, create the `Secret` with the following command:

    ```bash
    kubectl create ns config-management-system && \
    kubectl create secret generic git-creds \
    --namespace="config-management-system" \
    --from-literal=username=USERNAME \
    --from-literal=token=TOKEN
    ```

    Replace the following:

    - `USERNAME`: the username that you want to use.
    - `TOKEN`: the token that you created in the previous step.

- (HTTPS-Proxy) If you need to use an HTTPS proxy, add it to the `Secret` together with username and token by running the following command:

    ```bash
    kubectl create ns config-management-system && \
    kubectl create secret generic git-creds \
    --namespace=config-management-system \
    --from-literal=username=USERNAME \
    --from-literal=token=TOKEN \
    --from-literal=https_proxy=HTTPS_PROXY_URL
    ```

    Replace the following:

    - `USERNAME`: the username that you want to use.
    - `TOKEN`: the token that you created in the previous step.
    - `HTTPS_PROXY_URL`: the URL for the HTTPS proxy that you use when communicating with the Git repository.

> NOTE: Config Sync must be able to fetch your Git server, this means you might need to adjust your firewall rules to allow GKE pods to reach that server or create a Cloud NAT Router to allow accessing the Github/Gitlab or Bitbucket SaaS servers.

## Usage

### Deploying with Google Cloud Build

The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

Please note that some steps in this documentation are specific to the selected Git provider. These steps are clearly marked at the beginning of each instruction. For example, if a step applies only to GitHub users, it will be labeled with "(GitHub only)."

1. Retrieve Multi-tenant administration project variable value from 1-bootstrap:

    ```bash
    export multitenant_admin_project=$(terraform -chdir=./terraform-google-enterprise-application/1-bootstrap output -raw project_id)

    echo multitenant_admin_project=$multitenant_admin_project
    ```

1. (CSR Only) Clone the infrastructure pipeline repository:

    ```bash
    gcloud source repos clone eab-fleetscope --project=$multitenant_admin_project
    ```

1. (Github Only) When using Github with Cloud Build, clone the repository with the following command.

    ```bash
    git clone git@github.com:<GITHUB-OWNER or ORGANIZATION>/eab-fleetscope.git
    ```

1. (Gitlab Only) When using Gitlab with Cloud Build, clone the repository with the following command.

    ```bash
    git clone git@gitlab.com:<GITLAB-GROUP or ACCOUNT>/eab-fleetscope.git
    ```

1. Initialize the git repository, copy `3-fleetscope` code into the repository, Cloud Build yaml files and terraform wrapper script:

    ```bash
    cd eab-fleetscope
    git checkout -b plan

    cp -r ../terraform-google-enterprise-application/3-fleetscope/* .
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

1. Use `terraform output` to get the state bucket value from 1-bootstrap output and replace the placeholder in `terraform.tfvars`.

   ```bash
   export remote_state_bucket=$(terraform -chdir="../terraform-google-enterprise-application/1-bootstrap/" output -raw state_bucket)

   echo "remote_state_bucket = ${remote_state_bucket}"

   sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" ./terraform.tfvars
   ```

1. Update the `terraform.tfvars` file with values for your environment.

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
