# HPC Batch Jobs Use Cases

This document presents two use cases that demonstrate the utilization of `kueue` to manage multi-team batch jobs within a Cluster.

### Use Cases:

- [Use Case 1: HPC Financial Analysis Using Monte Carlo Simulations (Team: `hpc-team-b`)](#use-case-1-hpc-financial-analysis-using-monte-carlo-simulations-team-hpc-team-b)
- [Use Case 2: HPC AI Model Training with GPU (Team: `hpc-team-a`)](#use-case-2-hpc-ai-model-training-with-gpu-team-hpc-team-a)

## Use Case 1: HPC Financial Analysis Using Monte Carlo Simulations (Team: `hpc-team-b`)

This example is an adaptation from [Google Cloud Platform's Risk and Research Blueprints](github.com/GoogleCloudPlatform/risk-and-research-blueprints/tree/main/examples/research/monte-carlo).

### Requirements

- **Docker Registry Connectivity**
  If you are using a private cluster with private nodes, they must be able to fetch Kueue Docker images from `registry.k8s.io`. This can be done by adding Cloud NAT to the private nodes network, having your own NAT setup on your cluster network, or by following the tutorial for [Artifact Registry Remote Repositories](../../docs/remote_repository_kueue_installation.md).

- **Kubectl with Cluster Connection**
  If using a private cluster, you can use Connect Gateway.

  ```bash
  gcloud container fleet memberships get-credentials CLUSTER-NAME --project=YOUR-CLUSTER-PROJECT --location=YOUR-CLUSTER-REGION
  ```

  If you have access to specific namespace, you can run:

  ```bash
  gcloud container fleet scopes namespaces get-credentials NAMESPACE
  ```

- **Kueue**

  - **Option 1 (Cluster Network with NAT)**: Install Kueue by running the following command:

      ```bash
      kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.10.1/manifests.yaml
      ```

      > **Note:** To uninstall a released version from your cluster, run:
      >
      > ```bash
      > kubectl delete -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.10.1/manifests.yaml
      > ```

      Wait for Kueue installation to complete:

      ```bash
      kubectl wait deploy/kueue-controller-manager -nkueue-system --for=condition=available --timeout=5m
      ```

  - **Option 2**: Install Kueue by following the tutorial for [Artifact Registry Remote Repositories](../../docs/remote_repository_kueue_installation.md)

- **Cluster Toolkit (gcluster)**

    This guide assumes you have `gcluster` installed on your home directory. More information on how to setup gcluster in the following [link](https://cloud.google.com/cluster-toolkit/docs/setup/configure-environment#local-shell)

#### Create Namespaces

##### Add `hpc-team-a` and `hpc-team-b` Namespaces at the Fleetscope repository

Typically, the application namespace will be created on 3-fleetscope and specified in 6-appsource.

1. Navigate to Fleetscope repository and add the hpc-team-a and hpc-team-b namespaces at `terraform.tfvars`, if the namespace was not created already:

    ```diff
    namespace_ids = {
    +    "hpc-team-a"     = "your-hpc-team-a-group@yourdomain.com",
    +    "hpc-team-b"     = "your-hpc-team-b-group@yourdomain.com",
         ...
    }
   ```

1. Apply changes by commiting to a named environment branch (`development`, `nonproduction`, `production`). After the build associated with the fleetscope repository finishes it's execution, the namespaces should be present in the cluster.

#### Create Teams Environments and Infrastructure

##### Create projects in 4-appfactory

You will find an example [terraform.tfvars](./4-appfactory/terraform.tfvars) in this example to create `hpc-team-a` and `hpc-team-b`.

```diff
applications = {
+  "hpc" = {
+    "hpc-team-a" = {
+      create_infra_project = true
+      create_admin_project = true
+    },
+    "hpc-team-b" = {
+      create_infra_project = true
+      create_admin_project = true
+    }
+  }
}

cloudbuildv2_repository_config = {
  repo_type = "GITLABv2"
  repositories = {
+    hpc-team-a = {
+      repository_name = "hpc-team-a-i-r"
+      repository_url  = "https://gitlab.com/user/hpc-team-a-i-r.git"
+    },
+    hpc-team-b = {
+      repository_name = "hpc-team-b-i-r"
+      repository_url  = "https://gitlab.com/user/hpc-team-b-i-r.git"
+    }
  }
  # The Secret ID format is: projects/PROJECT_NUMBER/secrets/SECRET_NAME
  gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
  gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
  gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
  # If you are using a self-hosted instance, you may change the URL below accordingly
  gitlab_enterprise_host_uri = "https://gitlab.com"
}

```

Apply the modifications by pushing code to a named branch, after updating the variables.

##### Deploy baseline infrastructure in 5-appinfra

Under [5-appinfra](./5-appinfra/) you will find the two environment folders. They just need to be copied to you AppInfra Pipeline repository and pushed to a named branch.

##### Apply Kueue Resources

Run the following command to create the necessary Kueue resources (ClusterQueue and LocalQueue), this step should be run by a Batch Administrator, after the namespaces are created and should be run only once:

```bash
kubectl apply -f manifests/kueue-resources.yaml
```

The queues that are created in this step will later be used to schedule batch jobs.

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
