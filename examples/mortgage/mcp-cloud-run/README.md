# Deployment Order

[1] `standalone-single-project`
*(This README covers the process starting from `mcp-cloud-run`)*
[2] `mcp-cloud-run`
[3] `6-appsource`

```bash
gcloud services enable agentregistry.googleapis.com --project=XXXXXXXXXX
```

## 1) Terraform (mcp-cloud-run)

```bash
cd /terraform-google-enterprise-application/examples/mortgage/mcp-cloud-run/terraform
mv terraform.tfvars.example terraform.tfvars
```

Edit `project_id` and `gke_agent_sa_email` (Agent's GSA in GKE) in the `terraform.tfvars` file.

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## 2) Deploy MCP Images

```bash
cd /terraform-google-enterprise-application/examples/mortgage/mcp-cloud-run

export PROJECT_ID=XXXXXXXXXX
export REGION=us-central1
export BUCKET_NAME=$(terraform -chdir=terraform output -raw cloudbuild_bucket)
export MCP_INGRESS=all

envsubst '${PROJECT_ID} ${REGION} ${BUCKET_NAME}' < skaffold.yaml.tmpl > skaffold.yaml
for f in cloud_run/*.yaml.tmpl; do
  envsubst '${PROJECT_ID} ${REGION} ${MCP_INGRESS}' < "$f" > "${f%.tmpl}"
done

skaffold run
```

## 3) Pointing to 6-appsource

In `terraform-google-enterprise-application/examples/mortgage/6-appsource/k8s/base/deployment.yaml`, the environment variables `MCP_DISCOVERED_SERVERS_JSON` and `MCP_INVOKER_SA_EMAIL` point to the `mortgage-agent-config` ConfigMap.

In the overlay at `terraform-google-enterprise-application/examples/mortgage/6-appsource/k8s/overlays/development/`:

- Create the `mcp-discovered-servers.json` file with the Cloud Run URLs:

Get the individual URLs:

```bash
for s in legacy-dms corporate-email income-verification; do echo "$s: $(gcloud run services describe "$s" --project="$PROJECT_ID" --region="$REGION" --format='value(status.url)')/mcp"; done
```

```json
[
    {
      "name": "legacy-dms",
      "resolved_url": "https://legacy-dms-XXXXXXXx.a.run.app/mcp",
      "tool_name_prefix": "legacy_dms",
      "tools": ["search_documents", "get_document"]
    },
    {
      "name": "corporate-email",
      "resolved_url": "https://corporate-email-XXXXXXXx.a.run.app/mcp",
      "tool_name_prefix": "corporate_email",
      "tools": ["send_email", "read_email"]
    },
    {
      "name": "income-verification",
      "resolved_url": "https://income-verification-XXXXXXXx.a.run.app/mcp",
      "tool_name_prefix": "income_verification",
      "tools": ["verify_applicant"]
    }
]
```

In the overlays at `terraform-google-enterprise-application/examples/mortgage/6-appsource/k8s/overlays/development/kustomization.yaml`:

Get the service account email using:
```bash
terraform -chdir="/terraform-google-enterprise-application/examples/mortgage/mcp-cloud-run/terraform" output -raw agent_mcp_invoker_email
```

- Literal:
   - `MCP_INVOKER_SA_EMAIL=`
