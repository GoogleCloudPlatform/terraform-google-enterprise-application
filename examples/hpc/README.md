# HPC Examples

This example shows how to deploy a High-Performance Computing (HPC) environment for batch jobs using the infrastructure created by the [Enterprise Application blueprint](https://cloud.google.com/architecture/enterprise-application-blueprint). It demonstrates the utilization of `kueue` to manage multi-team batch jobs.

The primary use case demonstrated is a Financial Analysis using Monte Carlo Simulations, adapted from [Google Cloud Platform's Risk and Research Blueprints](https://github.com/GoogleCloudPlatform/risk-and-research-blueprints/tree/main/examples/research/monte-carlo).

## Pre-Requisites (Infrastructure)

This example requires the following blueprint phases to be executed successfully:
1. `1-bootstrap`
2. `2-multitenant`
3. `3-fleetscope`

## Additional HPC Requirements

Before deploying the infrastructure, ensure the following requirements are met for your target cluster.

1.  **Kueue Installation**
    `Kueue` is a K8s-native Job Queueing system. If your cluster has network access to `registry.k8s.io`, you can install it directly.

    *   **Option 1 (Cluster with NAT):** Install Kueue by running:
        ```bash
        kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.10.1/manifests.yaml
        ```
        Wait for the installation to complete:
        ```bash
        kubectl wait deploy/kueue-controller-manager -nkueue-system --for=condition=available --timeout=5m
        ```

    *   **Option 2 (Private Cluster without NAT):** Install Kueue by following the tutorial for [Artifact Registry Remote Repositories](../../docs/remote_repository_kueue_installation.md).

2.  **Cluster Toolkit (gcluster)**
    This guide assumes `gcluster` is installed. For setup instructions, see the [official documentation](https://cloud.google.com/cluster-toolkit/docs/setup/configure-environment#local-shell).

3.  **Kubectl Connection**
    Ensure you can connect to your cluster. For private clusters, you can use Connect Gateway.
    ```bash
    gcloud container fleet memberships get-credentials CLUSTER-NAME --project=YOUR-CLUSTER-PROJECT --location=YOUR-CLUSTER-REGION
    ```

## Usage (IaC Deployment)

This section details the Infrastructure as Code deployment, which should be performed before running the HPC jobs. The steps below assume you are deploying via Cloud Build.

### Deploying with Google Cloud Build

The steps below assume that you are in a directory containing both the `terraform-google-enterprise-application` and `terraform-example-foundation` repositories.

#### 1. Add HPC namespaces at Fleetscope repository

1.  Navigate to your `3-fleetscope` repository and add the `hpc-team-a` and `hpc-team-b` namespaces to `terraform.tfvars`:

    ```hcl
    namespace_ids = {
         "hpc-team-a"     = "your-hpc-team-a-group@yourdomain.com",
         "hpc-team-b"     = "your-hpc-team-b-group@yourdomain.com",
         ...
    }
    ```

2.  Commit and push the changes to a named environment branch (`development`, `nonproduction`, or `production`) to trigger the Cloud Build pipeline and apply the changes.

#### 2. Add HPC envs at App Factory

1.  Navigate to your `4-appfactory` repository. The example file at `examples/hpc/4-appfactory/terraform.tfvars` shows how to configure the projects for `hpc-team-a` and `hpc-team-b`. Update your main `terraform.tfvars` file accordingly:

    ```hcl
    applications = {
      "hpc" = {
        "hpc-team-a" = {
          create_infra_project = true
          create_admin_project = true
        },
        "hpc-team-b" = {
          create_infra_project = true
          create_admin_project = true
        }
      }
    }

    cloudbuildv2_repository_config = {
      # ... (your existing Git provider config)
      repositories = {
        "hpc-team-a" = {
          repository_name = "hpc-team-a-i-r"
          repository_url  = "UPDATE_WITH_YOUR_GIT_REPO_URL_A"
        },
        "hpc-team-b" = {
          repository_name = "hpc-team-b-i-r"
          repository_url  = "UPDATE_WITH_YOUR_GIT_REPO_URL_B"
        }
        # ... other repositories
      }
    }
    ```

2.  Commit and push your changes to a named branch to apply the modifications.

#### 3. Add HPC envs at App Infra

1.  Retrieve team repository and project information created by the `4-appfactory` stage. From your `eab-applicationfactory` directory, run:

    ```bash
    cd envs/shared/
    terraform init

    # Retrieve outputs for Team A
    export hpc_team_a_project=$(terraform output -json app-group | jq -r '.["hpc.hpc-team-a"]["app_admin_project_id"]')
    echo hpc_team_a_project=$hpc_team_a_project
    export hpc_team_a_repository=$(terraform output -json app-group | jq -r '.["hpc.hpc-team-a"]["app_infra_repository_name"]')
    echo hpc_team_a_repository=$hpc_team_a_repository
    export hpc_team_a_statebucket=$(terraform output -json app-group | jq -r '.["hpc.hpc-team-a"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo hpc_team_a_statebucket=$hpc_team_a_statebucket

    # Retrieve outputs for Team B
    export hpc_team_b_project=$(terraform output -json app-group | jq -r '.["hpc.hpc-team-b"]["app_admin_project_id"]')
    echo hpc_team_b_project=$hpc_team_b_project
    export hpc_team_b_repository=$(terraform output -json app-group | jq -r '.["hpc.hpc-team-b"]["app_infra_repository_name"]')
    echo hpc_team_b_repository=$hpc_team_b_repository
    export hpc_team_b_statebucket=$(terraform output -json app-group | jq -r '.["hpc.hpc-team-b"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo hpc_team_b_statebucket=$hpc_team_b_statebucket

    cd ../../
    ```
2.  Get the remote state bucket from `1-bootstrap` to be used later.
    ```bash
    terraform -chdir="./terraform-google-enterprise-application/1-bootstrap/" init
    export remote_state_bucket=$(terraform -chdir="./terraform-google-enterprise-application/1-bootstrap/" output -raw state_bucket)
    echo "remote_state_bucket = ${remote_state_bucket}"
    ```
3.  Clone the newly created infrastructure repositories for each team.

    ```bash
    mkdir hpc-teams
    cd hpc-teams

    # (CSR Only)
    gcloud source repos clone $hpc_team_a_repository --project=$hpc_team_a_project
    gcloud source repos clone $hpc_team_b_repository --project=$hpc_team_b_project

    # (GitHub Only)
    # NOTE: Replace <GITHUB-OWNER or ORGANIZATION> with your actual GitHub owner or organization name.
    git clone https://github.com/<GITHUB-OWNER or ORGANIZATION>/$hpc_team_a_repository.git
    git clone https://github.com/<GITHUB-OWNER or ORGANIZATION>/$hpc_team_b_repository.git

    # (GitLab Only)
    # NOTE: Make sure to replace <GITLAB-GROUP or ACCOUNT> with your actual GitLab group or account name.
    git clone https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/$hpc_team_a_repository.git
    git clone https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/$hpc_team_b_repository.git
    ```

4.  Copy the Terraform code for each team repository and replace placeholders.

    ```bash
    # Remove existing modules directories
    rm -rf $hpc_team_a_repository/modules
    rm -rf $hpc_team_b_repository/modules
    cp -R ../terraform-google-enterprise-application/examples/hpc/5-appinfra/hpc/hpc-team-a/* $hpc_team_a_repository
    rm -rf $hpc_team_a_repository/modules
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules/ $hpc_team_a_repository
    cp ../../terraform-example-foundation/build/cloudbuild-tf-* $hpc_team_a_repository/
    cp ../../terraform-example-foundation/build/tf-wrapper.sh $hpc_team_a_repository/
    chmod 755 $hpc_team_a_repository/tf-wrapper.sh
    cp -RT ../../terraform-example-foundation/policy-library/ $hpc_team_a_repository/policy-library
    rm -rf $hpc_team_a_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $hpc_team_a_repository/cloudbuild-tf-*
    mv $hpc_team_a_repository/*/*/terraform.tfvars.example $hpc_team_a_repository/*/*/terraform.tfvars
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$hpc_team_a_statebucket/" $hpc_team_a_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $hpc_team_a_repository/*/*/terraform.tfvars

    cp -R ../terraform-google-enterprise-application/examples/hpc/5-appinfra/hpc/hpc-team-b/* $hpc_team_b_repository
    rm -rf $hpc_team_b_repository/modules
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules/ $hpc_team_b_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $hpc_team_b_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $hpc_team_b_repository/
    chmod 755 $hpc_team_b_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $hpc_team_b_repository/policy-library
    rm -rf $hpc_team_b_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $hpc_team_b_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$hpc_team_b_statebucket/" $hpc_team_b_repository/*/*/backend.tf
    mv $hpc_team_b_repository/*/*/terraform.tfvars.example $hpc_team_b_repository/*/*/terraform.tfvars
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $hpc_team_b_repository/*/*/terraform.tfvars
    ```

5.  Commit and push the infrastructure code for each team.

    ```bash
    cd $hpc_team_a_repository
    git checkout -b plan
    git add .
    git commit -m 'Initialize hpc-team-a repo'
    git push --set-upstream origin plan
    # Create and push environment branches as needed
    git checkout -b production && git push --set-upstream origin production
    cd ..

    cd $hpc_team_b_repository
    git checkout -b plan
    git add .
    git commit -m 'Initialize hpc-team-b repo'
    git push --set-upstream origin plan
    # Create and push environment branches as needed
    git checkout -b production && git push --set-upstream origin production
    cd ..
    ```

> **Note:** Unlike the Cymbal Bank example, the HPC use case does not have a separate "Application Source Code" pipeline. The application logic is deployed in the final step using the `gcluster` blueprint.

---

## Running the HPC Use Case

After the IaC deployment is complete, a Batch Administrator and the team members can proceed with the following steps.

### 1. Apply Kueue Resources (Admin Task)

A Batch Administrator must apply the Kueue resources (`ClusterQueue` and `LocalQueue`) once, after the namespaces have been created. These queues will be used to schedule the jobs.

```bash
# Ensure you have the manifests from the example directory
kubectl apply -f manifests/kueue-resources.yaml
```
### Usage

#### Permissions within the Developer Platform

The team members will run the code through a [Vertex AI Workbench Instance](https://cloud.google.com/vertex-ai/docs/workbench/instances/). They must have permission to connect to the instance and the instance will have permission to apply changes on their respective team namespace.

If the team member belongs to the `hpc-team` group defined in `3-fleetscope`, they will have `ADMIN` permissions on the namespace (see module `fleet_app_operator_permissions` on [3-fleetscope](../../3-fleetscope/modules/env_baseline/main.tf)).

If the team member wants to manage kubernetes resources outside the instance, the user will also need permission to connect to the cluster using ConnectGateway. For more information on managing ConnectGateway, refer to the following [documentation](https://cloud.google.com/kubernetes-engine/enterprise/multicluster-management/gateway/setup).

If the user lacks the necessary privileges to assign these permissions, they can submit a pull request (PR) to the 3-fleetscope repository. This will allow the relevant personnel in charge of the cluster to review and address the request. Basic Kubernetes RBAC roles can be assigned using terraform with the following [module](https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/tree/v36.0.2/modules/fleet-app-operator-permissions).

##### Examples PR's requesting permission assignment

For example, the user can open a PR to 3-fleetscope `terraform.tfvars` file adding an identity to the namespace ADMIN permissions.

```diff
additional_namespace_identities = {
+  "hpc-team-b" = ["vertex-ai-instance-sa@infra-project-id.iam.gserviceaccount.com"]
}
```

And add Terraform Code to assign ConnectGateway permissions:

```diff
+resource "google_project_iam_member" "compute_sa_roles" {
+  for_each = toset([
+    "roles/gkehub.connect",
+    "roles/gkehub.viewer",
+    "roles/gkehub.gatewayReader",
+    "roles/gkehub.scopeEditorProjectLevel"
+  ])
+  role    = each.key
+  project = var.fleet_project_id
+  member  = "serviceAccount:vertex-ai-instance-sa@infra-project-id.iam.gserviceaccount.com"
}
```

#### Set Project for gcloud Commands

```bash
gcloud config set project REPLACE_WITH_YOUR_INFRA_PROJECT
```

#### Run `gcluster` Blueprint

The `fsi-montecarlo-on-batch.yaml` file contains a blueprint that is deployed with `gcluster` (cluster-toolkit). It will create a notebook instance on the infrastructure project, alongs with the it's dependencies.

To deploy the blueprint, navigate to the source directory and run the following command, make sure you replace CLUSTER_NAME with your environment's cluster name, use your team infrastructure project that was created on 4-appfactory for the `PROJECT_ID`:

```bash
PROJECT_ID=REPLACE_WITH_YOUR_INFRA_PROJECT
CLUSTER_NAME=REPLACE_WITH_CLUSTER_NAME
CLUSTER_PROJECT=REPLACE_WITH_CLUSTER_PROJECT

~/cluster-toolkit/gcluster deploy fsi-montecarlo-on-batch.yaml --vars "project_id=$PROJECT_ID,cluster_name=$CLUSTER_NAME,cluster_project=$CLUSTER_PROJECT" --auto-approve
```

> NOTE: the example code is deployed for `hpc-team-b`. If you wish to deploy the example on `hpc-team-a` environment, you will need to adjust `settings.tpl.toml` and change the namespace and LocalQueue name.

#### Run the Simulation Jobs and Visualize the Results

##### Requisites before running

Before running the jobs, historical stocks data must be downloaded and uploaded to a bucket, which will then be used by the containers that run the batch jobs. This procedure allows isolating the container from the external network and running the simulation in a Secure environment.

You will find an auxiliary script on `helpers` directory named `download_data.py`. The script will use `yfinance` library to download stocks data and a Google Cloud Storage Python Client to upload this data in the required format for the application. Here is a step-by-step to download the data and upload it using the script.

**IMPORTANT**: The script must be run in an authenticated environment that has access to the internet. It will use Application Default Credentials (ADC) to authenticate with the bucket that was created on 5-appinfra stage.

1. Navigate to `helpers` directory.

1. Before running the Script, you will need to install the script dependencies, by running:

    ```bash
    pip install -r download_data_requirements.txt
    ```

1. A bucket is created in 5-appinfra stage and is passed as a flag (`--bucket_name=YOUR_BUCKET_NAME`) to the script, you should the bucket created on 5-appinfra for this purpose. The bucket follows the naming `${var.infra_project}-stocks-historical-data`. Alternatively, if you have access to the terraform state, you may also retrieve the bucket name by running `terraform -chdir="../../5-appinfra/envs/development" output -raw stocks_data_bucket_name`.

1. To download data for all tickers that will be used for the simulation, execute the script by running the following command:

    ```bash
    BUCKET_NAME=YOUR_BUCKET_NAME
    python3 dowload_data.py --bucket_name=$BUCKET_NAME
    ```

    > NOTE: Please be aware that the script processes a significant amount of stock data. As a result, it may take approximately 10 minutes to complete, depending on your machine's specifications and your network bandwidth.

After uploading the data to the bucket, you may proceed.

##### Follow the tutorial on the original repository

Follow the steps outlined in the following document, after the "Open the Vertex AI Workbench Notebook" section:

[Open the Vertex AI Workbench Notebook](github.com/GoogleCloudPlatform/risk-and-research-blueprints/tree/0e3134b8478f3ffaa12031d7fda3ac6b94e61b17/examples/research/monte-carlo#open-the-vertex-ai-workbench-notebook)

**IMPORTANT**: Your Vertex AI Workbench Instance will be located on the application infrastructure project that was created on 4-appfactory.

## Use Case 2: HPC AI Model Training with GPU (Team: `hpc-team-a`)

This use case is based on the following example: [Training with a Single GPU on Google Cloud](https://github.com/GoogleCloudPlatform/ai-on-gke/tree/main/tutorials-and-examples/gpu-examples/training-single-gpu).

### Step 1: Connect to the Cluster

Before proceeding, ensure that the user is a member of the `hpc-team-a` group and has the necessary permissions to connect using ConnectGateway:

- **roles/gkehub.connect**
- **roles/gkehub.viewer**
- **roles/gkehub.gatewayReader**

Once confirmed, execute the following command to connect to your cluster:

```bash
gcloud container fleet memberships get-credentials CLUSTER-NAME --project=YOUR-CLUSTER-PROJECT --location=YOUR-CLUSTER-REGION
```

Replace the placeholders as follows:

- `CLUSTER-NAME`: The name of your cluster.
- `YOUR-CLUSTER-PROJECT`: The project ID where your cluster is located.
- `YOUR-CLUSTER-REGION`: The region of your cluster.

### Step 2: Deploy the Example

1. Retrieve the value for `IMAGE_URL` variable:

    ```bash
    terraform -chdir=./5-appinfra/hpc/hpc-team-a/envs/development init
    export IMAGE_URL="terraform -chdir=./5-appinfra/hpc/hpc-team-a/envs/development output -raw image_url"
    ```

    > NOTE: If you don't have access to the terraform state, the IMAGE_URL format is: `us-central1-docker.pkg.dev/INFRA_PROJECT/private-images/ai-train:v1` where `INFRA_PROJECT` is your hpc-team-a infrastructure project ID.

1. Run the job on `hpc-team-a-development` using the namespace LocalQueue and the variables retrieved above:

    ```bash
    envsubst < ./6-appsource/manifests/ai-training-job.yaml | kubectl -n hpc-team-a-development apply -f -
    ```

1. Validate your job finished by looking at the Container Logs, search for "Training finished. Model saved":

    ```bash
    kubectl -n hpc-team-a-development logs jobs/mnist-training-job -c tensorflow
    ```
