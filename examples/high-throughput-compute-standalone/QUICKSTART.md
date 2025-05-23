
# Load Test for HTC

## Overview

This is an example of running a loadtest library on Google Cloud infrastructure.

It will run using GKE horizontal pod autoscaler orchestrated using Pub/Sub, and will
also run on Cloud Run through BigQuery. For details on the loadtest library, see
its [README.md](https://github.com/GoogleCloudPlatform/risk-and-research-blueprints/blob/main/examples/risk/loadtest/src/README.md). The same techniques can be used to run any kind of
library that is exposing gRPC.

Cloud Logging, Pub/Sub, Cloud Monitoring, BigQuery, and Looker Studio will all be used
for monitoring the infrastructure as it scales.

## Setup terraform

### Configure terraform

Set the variables for the region and zones being used. Change this to a different region and zones (e.g.., europe-west1 and zones b, c, d) if desired.

```sh
REGION='us-central1'
ZONES='"a","b","c","f"'
```

Create the terraform.tfvars configuration with the variables.

```sh
printf 'project_id="%s"\nregion="%s"\nzones=[%s]\n' ${GOOGLE_CLOUD_PROJECT} ${REGION} ${ZONES} > terraform.tfvars
```

### Initialize terraform

Inspect the terraform.tfvars. This should continue your desired project, region, and zones.
```sh
cat terraform.tfvars
```

Initialize the terraform environment.
```sh
terraform init
```

## Create infrastructure

### Enable basic project services

You may need to enable some basic APIs for Terraform to work:
```sh
gcloud services enable iam.googleapis.com cloudresourcemanager.googleapis.com
```

### Apply the terraform

Apply the terraform to your project.

```sh
terraform apply
```

NOTE: While running the terraform if the APIs are newly enabled, there may be
timing errors and terraform apply will need to be re-run.

## Run a test GKE HPA job

We will launch a test job and, using the horizontal pod autoscaler, see the
infrastructure scale up/down.

### Configure credentials

Get the credentials for kubectl by using the generated command.
```sh
$(terraform output -raw get_credentials)
```

### Launch the job

Launch a template job that will create 1,000 tasks that will take
1 second to initialize and each task will take 1 second.
```sh
./generated/gke_hpa_1k_1s_s_read_small.sh
```

### See the job

See the job in GKE. It may take a while to get scheduled due to
node auto-provisioning.
```sh
kubectl get jobs
```

## Monitor the status of the job

### Inspect Deployed workers

See the worker deployment. This should have a single instance running, but will be scaled
when the Horizontal Pod Autoscaler detects backlog on the Pub/Sub subscription.

```sh
kubectl get deploy
```

### Inspect the autoscaler

We can also describe the Horizontal Pod Autoscaler. This monitors the Pub/Sub
metrics to calculate the desired number of pods in the deployment.

```sh
kubectl describe hpa gke-hpa
```

### Inspect the controller publishing into the queue

Check the logs of the controller. It should look like it is running normally. It publishes
tasks to the Pub/Sub topic as soon as it starts.
```sh
kubectl logs jobs/hpa-1k-1s-s-read-small-controller
```

### Inspect Pub/Sub Subscription

We can also inspect the queue in Pub/Sub. This will be the queue of outstanding tasks.

The link to the [subscription](https://console.cloud.google.com/cloudpubsub/subscription/detail/gke_hpa_request_sub)
will show you the health, statistics, and also allow you to pull messages (tasks).

Pull some messages (do not Ack!) and see the messages appear. These messages
will be JSON, but adhering to the [protobuf request](https://github.com/GoogleCloudPlatform/risk-and-research-blueprints/blob/main/examples/risk/loadtest/src/request.proto) schema.

### Inspect the workers

We can inspect the logs from the worker. The worker will be scaled, automatically,
after a period of time.

```sh
kubectl logs deploy/gke-hpa
```

### Inspect the workers in the console

The same workers -- with some monitoring, including CPU and memory usage -- can be
seen in the console.

Go into the [workload console](https://console.cloud.google.com/kubernetes/workload/overview) and
click on "gke-hpa". This will give you a view of the deployment over time.

## Observe Pub/Sub messages in BigQuery

There are Pub/Sub to BigQuery subscriptions that persist all Pub/Sub messages as JSON directly into BigQuery. This
allows you to analyze the content of the messages as they occur, including both requests and responses.

### Inspect the raw messages in BigQuery

Go into the [BigQuery Console](https://console.cloud.google.com/bigquery) and open a new query.

In the query, inspect the recent messages (tasks & responses) that have been published:
```sql
SELECT * FROM `workload.pubsub_messages` ORDER BY publish_time DESC LIMIT 10;
```

### Inspect the a summary in BigQuery

There are two views (workload.pubsub_messages_joined and workload.pubsub_messages_summary) that extract
meaningful information from these messages (outstanding tasks, completed tasks, task status, etc) that are
used in dashboards for monitoring.

An example query that will give you the queue length and some other stats (looking at tasks with no status
published back yet) follows. Try it out!

```sql
SELECT
  start_time,
  jobId,
  remaining_tasks AS queue,
  task_jobs,
  CAST(SAFE_DIVIDE(task_compute_secs, task_jobs) AS STRING FORMAT '999999.9') AS task_cpu_avg,
  CAST(SAFE_DIVIDE(task_io_secs_total, task_jobs) AS STRING FORMAT '999999.9') AS task_io_avg,
from
  workload.pubsub_messages_summary
ORDER BY
  start_time DESC
LIMIT 10
```

## Observe logs in Cloud Logging and BigQuery

### Browse the logs in Cloud Logging

You can go to the [logging console](https://console.cloud.google.com/logs/query;query=resource.type%3D%22k8s_container%22%0Aresource.labels.container_name%3D%22agent%22;duration=PT15M?inv=1) to see the same logs as from kubectl. This gives you a nice frontend for filtering the logs.

### Browse the logs in BigQuery

From within logging, you can also use [logging analytics](https://console.cloud.google.com/logs/analytics) to query the logs using
SQL. However, bringing these logs into BigQuery as a [linked dataset](https://cloud.google.com/logging/docs/buckets#link-bq-dataset)
gives you the full power of BigQuery (dashboards, analytics, pipelines, etc). The data is streamed in so it is near real time.

If you go back to the [BigQuery Console](https://console.cloud.google.com/bigquery), you can enter the following query to see
the same logs.

```sql
SELECT
  timestamp,
  log_name,
  resource,
  json_payload
FROM
  `applogs._AllLogs`
WHERE
  resource.type = 'k8s_container' AND
  json_payload IS NOT NULL
ORDER BY
  timestamp DESC
LIMIT
  10
```

### Browse log analysis in BigQuery

This shows you recent logs and the JSON messages, just as in Cloud Logging and kubectl. But using BigQuery views can allow
you to parse the JSON. For example, if you want to see the recent workers that have been processing operations the
following SQL can be used.

```sql
SELECT
  meta.job_worker_id,
  MAX(timestamp) AS last_active_time,
  TIMESTAMP_DIFF(
    MAX(timestamp),
    MIN(timestamp),
    SECOND) AS total_active_secs,
  SUM(ops) total_ops,
  SAFE_DIVIDE(SUM(ops),TIMESTAMP_DIFF(MAX(timestamp), MIN(timestamp), SECOND)) AS ops_per_second
FROM
  `workload.agent_stats`
GROUP BY
  meta.job_worker_id
HAVING
  total_ops > 0
ORDER BY
  last_active_time DESC
```

### Create a Looker Studio dashboard

Run the following to extract the creation link for a Looker Studio dashboard. This uses the BigQuery views -- with streaming,
up to date, parsed logs and Pub/Sub messages -- to create a monitoring dashboard. This can be integrated with any other logging,
streaming messages, and BigQuery data.

```sh
terraform output -json | jq -r .lookerstudio_create_dashboard_url.value
```

Click on the URL to create a dashboard from the template.

## Look at the Cloud Monitoring

### Explore Cloud Monitoring

The metrics of Pub/Sub (e.g. queue length), Kubernetes (e.g. container CPU usage), and much more is available in Cloud Monitoring.

Look at some [Cloud Monitoring metrics](https://console.cloud.google.com/monitoring/metrics-explorer?pageState=%7B%22xyChart%22:%7B%22constantLines%22:%5B%5D,%22dataSets%22:%5B%7B%22plotType%22:%22LINE%22,%22targetAxis%22:%22Y1%22,%22timeSeriesFilter%22:%7B%22aggregations%22:%5B%7B%22crossSeriesReducer%22:%22REDUCE_SUM%22,%22groupByFields%22:%5B%5D,%22perSeriesAligner%22:%22ALIGN_MEAN%22%7D%5D,%22apiSource%22:%22DEFAULT_CLOUD%22,%22crossSeriesReducer%22:%22REDUCE_SUM%22,%22filter%22:%22metric.type%3D%5C%22kubernetes.io%2Fcontainer%2Fcpu%2Frequest_utilization%5C%22%20resource.type%3D%5C%22k8s_container%5C%22%22,%22groupByFields%22:%5B%5D,%22minAlignmentPeriod%22:%2260s%22,%22perSeriesAligner%22:%22ALIGN_MEAN%22%7D%7D%5D,%22options%22:%7B%22mode%22:%22COLOR%22%7D,%22y1Axis%22:%7B%22label%22:%22%22,%22scale%22:%22LINEAR%22%7D%7D%7D) and explore. The link will provide you CPU utilization on standard Cloud Monitoring.

### Explore Sample Dashboard - Risk Platform Overview

There is a `Risk Platform Overview` dashboard supplied. You can find it and see
it on the Dashboards List page as a [Custom dashboard](https://console.cloud.google.com/monitoring/dashboards?pageState=(%22dashboards%22:(%22t%22:%22Custom%22))).

## Run scalable compute with BigQuery

### Run BigQuery query

Open [BigQuery](https://console.cloud.google.com/bigquery).

Create and run the following query. The `workload.workload` (which you can inspect) is connected to a Cloud Run instance which is running the same loadtest code, connected into the same logging infrastructure. Rather than using Pub/Sub, however, it uses JSON over gRPC.

This query dispatches 100 tasks which each take 100 milliseconds (e.g., 10 seconds of work). This will create Cloud Run instances on
demand, execute the work, and scale down. It scales to zero on a normal basis.

```sql
SELECT
  `workload.workload`(TO_JSON(STRUCT(
    STRUCT(
      100000 AS min_micros
    ) AS task
  )))
FROM
  UNNEST(GENERATE_ARRAY(1, 100)) AS i;
```

### Look at Cloud Run

By looking at the [Cloud Run](https://console.cloud.google.com/run) and the `workload-worker-bigquery` service you can watch as it
scales up and down. The same logging tools and metrics can be used with Cloud Run and can be leveraged and dashboards.

Feel free to try scaling up the number of tasks -- say, 10000! -- and see Cloud Run scaling up even higher.

## Run a custom UI

A custom control and monitoring front end, leveraging BigQuery data and launching jobs, can be created.

### Create a virtual environment

```sh
python3 -m venv ui/.venv
ui/.venv/bin/python3 -m pip install --require-hashes -r ui/requirements.txt
```

### Run the Gradio dashboard

```sh
ui/.venv/bin/python3 ui/main.py generated/config.yaml
```
Use port 8080 or preview 8080 in the Cloud Shell (Webpreview). This allows you to load
tests, inspect the jobs from BigQuery (similar to the dashboard), and has some deep
links into the Console.

## Conclusion

You have now run a dynamically scalable GKE workload, observed it using Cloud Logging, Pub/Sub, and Cloud Monitoring, and
run a BigQuery query that dynamically scales to execute your query.
