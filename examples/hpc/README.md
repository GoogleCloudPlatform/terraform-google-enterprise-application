# HPC Example

This document is an adaptation from [Google Cloud Platform's Risk and Research Blueprints](https://github.com/GoogleCloudPlatform/risk-and-research-blueprints/tree/main/examples/research/monte-carlo).

## Requirements

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
  Install Kueue by running the following command:

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

- **Cluster Toolkit (gcluster)**

    This guide assumes you have `gcluster` installed on your home directory. More information on how to setup gcluster in the following [link](https://cloud.google.com/cluster-toolkit/docs/setup/configure-environment#local-shell)

## Usage

### Create Namespaces

#### Add `hpc-team-a` and `hpc-team-b` Namespaces at the Fleetscope repository

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

### Apply Kueue Resources

Run the following command to create the necessary Kueue resources (ClusterQueue and LocalQueue), this step should be run by a Batch Administrator, after the namespaces are created and should be ran only once:

```bash
kubectl apply -f manifests/kueue-resources.yaml
```

The queues that are created in this step will later be used to schedule batch jobs.

### Set Project for gcloud Commands

```bash
gcloud config set project REPLACE_WITH_YOUR_INFRA_PROJECT
```

### Run `gcluster` Blueprint

The `fsi-montecarlo-on-batch.yaml` file contains a blueprint that is deployed with `gcluster` (cluster-toolkit). It will create a notebook instance on the infrastructure project, alongs with the it's dependencies.

To deploy the blueprint, navigate to the source directory and run the following command, make sure you replace CLUSTER_NAME with your environment's cluster name, use your team infrastructure project that was created on 4-appfactory for the `PROJECT_ID`:

```bash
PROJECT_ID=REPLACE_WITH_YOUR_INFRA_PROJECT
CLUSTER_NAME=REPLACE_WITH_CLUSTER_NAME
CLUSTER_PROJECT=REPLACE_WITH_CLUSTER_PROJECT

~/cluster-toolkit/gcluster deploy fsi-montecarlo-on-batch.yaml --vars "project_id=$PROJECT_ID,cluster_name=$CLUSTER_NAME,cluster_project=$CLUSTER_PROJECT" --auto-approve
```

> NOTE: the example code is deployed for `hpc-team-b`. If you wish to deploy the example on `hpc-team-a` environment, you will need to adjust `settings.tpl.toml` and change the namespace and LocalQueue name.

### Run the Simulation Jobs and Visualize the Results

#### Requisites before running

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

#### Follow the tutorial on the original repository

Follow the steps outlined in the following document, after the "Open the Vertex AI Workbench Notebook" section:

[Open the Vertex AI Workbench Notebook](https://github.com/GoogleCloudPlatform/risk-and-research-blueprints/tree/0e3134b8478f3ffaa12031d7fda3ac6b94e61b17/examples/research/monte-carlo#open-the-vertex-ai-workbench-notebook)

**IMPORTANT**: Your Vertex AI Workbench Instance will be located on the application infrastructure project that was created on 4-appfactory.
