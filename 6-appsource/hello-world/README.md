### Example: Getting started with a simple go app

This is a simple example based on:

* **building** a single Go file app and with a multistage `Dockerfile` using local docker to build
* **tagging** using the default tagPolicy (`gitCommit`)
* **deploying** a single container pod using `kubectl`

### Using the CI/CD Pipeline

1. Clone the CI/CD repository

```bash
gcloud source repos clone eab-default-example-hello-world --project=REPLACE_WITH_ADMIN_PROJECT
```

1. Copy the contents of this directory to the repository:

```bash
cp -r terraform-google-enterprise-application/6-appsource/hello-world/* eab-default-example-hello-world
```

1. Commit changes

```bash
cd eab-default-example-hello-world
git checkout -b main
git add .
git commit -m "Add code to cicd repository"
git push origin main
```

1. After pushing the code to the main branch, the CI (build) pipeline will be triggered on the `hello-world-admin` project under the common folder. You can view the results on the Cloud Build Page.

1. After the CI build succesfully runs, it will automatically trigger the CD pipeline using Cloud Deploy on the same project.

1. Once the CD pipeline succesfully runs, you should be able to see a pod named `getting-started` on your cluster that prints the "Hello world!" message.
