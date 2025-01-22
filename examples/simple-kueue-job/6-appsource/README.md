# simple-kueue-job - Parallel Queue for two teams using GKE Autopilot

You will setup two tenant teams where each team has its own namespace and each team creates Jobs that share global resources. You also configure Kueue to schedule the Jobs based on resource quotas that you define.

To run this you must install queue

## Kueue installation

Make sure the following conditions are met before installing:

- A Kubernetes cluster with version 1.25 or newer is running.
- The kubectl command-line tool has communication with your cluster.

To install a released version of Kueue in your cluster, run the following command:

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.10.1/manifests.yaml
```

Wait until pods are in ready state:

```bash
watch kubectl -n kueue-system get pods
```

## Concepts

- `ResourceFlavor`: ResourceFlavor is an object that represents resource variations (architecture, pricing, brands, models, etc...) and allows you to associate them with cluster nodes through labels, taints and tolerations. We are using an empty ResourceFlavor in this example because we don't need to manage quotas in an autopilot cluster.
- `ClusterQueue`: A ClusterQueue is a cluster-scoped object that governs a pool of resources such as pods, CPU, memory, and hardware accelerators.
- `LocalQueue`: A LocalQueue is a namespaced object that groups closely related Workloads that belong to a single namespace/tenant and points to a ClusterQueue. Users submit jobs to a LocalQueue, instead of to a ClusterQueue directly.

## Running the Example

After installing `Kueue`, run the `setup.yaml`, that will create the Namespaces, ResourceFlavor, ClusterQueue and LocalQueue:

```bash
kubectl apply -f setup.yaml
```

Then run a dummy job on team-a, on file `job-team-a.yaml`:

```bash
kubectl apply -f job-team-a.yaml
```

Then run a dummy job on team-b, on file `job-team-b.yaml`:

```bash
kubectl apply -f job-team-a.yaml
```

The jobs are 3 parallel pods that sleep for 3 seconds, they will request CPU, GPU and Storage, you can create multiple the commandns above multiple times to simulate teams deploying jobs in parallel and observe the ClusterQueue behaviour using `kubectl get clusterqueue cluster-queue -o wide`.

## Reference

- Kueue <https://kueue.sigs.k8s.io/docs/>
- keueue in gke intro <https://cloud.google.com/kubernetes-engine/docs/tutorials/kueue-intro>
- <https://github.com/GoogleCloudPlatform/kubernetes-engine-samples>
