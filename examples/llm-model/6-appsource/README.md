# Example: Getting started with a VLLM model

This is a modified version of a [GKE Inference Gataway tutorial](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/deploy-gke-inference-gateway#create-model-deployment) for skaffold, and contains the following features:

* **building** `Dockerfile` using local docker to build
* **tagging** using the default tagPolicy (`gitCommit`)

## Requeriments

You need to follow this Hugging Face steps in this [documentation](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/deploy-gke-inference-gateway#before-you-begin)

1. Create a [Hugging Face](https://huggingface.co/) account if you don't already have one. You will need this to access the model resources for this tutorial.
1. Request access to the Llama 3.1 model and generate an access token. Access to this model requires an approved request on Hugging Face, and the deployment will fail if access has not been granted.
    * __Sign the license consent agreement:__ You must sign the consent agreement to use the Llama 3.1 model. Go to the model's page on Hugging Face, verify your account, and accept the terms.
    * __Generate an access token:__ To access the model, you need a Hugging Face token. In your Hugging Face account, go to Your Profile > Settings > Access Tokens, create a new token with at least Read permissions, and copy it to your clipboard.
1. After getting the token, create the secret in your cluster:

```bash
export token=<YOUR-TOKEN>
export cluster_name=<CLUSTER-NAME>
export cluster_project=<CLUSTER-PROJECT>
export enviroment=<ENVIROMENT-YOUR-ARE-APPLYING>

# GET YOUR CLUSTER CREDENTIALS
gcloud container fleet memberships get-credentials ${cluster_name}  --project ${cluster_project}

# CREATE THE SECRET
kubectl create secret generic hf-secret --from-literal=${token} --namespace=capital-agent-${enviroment} --dry-run=client -o yaml | kubectl apply -f -
```

## Using the CI/CD Pipeline

A CI/CD pipeline was created for this application on 5-appinfra, it uses Cloud Build to build the docker image and Cloud Deploy to deploy the image to the cluster using skaffold.

1. Clone the CI/CD repository

```bash
gcloud source repos clone eab-llm-model-llamma-model --project=REPLACE_WITH_ADMIN_PROJECT

1. Copy the contents of this directory to the repository:

```bash
cp -r terraform-google-enterprise-application/6-appsource/llm-model/* eab-llm-model-llamma-model
```

1. Commit changes

```bash
cd eab-llm-model-llamma-model
git checkout -b main
git add .
git commit -m "Add code to cicd repository"
git push origin main
```

1. After pushing the code to the main branch, the CI (build) pipeline will be triggered on the `llm-admin` project under the common folder. You can view the results on the Cloud Build Page.

1. After the CI build succesfully runs, it will automatically trigger the CD pipeline using Cloud Deploy on the same project.

1. Once the CD pipeline succesfully runs, you should be able to see a deployment named `openai-app` on your cluster and be able to access the UI by Load Balancer IP.
