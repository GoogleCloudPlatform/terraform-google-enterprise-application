# Example: Getting started with a simple go app

<table>
<tbody>
<tr>
<td><a href="../1-bootstrap">1-bootstrap</a></td>
<td>Bootstraps streamlines the bootstrapping process for Enterprise Applications on Google Cloud Platform (GCP)</td>
</tr>
<tr>
<td><a href="../2-multitenant">2-multitenant</a></td>
<td>Deploys GKE clusters optimized for multi-tenancy within an enterprise environment.</td>
</tr>
<tr>
<td><a href="../3-fleetscope"><span style="white-space: nowrap;">3-fleetscope</span></a></td>
<td>Set-ups Google Cloud Fleet, enabling centralized management of multiple Kubernetes clusters.</td>
</tr>
<tr>
<td><a href="../4-appfactory">4-appfactory</a></td>
<td>Sets up infrastructure and CI/CD pipelines for a single application or microservice on Google Cloud</td>
</tr>
<tr>
<td><a href="../5-appinfra">5-appinfra</a></td>
<td>Set up application infrastructure pipelineaims to establish a streamlined CI/CD workflow for applications, enabling automated deployments to multiple environments (GKE clusters).</td>
</tr>
<tr>
<td>6-appsource (this file)</td>
<td>Deploys a modified version of a [simple example](https://github.com/GoogleContainerTools/skaffold/tree/main/examples/getting-started) for skaffold.</td>
</tr>
</tbody>
</table>

This is a modified version of a [simple example](https://github.com/GoogleContainerTools/skaffold/tree/main/examples/getting-started) for skaffold, and contains the following features:

* **building** a single Go file app and with a multistage `Dockerfile` using local docker to build
* **tagging** using the default tagPolicy (`gitCommit`)
* **deploying** a single container pod using `kubectl`

This example contains multi-architecture images. On the development environment, the pod specification will request arm64 nodes for the autopilot cluster and run an arm64 version of the docker image. On nonproduction and production environments, the pod will run an amd64/x86 version of the image on standard clusters.

|              | Development | Non Production/Staging | Production |   |
|--------------|-------------|------------------------|------------|---|
| Architecture | arm64       | amd64/x86              | amd64/x86  |   |

To achieve multi-architecture builds and images, the examples needs to use the extended features of [`buildx`](https://github.com/docker/buildx).

## Using the CI/CD Pipeline

A CI/CD pipeline was created for this application on 5-appinfra, it uses Cloud Build to build the docker image and Cloud Deploy to deploy the image to the cluster using skaffold.

1. (CSR Only) Clone the CI/CD repository

   ```bash
   gcloud source repos clone eab-default-example-hello-world --project=REPLACE_WITH_ADMIN_PROJECT
   ```

1. (GitHub Only) When using GitHub, clone the CI/CD repository with the following command.

   ```bash
   git clone git@github.com:<GITHUB-OWNER or ORGANIZATION>/eab-default-example-hello-world.git
   ```

   > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.

1. (GitLab Only) When using GitLab, clone the CI/CD repository with the following command.

   ```bash
   git clone git@gitlab.com:<GITLAB-GROUP or ACCOUNT>/eab-default-example-hello-world.git
   ```

   > NOTE: Make sure to replace `<GITLAB-GROUP or ACCOUNT>` with your actual GitLab group or account name.

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
