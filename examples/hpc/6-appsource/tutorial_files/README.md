# Running batch jobs on GKE

Running a job on kubernetes using the Batch and Jobs API is reasonably simple if you use GKE Autopilot.
Autopilot will scale up nodes to provide the requirements of the Pod created for your Job submission.

## Introduction

In this demo we use the [Python kubernetes API](https://github.com/kubernetes-client/python/)
to submit pods on a Kubernetes cluster.

To populate the basic settings for the Job, we use `settings.toml`, which is
read using the [Dynaconf library](https://www.dynaconf.com/). One of the advantages of Dynaconf is
the ability to read from a variety of files (toml, yaml, json, etc) and to override those settings with
environment variables.

## Tutorial architecture
The overall structure of this tutorial is as follows:

* The Monte Carlo simulation is managed with
  [Kueue](https://cloud.google.com/kubernetes-engine/docs/tutorials/kueue-intro).
* The output of the Monte Carlo simulation is published to a
  [PubSub](https://cloud.google.com/pubsub/docs/overview) topic.
* The PubSub data is entered into [BigQuery](https://cloud.google.com/bigquery)
via a [PubSub BigQuery subscription](https://cloud.google.com/pubsub/docs/bigquery)
* The data is visualized via a
  [Vertex AI Workbench](https://cloud.google.com/vertex-ai-workbench)
  [Jupyter Notebook](https://jupyter.org/)

<img src="https://services.google.com/fh/files/blogs/gke_arch.png" width="800" />


## Cost to run
The following elements of this tutorial will result in charges to your billing
account. Please validate with the
[Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator)

* Pub/Sub
* BigQuery
* Vertex AI Notebooks
* Cluster Toolkit
* Google Kubernetes Engine (GKE)
* Artifact Registry
* Cloud Build

## Getting started

### Kubernetes Cluster, GKE

> If you have an existing Kubernetes Cluster you can step.

1. Clone this repository
1. `cd` to `research-platform-for-fsi/examples/research/monte-carlo`
1. Edit the `variables.tf` file to update `project_id` and if you choose, `region`.
1. Run `terraform init`
1. Run `terraform apply`

This will create a GKE kubernetes cluster, `gke-risk-research` in your project.

Once complete, authenticate to the cluster.
```
gcloud container clusters get-credentials gke-risk-research --region us-central1
```

Now the cluster build is complete and you are authenticated, install Kueue and Kueue Configurations:

When complete, run the local Kueue configuration. This will create a `cluster-queue` and two `local-queues`, `lq-hpc-team-a` and `lq-hpc-team-b`.
```
kubectl apply --server-side -k kubernetes
```
To see the details of the cluster queue, use `kubectl`.
```
kubectl get clusterqueue cluster-queue
```
To see the local queues, again use `kubectl get localqueue
```
kubectl get localqueues --all-namespaces
```
This completes the Kubernetes configuration.

### Install GCP Cluster Toolkit

We will make use of the cluster Toolkit in the next step. The instructions to install it are here:

[Set up Cluster Toolkit](https://cloud.google.com/cluster-toolkit/docs/setup/configure-environment)

You should install this in your $HOME directory. Then you can test it:
```
~/cluster-toolkit/gcluster --version
```

### Build docker container and send to Artifact Registry
To efficiently run the code required for this tutorial, you must build a docker container
Python installed with the relevant libraries and local Python scripts. You then send it to
Google Cloud Aritifact Registry, in a repository called `research-images`. This work is
managed by Google Cloud Build.

Run Google Cloud Build as follows:
1. `cd` to `research-platform-for-fsi/examples/research/monte-carlo/src/docker`

```
gcloud builds submit --region=us-central1 --config cloudbuild.yaml
```
Ensure that `us-central1` is the region your cluster ended up in.

### Install the tutorial code

This tutorial is part of the `research-platform-for-fsi` repository.

1. `cd` to `research-platform-for-fsi/examples/research/monte-carlo/src`
1. Run `gcluster`
```
~/cluster-toolkit/gcluster deploy fsi-montecarlo-on-gke.yaml \
   --vars "project_id=${GOOGLE_CLOUD_PROJECT}"
```

Ensure that the $GOOGLE_CLOUD_PROJECT variable is set to your project ID.

### Open the Vertex AI Workbench Notebook
When the deployment is complete, you can connect to the Vertex AI Workbench Notebook. Navigate to:

https://console.cloud.google.com/vertex-ai/workbench/instances

If the Notebook instance is complete, **"OPEN JUPYTERLAB"** will be listed. If not, wait until it completes.

> Open JupyterLab on the Notebook instance listed.

<img src="https://services.google.com/fh/files/blogs/gke_workbench.png" width="500" />

```bash
Click on `OPEN JUPYTERLAB` link
```

> In the JupyterLab UI, you will see a list of directories:

```bash
Select `data`
```

> Under `data` all the files required to run the demo have been pepared.

<img src="https://services.google.com/fh/files/blogs/gke_files.png" width="300" />

> Open a terminal window by clicking on the terminal icon.

<img src="https://services.google.com/fh/files/blogs/fsi_terminal.png" width="200" />

> Run the `run_me_first.sh` shell script.

```
source ./run_me_first.sh
```

> Run the `gke_batch.py` Python script to ensure it is working.

```bash
python3 gke_batch.py --help
```
You will see a listing of the help messages.

In this tutorial, all the settings are in a file called:
```
settings.toml
```
The default values set in this file should work for the tutorial, but it is the first place
to look if you have to debug.

> To start the VaR simulation, run `gke_batch.py` with `--create_job`

```bash
python3 gke_batch.py --create_job
```

You should see output without any errors, listing information about the job.

> To see if the job is running, use the `--list_jobs` options.

```bash
python3 gke_batch.py --list_jobs
```
<img src="https://services.google.com/fh/files/blogs/gke_listjobs.png" width="300" />

If you want to see the jobs listed in the Cloud Console, you can click:

https://console.cloud.google.com/kubernetes/workload/overview

## View the data in BigQuery
The batch job runs Monte Carlo simulation for the VaR calculation. The output
from each run is stored in BigQuery. To view this data in it's raw form, you can
view BigQuery in the Cloud Console:

https://console.cloud.google.com/bigquery

> Navigate to table with a name that starts with `montecarlo`.

<img src="https://services.google.com/fh/files/blogs/gke_bq.png" width="300" />

> There you can see the schema.

<img src="https://services.google.com/fh/files/blogs/gke_schema.png" width="600" />

> To see the data, click on `PREVIEW`

<img src="https://services.google.com/fh/files/blogs/fsi_preview.png" width="600" />

For an advanced user, you can run queries directly in the BigQuery UI.

## Visualization in the Notebook

Finally, you can select the `FSI_MonteCarlo.ipynb` from the left navigation in
the JupyterLab window.

<img src="https://services.google.com/fh/files/blogs/fsi_ipynb.png" width="300" />

To run the cells in the notebook, select the cell, then click the play button,
or `Alt-Enter`.

> Run the cells in the order they appear.

<img src="https://services.google.com/fh/files/blogs/fsi_notebook.png" width="600" />

> After running the second cell, you should see output.

<img src="https://services.google.com/fh/files/blogs/fsi_output.png" width="500" />

> Finally, when you run Cell #4, you will see graphs and table summaries.

<img src="https://services.google.com/fh/files/blogs/fsi_graphs.png" width="600" />

## Summary

In this tutorial, you accomplished the following:

* You created Cloud infrastructure
  * Vertex AI notebooks
  * BigQuery Tables
  * Pubsub BigQuery Subscription
  * Batch jobs on GKE
* You ran a MonteCarlo simulation for VaR on several stock tickers.
* You reviewed the data in BigQuery
* You visualized the data in Vertex AI notebooks.

## Shutting down

The best way to clean up your workspace is to delete the project. This will
ensure you are not billed for any of the Cloud usage.

### Alternatively

The other choice is to run a `gcluster destroy` command.

```bash
./gcluster destroy fsimontecarlo
```
Change directory to /examples/research/monte-carlo

```bash
terraform destroy
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster\_name | Name of the GKE Cluster to use for job submission | `string` | n/a | yes |
| cluster\_project | Project that hosts the GKE Cluster | `string` | n/a | yes |
| dataset\_id | Bigquery dataset id | `string` | n/a | yes |
| gcs\_bucket\_path | Bucket name | `string` | `null` | no |
| project\_id | ID of project in which GCS bucket will be created. | `string` | n/a | yes |
| region | Region to run project | `string` | n/a | yes |
| table\_id | Bigquery table id | `string` | n/a | yes |
| topic\_id | Pubsub Topic Name | `string` | n/a | yes |
| topic\_schema | Pubsub Topic schema | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->