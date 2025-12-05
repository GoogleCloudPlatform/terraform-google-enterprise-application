# Example: Getting started with a Agent app

This is a modified version of a [Capital Agent](https://google.github.io/adk-docs/agents/llm-agents/#equipping-the-agent-tools-tools) for skaffold, and contains the following features:

* **building** a single Go file app and with a multistage `Dockerfile` using local docker to build
* **tagging** using the default tagPolicy (`gitCommit`)

## Using the CI/CD Pipeline

A CI/CD pipeline was created for this application on 5-appinfra, it uses Cloud Build to build the docker image and Cloud Deploy to deploy the image to the cluster using skaffold.

1. Clone the CI/CD repository

```bash
gcloud source repos clone eab-default-capital-agent --project=REPLACE_WITH_ADMIN_PROJECT

1. Copy the contents of this directory to the repository:

```bash
cp -r terraform-google-enterprise-application/6-appsource/agent/* eab-agent-example-capital-agent
```

1. Commit changes

```bash
cd eab-agent-example-capital-agent
git checkout -b main
git add .
git commit -m "Add code to cicd repository"
git push origin main
```

1. After pushing the code to the main branch, the CI (build) pipeline will be triggered on the `agent-admin` project under the common folder. You can view the results on the Cloud Build Page.

1. After the CI build succesfully runs, it will automatically trigger the CD pipeline using Cloud Deploy on the same project.

1. Once the CD pipeline succesfully runs, you should be able to see a deployment named `capital-agent-deployment` on your cluster and be able to access the UI by Load Balancer IP.
