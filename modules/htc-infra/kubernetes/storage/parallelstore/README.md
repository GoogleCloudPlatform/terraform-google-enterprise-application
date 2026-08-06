# Deploying a DaemonSet for Node Mounting Parallelstore
> **WARNING:** This is not an officially supported Google service. The use of this solution is on an “as-is” basis and is not a service offered under the Google Cloud Terms of Service.

> **WARNING:** Google does not endorse the PoC approach described in this document for production use. This PoC is intended solely for internal testing to validate that the shared mount architecture for Parallelstore. It should only be used for experimental purposes. Please also note that this PoC does not support Node Autoscaling, non-disruptive node upgrades, or DaemonSet updates. Any attempt at node upgrades or DaemonSet updates will require complete downtime for workloads and will result in workload failures if these actions are attempted.


This DaemonSet mounts a Parallelstore instance (Google Cloud's high-performance storage solution) for all Pods on a GKE node to leverage the same mount point. This provides an alternate method to using the supported Parallelstore CSI driver.

For more information on using the CSI Driver, please refer to the [documentation](https://cloud.google.com/parallelstore/docs/csi-driver-overview).

## Build Images and Deploy DaemonSet

**1. Export Variables**

```bash
export REGION=<your-region>
export PROJECT_ID=<your-project-id>
```

**2. Build Images**
#### Cloudbuild
```bash
gcloud builds submit --project $PROJECT_ID --region=$REGION .
```

#### Manually
```bash
cd image
docker buildx build --platform linux/amd64 -t $REGION-docker.pkg.dev/$PROJECT_ID/research-images/nodemount:latest --push -f ./Dockerfile .
```

**3. Update Config**

Update the `DAOS_ACCESS_POINTS` with the your Parallelstore Access Points in `k8s/daemonset-access-points.yaml`.

If you used the included terraform these were outputted as apart of the Terraform Apply.

Otherwise, you can find these via the following command (replace INSTANCE_NAME and LOCATION with your actual values):

```bash
gcloud beta parallelstore instances describe INSTANCE_NAME --location=LOCATION
```
Example output
```bash
accessPoints:
- 10.155.200.4
- 10.155.200.3
- 10.155.200.2
capacityGib: '12000'
createTime: '2024-10-03T14:22:45.381421273Z'
effectiveReservedIpRange: address
name: projects/project-id/locations/us-central1-a/instances/daos-instance
network: projects/project-id/global/networks/research-vpc
state: ACTIVE
updateTime: '2024-10-03T14:31:53.129533289Z'
```
In k8s/daemonset-access-points.yaml, replace the placeholder access points with your own:

```yaml
# k8s/daemonset-access-points.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: daos-client
spec:
  template:
    spec:
      containers:
      - name: daos-client
        env:
        - name: DAOS_ACCESS_POINTS
          value: "10.90.188.4, 10.90.188.2, 10.90.188.3"  # Replace with your access points
```

Update `k8s/kustomization.yaml` with your Artifact Registry details.
```yaml
# k8s/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- daemonset.yaml
- daemonset-access-points.yaml
images:
- name: nodemount
  newName: us-central1-docker.pkg.dev/your-project-id/research-images/nodemount  # Replace with your registry
  newTag: latest                    # Replace with your desired tag
```

**4. Apply the DaemonSet to your cluster**

```bash
kubectl apply -k k8s
```

**5. Validate Deployment**
```bash
kubectl describe daemonset/daos-client -n default
```
Check the "Desired Number Scheduled" and "Current Number Scheduled" to ensure they match the number of nodes in your cluster.
Look for any error messages or events that indicate problems with the DaemonSet.
**6. Test with sample workload**
This example workload deploys two pods that mount the Parallelstore volume.
```bash
kubectl apply -f example-workload.yaml
```
Exec into the first pod and create a file:
```bash
kubectl exec -it pod/pstore-testing-1 -- sh
touch /data/test.txt
```
Exec into the second pod and list the directory to see the file created by the first pod:
```bash
kubectl exec -it pod/pstore-testing-2 -- sh
ls -la /data
```
**7. (Optional) Transfer data to or from Cloud Storage**

Another option to validate the Daemonset is by using the import data feature of Parallelstore.

Parallelstore can import data from, and export data to, Cloud Storage. Data transfers allow you to quickly load data into your Parallelstore instance, and to use Cloud Storage as a durable backing layer for your Parallelstore instance.

Transfers from Cloud Storage are incremental; they only copy files to your Parallelstore instance that don't already exist on the instance, or that have changed since they were transferred.

Follow guide [here](https://cloud.google.com/parallelstore/docs/transfer-data) to import data into the Parallelstore instance and validate that is visible from one of the pods above.
