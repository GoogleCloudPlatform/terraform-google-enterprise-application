# simple-kueue-job

To run this you must install queue

## Kueue installation

Make sure the following conditions are met before installing:

- A Kubernetes cluster with version 1.25 or newer is running.
- The kubectl command-line tool has communication with your cluster.

To install a released version of Kueue in your cluster, run the following command:

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.10.1/manifests.yaml
```
