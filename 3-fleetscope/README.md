# 3. Fleet Scope phase

The Fleet Scope phase defines the resources used to create the GKE Fleet Scopes, Fleet namespaces, and some Fleet features.

<table>
<tbody>
<tr>
<td><a href="../1-bootstrap">1-bootstrap</a></td>
<td>Bootstraps streamlines the bootstrapping process for Enterprise Applications on Google Cloud Platform (GCP)</td>
</tr>
<tr>
<td><a href="../2-multitenant">2-multitenant</a></td>
<td>Deploys GKE clusters optimized for multi-tenancy within an enterprise environment.</td>
</tr>
<tr>
<td>3-fleetscope (this file)</td>
<td>Set-ups Google Cloud Fleet, enabling centralized management of multiple Kubernetes clusters.</td>
</tr>
<tr>
<td><a href="../4-appfactory">4-appfactory</a></td>
<td>Sets up infrastructure and CI/CD pipelines for a single application or microservice on Google Cloud</td>
</tr>
<tr>
<td><a href="../5-appinfra">5-appinfra</a></td>
<td>Set up application infrastructure pipeline aims to establish a streamlined CI/CD workflow for applications, enabling automated deployments to multiple environments (GKE clusters).</td>
</tr>
<tr>
<td><a href="../6-appsource">6-appsource</a></td>
<td>Deploys a modified version of a [simple example](https://github.com/GoogleContainerTools/skaffold/tree/main/examples/getting-started) for skaffold.</td>
</tr>
</tbody>
</table>

## Purpose

This phase deploys the per-environment the setup and configuration of a Google Cloud Fleet, enabling centralized management of multiple Kubernetes clusters. It automates the creation of scopes and namespaces, enables features across the fleet, and configures necessary IAM permissions for services running within the clusters. This simplifies multi-cluster management and promotes consistent policy enforcement.

An overview of the fleet-scope  pipeline is shown below.

![Enterprise Application fleet-scope  diagram](../assets/eab-multitenant.png)

The following resources are created:

-   **GKE Hub Scope:** Creates GKE Hub scopes for each specified namespace.
-   **GKE Hub Namespace:** Creates GKE Hub namespaces within the defined scopes.
-   **GKE Hub Membership Binding:** Binds cluster memberships to the created scopes.
-   **GKE Hub Feature:** Enables features like Config Management (ACM), Service Mesh, Policy Controller (PoCo), Multi-cluster Ingress (MCI), and Multi-cluster Services (MCS) on the fleet.
-   **GKE Hub Feature Membership:** Associates the enabled features with specific cluster memberships.
-   **IAM Bindings:** Grants IAM roles to service accounts, allowing them to create traces, send metrics, access logging views, and manage service mesh configurations.
-   **Binary Authorization Attestor and Policy:** Configures Binary Authorization to ensure that only attested images are deployed to the cluster.
-   **Google Cloud Source Repository (Optional):** Creates a Cloud Source Repository for Config Sync if `config_sync_secret_type` is set to `gcpserviceaccount`.
-   **Kueue Private Installation (Optional):** Installs Kueue, a Kubernetes-native job management system, for private use within the fleet.
-   **Fleet App Operator Permissions:** Grants operator permissions within the fleet.

## Prerequisites

1. Provision of the per-environment folder, network project, network, and subnetwork(s).
1. 1-bootstrap phase executed successfully.
1. 2-multitenant phase executed successfully.

### Workspace groups

For each namespace being created, you will need a Workspace group email previously created. You can find more information [here](https://developers.google.com/workspace/admin/directory/v1/guides/manage-groups#create_group).

The code will grant ADMIN permission for each group email to the namespace created.

```hcl
namespace_ids = {
  "cb-frontend" = "your-frontend-group@yourdomain.com",
  "cb-accounts" = "your-accounts-group@yourdomain.com",
  "cb-ledger"   = "your-ledger-group@yourdomain.com"
}
```

### KMS key for attestation

You will need to provide a [PKIK KMS Key](https://cloud.google.com/binary-authorization/docs/creating-attestors-console#create_a_pkix_key_pair) to be used by the attestor.

### Configuring Git Access for Config Sync Repository

With [Config Sync](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/overview), you can manage Kubernetes resources with configuration files stored in a source of truth. Config Sync supports Git repositories, that are used as the source of truth in this example.

Config Sync is installed in this step when running the Terraform code. Before installing, you must grant access to Git.

Config Sync supports the following mechanisms for authentication:

- SSH key pair (ssh)
- Cookiefile (cookiefile)
- Token (token)
- Google service account (gcpserviceaccount)
- Compute Engine default service account (gcenode)
- GitHub App (githubapp)

The example below shows configuration steps for the `token` mechanism, using Gitlab as the Git provider, for more information please check the [following documentation](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync).

#### Git access: Gitlab/Github using Token

After you create and obtain the personal access token in Gitlab/Github, add it to a new `Secret` in each cluster for each environment.

- Get Cluster names on 2-multitenant output for each environment:

    ```bash
    terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/development" init
    export cluster_dev_project=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/development" output -raw cluster_project)
    export membership_dev_1=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/development" output -json cluster_names | jq -r '.[0]')
    export region_dev_1=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/development" output -json cluster_regions | jq -r '.[0]')

    export membership_dev_2=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/development" output -json cluster_names | jq -r '.[1]')
    export region_dev_2=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/development" output -json cluster_regions | jq -r '.[1]')
    ```

- Get your cluster credentials for the first region:

    ```bash
     gcloud container hub memberships get-credentials ${membership_dev_1} --location ${region_dev_1} --project ${cluster_dev_project}
     ```

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

- Get your cluster credentials for the second region:

    ```bash
     gcloud container hub memberships get-credentials ${membership_dev_2} --location ${region_dev_2} --project ${cluster_dev_project}
     ```

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


    ```bash
    terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/nonproduction" init
    export cluster_nonprod_project=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/nonproduction" output -raw cluster_project)
    export membership_nonprod_1=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/nonproduction" output -json cluster_names | jq -r '.[0]')
    export region_nonprod_1=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/nonproduction" output -json cluster_regions | jq -r '.[0]')

    export membership_nonprod_2=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/nonproduction" output -json cluster_names | jq -r '.[1]')
    export region_nonprod_2=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/nonproduction" output -json cluster_regions | jq -r '.[1]')
    ```

- Get your cluster credentials for the first region:

    ```bash
     gcloud container hub memberships get-credentials ${membership_nonprod_1} --location ${region_nonprod_1} --project ${cluster_nonprod_project}
     ```

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

- Get your cluster credentials for the second region:

    ```bash
     gcloud container hub memberships get-credentials ${membership_nonprod_2} --location ${region_nonprod_2} --project ${cluster_nonprod_project}
     ```

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


    ```bash
    terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/production" init
    export cluster_prod_project=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/production" output -raw cluster_project)
    export membership_prod_1=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/production" output -json cluster_names | jq -r '.[0]')
    export region_prod_1=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/production" output -json cluster_regions | jq -r '.[0]')

    export membership_prod_2=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/production" output -json cluster_names | jq -r '.[1]')
    export region_prod_2=$(terraform -chdir="../terraform-google-enterprise-application/2-multitenant/envs/production" output -json cluster_regions | jq -r '.[1]')
    ```

- Get your cluster credentials for the first region:

    ```bash
     gcloud container hub memberships get-credentials ${membership_prod_1} --location ${region_prod_1} --project ${cluster_prod_project}
     ```

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

- Get your cluster credentials for the second region:

    ```bash
     gcloud container hub memberships get-credentials ${membership_prod_2} --location ${region_prod_2} --project ${cluster_prod_project}
     ```

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

### Important Considerations:

- __namespace_ids:__ This map defines the namespaces to be created in the fleet, along with the Google Group email address associated with each team/namespace.
- __cluster_membership_ids:__ Ensure that these IDs are correct and that the clusters are properly registered with the GKE Hub.
- __Workload Identity:__ Make sure Workload Identity is enabled on your GKE clusters.
- __Config Sync:__ If using `gcpserviceaccount` for `config_sync_secret_type`, the module will create a Cloud Source Repository. Otherwise, you must provide a valid `config_sync_repository_url`.
- __Binary Authorization:__ The attestation_kms_key must be a valid KMS key with appropriate permissions.
- __Kueue:__ If enable_kueue is set to true, ensure that the `private_install_manifest` module is available (as indicated by `source = "../private_install_manifest"`).


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
   sed -i'' -e "s/UPDATE_ME/${remote_state_bucket}/" ./*/*/backend.tf
   ```

1. Update the `terraform.tfvars` file with values for your environment.

1. Commit and push changes. Because the plan branch is not a named environment branch, pushing your plan branch triggers terraform plan but not terraform apply. Review the plan output in your Cloud Build project. <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git add .
    git commit -m 'Initialize fleetscope repo'
    git push --set-upstream origin plan
    ```

1. Merge changes to development. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout -b development
    git push origin development
    ```

1. Merge changes to nonproduction. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout -b nonproduction
    git push origin nonproduction
    ```

1. Merge changes to production. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

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
   sed -i'' -e "s/UPDATE_ME/${remote_state_bucket}/" ./*/*/backend.tf
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

## Namespace Network-Level Isolation Example

Namespace network isolation is an aspect of Kubernetes security that helps to limit the access of different services and components within the cluster. You can find an example namespace isolation using Network Policies for Cymbal Bank. This example will enforce the following:

- Namespaces pods will deny all ingress traffic.
- Namespaces pods will allow all egress traffic.
- Frontend namespace will allow ingress traffic.
- Cymbal-Bank example namespaces will be able to communicate with each other by allowing ingress from the necessary specific namespaces.

### Use Config Sync for Network Policies

To use `config-sync` you will need to clone you config-sync repository and add the policies there. Commit it and wait for the next sync. Here is a detailed tutorial on [how to setup network policies with config-sync](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/fleet-tenancy#set-up-source). The steps below will show an example for [cymbal-bank](../examples/cymbal-bank) application.

1. Clone `config-sync` repository.

    ```bash
    git clone https://YOUR-GIT-INSTANCE/YOUR-NAMESPACE/config-sync-development.git
    ```

1. Checkout to sync branch:

    ```bash
    cd config-sync-development
    git checkout master
    ```

1. Copy example policies from `terraform-google-enterprise-applicaiton` repository to the `config-sync` repository (development environment):

    ```bash
    cp ../terraform-google-enterprise-applicaiton/examples/cymbal-bank/3-fleetscope/config-sync/development/cymbal-bank-network-policies-development.yaml .
    ```

1. Commit and push changes:

    ```bash
    git add .
    git commit -am "Add cymbal bank network policies - development"
    git push origin master
    ```

1. Wait until the resources are synced. You can check status by using `nomos` command line. This requires you having your `kubeconfig` configured to connect to the cluster. Or by accessing the Config Management Console on [https://console.cloud.google.com/kubernetes/config_management/dashboard](https://console.cloud.google.com/kubernetes/config_management/dashboard).

    ```bash
    nomos status
    ```

    > NOTE: For more information on nomos command line, see this [documentation](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/nomos-command)

For more information on namespace isolation options see this [documentation](../docs/namespace_isolation.md).

### Policy Controller

For more information on Policies, refer to the [following documentation](../docs/opa_policies.md)
