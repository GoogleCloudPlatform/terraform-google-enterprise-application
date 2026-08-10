# Installing Kueue
This document provides a basic guide for using Kustomize to deploy and manage Kueue installations.

It includes integration with Google Cloud Monitoring and Google Cloud Managed Service for Prometheus and a includes:
- A [custom-configured released version](https://kueue.sigs.k8s.io/docs/installation/#install-a-custom-configured-released-version) to enable `enableClusterQueueResources`
- Enabled [visibility API](https://kueue.sigs.k8s.io/docs/installation/#add-visibility-api-to-monitor-pending-workloads)

**Prerequisites:**

- Kustomize: Ensure you have Kustomize installed on your system. You can download it from the official Kustomize releases page.
- kubectl: You'll need kubectl to interact with your Kubernetes cluster.

## Deploy Kueue with GMP Configuration and Cloud Monitoring Dashboard
**Deploy Kueue**

Deploy for GKE Standard
```bash
kustomize build overlays/gke-standard/ | kubectl apply --server-side -f -
```

Deploy for GKE Autopilot
```bash
kustomize build overlays/gke-autopilot/ | kubectl apply --server-side -f -
```

**Deploy Monitoring Dashboard**

```bash
gcloud monitoring dashboards create --project=$PROJECT_ID --config-from-file=dashboard/kueue-dashboard.json
```

## Querying Metrics

You can also query Kueue metrics directly using the [Google Cloud Monitoring - Metrics explorer](https://console.cloud.google.com/monitoring/metrics-explorer) interface. Both PromQL and MQL are supported for querying.

For more information, refer to the [Cloud Monitoring Documentation](https://cloud.google.com/monitoring/charts/metrics-explorer).

### Example Queries

Here are some sample PromQL queries to help you get started with monitoring your Kueue system:

#### Job Throughput

```promql
sum(rate(kueue_admitted_workloads_total[5m])) by (cluster_queue)
```

This query calculates the per-second rate of admitted workloads over 5 minutes for each cluster queue. Summing them provides the overall system throughput, while breaking it down by queue helps pinpoint potential bottlenecks.

#### Resource Utilization (`requires metrics.enableClusterQueueResources`)

```promql
sum(kueue_cluster_queue_resource_usage{resource="cpu"}) by (cluster_queue) / sum(kueue_cluster_queue_nominal_quota{resource="cpu"}) by (cluster_queue)
```

This query calculates the ratio of current CPU usage to the nominal CPU quota for each queue. A value close to 1 indicates high CPU utilization. You can adapt this for memory or other resources by changing the resource label.

>__Important__: This query requires the metrics.enableClusterQueueResources setting to be enabled in your Kueue manager's configuration.  To enable this setting, follow the instructions in the Kueue installation documentation: [https://kueue.sigs.k8s.io/docs/installation/#install-a-custom-configured-released-version](https://kueue.sigs.k8s.io/docs/installation/#install-a-custom-configured-released-version)
#### Queue Wait Times
```promql
histogram_quantile(0.9, kueue_admission_wait_time_seconds_bucket{cluster_queue="QUEUE_NAME"})
```
This query provides the 90th percentile wait time for workloads in a specific queue. You can modify the quantile value (e.g., 0.5 for median, 0.99 for 99th percentile) to understand the wait time distribution. Replace `QUEUE_NAME` with the actual name of the queue you want to monitor.

## Preview of Dashboard

![Dashboard 1](../../images/kueue_cloud_monitoring_1.png)
![Dashboard 2](../../images/kueue_cloud_monitoring_2.png)
