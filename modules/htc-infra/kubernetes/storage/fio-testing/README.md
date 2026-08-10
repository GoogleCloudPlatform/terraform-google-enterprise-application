# FIO Benchmark for Google Cloud Storage (GCS) and Parallelstore

This repository provides an example Docker image and Kubernetes configurations for using FIO (Flexible I/O Tester) to benchmark Google Cloud Storage (GCS) buckets and Parallelstore.  It leverages Kubernetes Jobs to run FIO tests and provides separate configurations for GCS and Parallelstore.

## Overview

The setup includes:

*   **Dockerfile:** Builds a Docker image containing FIO, `jq`, Python 3, and necessary tools.
*   **entrypoint.sh:**  A script that handles FIO execution, mount point checks, configuration validation, and cleanup.
*   **k8s:** Directory containing sample GCS and Parallelstore configs for testing
    * **gcs:** Kubernetes Job definition for running FIO tests against a GCS bucket mounted using the GCSFuse CSI driver.
    * **parallelstore:** Kubernetes Job definition for running FIO tests against a Parallelstore Persistent Volume.

## Getting Started

### Prerequisites

*   Docker installed.
*   kubectl configured to connect to your Kubernetes cluster.
*   A GCS bucket for testing
*   A Parallelstore instance for testing
*   A Docker registry (e.g., Google Container Registry) to push the built Docker image.

    ```bash
    export PROJECT_ID=YOUR_PROJECT_ID
    export REGISTRY=YOUR_REGISTRY_NAME
    ```

### Building and Deploying

1.  **Build the Docker image:**

    ```bash
    docker build -t us-docker.pkg.dev/$PROJECT_ID/$REGISTRY/fio:latest .
    ```

    Replace `us-docker.pkg.dev/PROJECT_ID/REGISTRY/fio:latest` with your desired image name and tag.

2.  **Push the Docker image to your registry:**

    ```bash
    docker push us-docker.pkg.dev/$PROJECT_ID/$REGISTRY/fio:latest
    ```
3.  **Add your variables:**

    - In both directory there is a `fio-config.yaml` file which is a config map that configures FIO. Modify this to set the behaviour of your test.

    - Modify the `kustomization.yaml` file and set the variables in the configMapGenerator.


4.  **Deploy the Config and Job:**

    ```bash
    kustomize build k8s/parallelstore | kubectl apply -f -
    ```

    ```bash
    kustomize build k8s/gcs | kubectl apply -f -
    ```


### Monitoring and Results

*   **Check job status:**

    ```bash
    kubectl get jobs -l app=fio-test
    ```

*   **View job logs:**

    ```bash
    kubectl logs -l app=fio-test -f
    ```

    This will stream the FIO output, which is formatted as JSON.  You can use `jq` to parse and analyze the results.  For example:

    ```bash
    kubectl logs -l app=fio-test -f | jq .
    ```

*   **Cleanup:**

    The Kubernetes Jobs are configured with `ttlSecondsAfterFinished` to automatically clean up after completion.  You can also manually delete the jobs:

    ```bash
    kubectl delete job -l app=fio-test
    ```

## Configuration Details

### fio-config.yaml

*   `[global]`: Defines global FIO parameters.  `filename_format` uses the pod name to ensure unique filenames for each run.
*   `[job1]`: Defines the I/O workload.  Adjust parameters like `rw`, `rwmixread`, `blocksize`, `filesize`, etc., to suit your testing needs.
*   `[cleanup]`: Defines a cleanup job that trims (deletes) the files created during the test.

### Parallelstore Options:

*   `STORAGECLASS`: The storage class name for your Parallelstore instance (without the project/location prefix).
*   `PROJECT_ID`: Your Google Cloud project ID.
*   `LOCATION`: The region and zone of your Parallelstore instance (e.g., `us-central1-b`).
*   `INSTANCE_NAME`: The name of your Parallelstore instance.
*   `STORAGE_SIZE`: The size of the PersistentVolume to create (e.g., `21000Gi`).
*   `ACCESS_POINTS`: Comma-separated list of access points for the Parallelstore instance.
*   `NETWORK`: The VPC network name of your Parallelstore instance.
*   `MOUNT_LOCALITY`: The mount locality for the Parallelstore instance.
*   `COMPLETIONS`: The number of FIO job completions.
*   `PARALLELISM`: The number of parallel FIO jobs.

## GCS Options:

*   `BUCKETNAME`: The name of your GCS bucket.
*   `COMPLETIONS`: The number of FIO job completions.
*   `PARALLELISM`: The number of parallel FIO jobs.


## Analyzing Results in BigQuery

The FIO results are logged as JSON and can be efficiently queried in BigQuery.  Ensure that your Kubernetes logs are being exported to BigQuery.  You can then use a query similar to the following to analyze the results:

```sql
SELECT
  -- Timestamp and identifiers
  timestamp,
  JSON_EXTRACT_SCALAR(resource.labels, '$.pod_name') as pod_name,
  -- Throughput and IOPS
  CAST(JSON_EXTRACT_SCALAR(json_payload, '$.jobs[0].read.bw') AS FLOAT64) AS throughput_kbs,
  CAST(JSON_EXTRACT_SCALAR(json_payload, '$.jobs[0].read.iops') AS FLOAT64) AS iops,
  -- Data read
  CAST(JSON_EXTRACT_SCALAR(json_payload, '$.jobs[0].read.io_bytes') AS FLOAT64)/1048576 AS data_read_mb,
  -- Latency percentiles (in milliseconds)
  CAST(JSON_EXTRACT_SCALAR(json_payload, "$.jobs[0].read.clat_ns.percentile['50.000000']") AS FLOAT64)/1000000 AS median_latency_ms,
  CAST(JSON_EXTRACT_SCALAR(json_payload, "$.jobs[0].read.clat_ns.percentile['90.000000']") AS FLOAT64)/1000000 AS p90_latency_ms,
  CAST(JSON_EXTRACT_SCALAR(json_payload, "$.jobs[0].read.clat_ns.percentile['99.000000']") AS FLOAT64)/1000000 AS p99_latency_ms,
  -- Runtime
  CAST(JSON_EXTRACT_SCALAR(json_payload, '$.jobs[0].job_runtime') AS FLOAT64)/1000 AS runtime_seconds
FROM
  `PROJECT_ID.all_logging_bq_link._Default`
WHERE
  resource.type = "k8s_container"
  AND JSON_EXTRACT_SCALAR(resource.labels, '$.container_name') = 'fio'
  AND JSON_EXTRACT_SCALAR(resource.labels, '$.pod_name') like 'fio-test-%'
  AND json_payload IS NOT NULL
ORDER BY timestamp DESC;
```


## Note:

This example provides a starting point for benchmarking GCS and Parallelstore using FIO.  You can customize the configurations to meet your specific testing requirements. Remember to consult the FIO documentation for more advanced configuration options.
