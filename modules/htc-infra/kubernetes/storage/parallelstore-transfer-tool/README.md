# Parallelstore Data Transfer Tool

This tool allows you to import and export data between Google Cloud Parallelstore and Google Cloud Storage (GCS). It provides a command-line interface to initiate data transfers and monitor their progress.

Along with a sample Kubernetes Job manifest to run in your kubernetes cluster.

## Features

* **Import data from GCS to Parallelstore:** Transfer data from a GCS bucket to a Parallelstore instance.
* **Export data from Parallelstore to GCS:** Transfer data from a Parallelstore instance to a GCS bucket.

## Prerequisites

* **Google Cloud Project:** A Google Cloud project with billing enabled.
* **Parallelstore Instance:** A Parallelstore instance in your project.
* **GCS Bucket:** A GCS bucket to store or retrieve data.
* **Service Account:** A service account with permissions to access Parallelstore and GCS.
* **Google Cloud SDK:**  Installed and configured with your project.

## Run via CLI
  1. Install Requirements
  ```bash
    pip install -r requirements.txt
  ```
  Sample Import Job:
  ```
  python3 main.py --mode import --gcsbucket my-bucket-name --instance my-instance-name --location us-central1-a
  ```
  Sample Export Job:
  ```
  python3 main.py --mode export --gcsbucket my-bucket-name --instance my-instance-name --location us-central1-a
  ```
## Run as a Kubernetes Job

  1. Export variables

  ```bash
  export REGION=<your-region>
  export PROJECT_ID=<your-project-id>
  export BUCKET_NAME=<gcs-bucket-name>
  ```
  2. Build and Push docker image

  ```bash
    docker build . -t $REGION-docker.pkg.dev/$PROJECT_ID/research-images/parallelstore-transfer

    docker push $REGION-docker.pkg.dev/$PROJECT_ID/research-images/parallelstore-transfer
  ```
 3. Grant IAM Permission for Workload

  The user or service account used for initiating the transfer requires the following permissions:
  - `parallelstore.instances.exportData` in order to transfer from Parallelstore to Cloud Storage.
  - `parallelstore.instances.importData` in order to transfer to Cloud Storage.

  Both of these permissions are granted with the `roles/parallelstore.admin` role.

  You can create a [custom role](https://cloud.google.com/iam/docs/creating-custom-roles) to grant permissions independently.

  In addition, the Parallelstore service account requires the following permission:

  - `roles/storage.admin` on the Cloud Storage bucket.

  To grant this permission, run the following `gcloud` command:

  > **_NOTE:_** This is assuming you are running the job in the default namespace.

  ```bash
    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="principal://iam.googleapis.com/projects/$PROJECT_ID/locations/global/workloadIdentityPools/$PROJECT_ID.svc.id.goog/subject/ns/default/sa/parallelstore-data-transfer" \
      --role="roles/storage.admin"

    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="principal://iam.googleapis.com/projects/$PROJECT_ID/locations/global/workloadIdentityPools/$PROJECT_ID.svc.id.goog/subject/ns/default/sa/parallelstore-data-transfer" \
      --role="roles/parallelstore.admin"

  ```

  4. Configure Job

  In the `k8s/kustomization.yaml` file, update the following parameters with your specifics, including if you want to run an import or export job.

 ```
      args:
    - --mode
    - import
    - --gcsbucket
    - <your-gcs-bucket-name>
    - --instance
    - <your-parallelstore-instance-name>
    - --location
    - <your-parallelstore-instance-location>
    - --project-id
    - <your-parallelstore-project-id>

  ```


 5. Run Job

  ```bash
    kustomize build k8s/ | kubectl deploy -f -
  ```
 6. Check status of Job
  To check the status of the job you can run the following command:
  ```bash
    kubectl describe job parallelstore-data-transfer
  ```
  otherwise if you'd like to see the logs from the job run the following:
  ```bash
    kubectl logs job/parallelstore-data-transfer
  ```
