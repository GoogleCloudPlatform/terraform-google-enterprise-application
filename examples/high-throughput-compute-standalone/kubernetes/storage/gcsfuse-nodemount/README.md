# GCSFUSE Node-Level Mount DaemonSet
> **WARNING:** This is not an officially supported Google service. The use of this solution is on an "as-is" basis and is not a service offered under the Google Cloud Terms of Service.

> **WARNING:** Google does not endorse the PoC approach described in this document for production use. This PoC is intended solely for internal testing to validate the shared mount architecture for GCS. It should only be used for experimental purposes. Please also note that this PoC does not support Node Autoscaling, non-disruptive node upgrades, or DaemonSet updates. Any attempt at node upgrades or DaemonSet updates will require complete downtime for workloads and will result in workload failures if these actions are attempted.

This repository contains a Kubernetes Daemonset that deploys GCSFUSE on each node of your cluster, providing a shared mount point for accessing Google Cloud Storage (GCS).

## Overview

This Daemonset utilizes GCSFUSE to mount a GCS bucket to a directory on each node. The configuration emphasizes performance and caching for high-concurrency, small-file workloads. Key features include:

* **Node-level mount:**  Provides a consistent mount point accessible to all pods on the node.
* **Optimized for small files:**  Caching settings are tuned for frequent access to small files, minimizing latency.
* **High concurrency:** Connection limits are increased to handle many concurrent requests.
* **tmpfs for cache and temp:** Utilizes tmpfs for the GCSFUSE cache and temporary directories, leveraging node memory for improved performance.
* **`allow_other`:** Enables access to the mount point from pods running with different user IDs.

## Configuration

The `gcsfuse-config` ConfigMap defines the GCSFUSE settings:

* **`file-cache`:**
    * `max-size-mb`:  Set to `-1` to allow the cache to grow dynamically.
    * `cache-file-for-range-read`: **Enabled** to avoid downloading entire files for small reads.
    * `enable-parallel-downloads`: **Enabled** to potentially improve performance for larger files.
* **`metadata-cache`:**  Configured with generous sizes and a 10-minute TTL.
* **`cache-dir`:** Set to `/tmp/cache` (tmpfs).
* **`gcs-connection`:**  Increased `max-conns-per-host` and `max-idle-conns-per-host`.
* **`implicit-dirs`:** **Enabled** for faster directory creation.
* **`file-system`:**
    * `fuse-options`: Includes `allow_other`, `nonempty`, and `auto_unmount`.
    * `temp-dir`: Set to `/tmp/gcsfuse` (tmpfs).

## Filesystem

* **Mount point:** `/data` (baced by a hostPath volume, could be extended to use a persistent disk)
* **Cache directory:** `/tmp/cache` (tmpfs)
* **Temporary directory:** `/tmp/gcsfuse` (tmpfs)

Using tmpfs for the cache and temporary directories leverages node memory for improved performance. However, ensure sufficient memory is available on your nodes.

## Approach

The Daemonset uses a privileged container to run GCSFUSE and mount the GCS bucket. A `preStop` lifecycle hook ensures graceful unmounting before the pod terminates.

## Provide GCS Access to DaemonSet
  ```bash
    export PROJECT_NUMBER=$(gcloud projects list \
    --filter="PROJECT_ID=${PROJECT_ID}" \
    --format="value(PROJECT_NUMBER)")

    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/$PROJECT_ID.svc.id.goog/subject/ns/gcs-node-mount/sa/gcsfuse-node-sa" \
      --role="roles/storage.admin"
```

## Build Images and Deploy DaemonSet

**1. Export Variables**

```bash
export REGION=<your-region>
export PROJECT_ID=<your-project-id>
```

**2. Build Images**
#### Cloudbuild

    Cloudbuild builds the Image from the Dockerfile in the [gcsfuse](https://github.com/GoogleCloudPlatform/gcsfuse/tree/master) Github repo.
```bash
gcloud builds submit --no-source --project $PROJECT_ID --region=$REGION .
```

#### Manually

```bash
git pull https://github.com/GoogleCloudPlatform/gcsfuse.git
cd gcsfuse
docker buildx build --platform linux/amd64 -t $REGION-docker.pkg.dev/$PROJECT_ID/research-images/gcs-fuse:latest --push .
```

**3. Deploy Daemonset**

```bash
kubectl apply -k k8s/
```

**4. Deploy Sample Workload**

```bash
kubectl apply -f k8s/example-pod.yaml
```

 Exec into pod and verify that you can see the files in your gcs bucket in the pod.

```bash
kubectl exec -n default -it pod/my-pod -- sh
ls -la /data
```

## Monitoring

The configuration exports GCSFUSE metrics to Cloud Monitoring. Monitor these metrics to assess performance and identify potential issues.

## Notes

* This setup uses `allow_other`, which has security implications. Ensure your GCS bucket has appropriate ACLs and your nodes are secured.
* GCSFUSE provides eventual consistency. If your application requires strong consistency, consider alternative approaches.
* This README provides a high-level overview. Refer to the GCSFUSE documentation for detailed information.
    - https://cloud.google.com/storage/docs/gcs-fuse
    - https://github.com/GoogleCloudPlatform/gcsfuse/tree/master/docs
