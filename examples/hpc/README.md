# HPC Example

This document is an adaptation from [Google Cloud Platform's Risk and Research Blueprints](https://github.com/GoogleCloudPlatform/risk-and-research-blueprints/tree/main/examples/research/monte-carlo).

## Requirements

- **Docker Registry Connectivity**  
  If you are using a private cluster with private nodes, they must be able to fetch Kueue Docker images from `registry.k8s.io`. This can be done by adding Cloud NAT to the private nodes network.

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

- **Kubectl with Cluster Connection**  
  If using a private cluster, you can use Connect Gateway.

  ```bash
  gcloud container fleet memberships get-credentials CLUSTER-NAME --project=YOUR-CLUSTER-PROJECT --location=YOUR-CLUSTER-REGION
  ```

- **Cluster Toolkit (gcluster)**

    This guide assumes you have `gcluster` installed on your home directory. More information on how to setup gcluster in the following [link](https://cloud.google.com/cluster-toolkit/docs/setup/configure-environment#local-shell)

## Usage

### Create Namespaces

#### Add `hpc-team-a` and `hpc-team-b` Namespaces at the Fleetscope repository

The namespaces created at 3-fleetscope will be used in the application kubernetes manifests, when specifying where the workload will run. Typically, the application namespace will be created on 3-fleetscope and specified in 6-appsource.

1. Navigate to Fleetscope repository and add the hpc-team-a and hpc-team-b namespaces at `terraform.tfvars`, if the namespace was not created already:

    ```diff
    namespace_ids = {
    +    "hpc-team-a"     = "your-hpc-team-a-group@yourdomain.com",
    +    "hpc-team-b"     = "your-hpc-team-b-group@yourdomain.com",
         ...
    }
   ```

1. Apply changes by commiting to a named environment branch (`development`, `nonproduction`, `production`).

### Apply Kueue Resources

Run the following command to apply Kueue resources, this step should be run by a Batch Administrator and after the namespaces are created:

```bash
kubectl apply -f manifests/kueue-resources.yaml
```

### Set Project for gcloud Commands

```bash
gcloud config set project REPLACE_WITH_YOUR_INFRA_PROJECT
```

### Run `gcluster` Blueprint

Navigate to the source directory and run the following command, make sure you replace CLUSTER_NAME with your environment's cluster name:

```bash
cd src

PROJECT_ID=REPLACE_WITH_YOUR_INFRA_PROJECT
CLUSTER_NAME="REPLACE_WITH_CLUSTER_NAME"

~/cluster-toolkit/gcluster deploy fsi-montecarlo-on-batch.yaml --vars "project_id=$PROJECT_ID,cluster_name=$CLUSTER_NAME" --auto-approve
```

### Run the Simulation Jobs and Visualize the Results

Follow the steps outlined in the following document, after the "Open the Vertex AI Workbench Notebook" section:

[Open the Vertex AI Workbench Notebook](https://github.com/GoogleCloudPlatform/risk-and-research-blueprints/tree/0e3134b8478f3ffaa12031d7fda3ac6b94e61b17/examples/research/monte-carlo#open-the-vertex-ai-workbench-notebook)

Your Vertex AI Workbench Notebook will be created on the application infrastructure project.
