# AGENTS.md - AI Agent & LLM Contribution Guide

This guide is designed for **AI coding assistants, LLMs, and autonomous agents** contributing to the `terraform-google-enterprise-application` repository. It outlines the architectural mental model, directory structure, development workflows, security guardrails, and verification procedures required to generate high-quality, production-ready contributions.

---

## 1. Repository Identity & Mission

This repository implements the Google Cloud Platform (GCP) **Enterprise Application blueprint** (`terraform-google-enterprise-application`). It provides an opinionated, production-ready, and secure internal developer platform (IDP) on Google Cloud.

The blueprint extends the foundational security practices of the [Enterprise Foundation blueprint](https://cloud.google.com/architecture/security-foundations) (`terraform-example-foundation`).

### Core Objectives
*   **Automate Multi-Tenant Platform Provisioning**: Provide isolated environments across development, non-production, and production.
*   **Decouple Infrastructure and Application Lifecycles**: Strict separation of duties between Cloud Platform teams and Application teams.
*   **Enforce Security Guardrails by Default**: Zero-trust networking, Private Service Connect (PSC), VPC Service Controls (VPC-SC), OPA/Gatekeeper Policy Controller, and Binary Authorization.
*   **Support Diverse Workloads**: Microservices, GenAI / LLM agents, High-Performance Computing (HPC), High-Throughput Computing (HTC), and multi-cluster topologies.

---

## 2. Architecture & Stage Execution Model

When reasoning about this codebase, agents must maintain a clear mental model of the progressive 6-stage lifecycle:

```
[0-bootstrap / Test Setup] ──> [1/2-multitenant GKE] ──> [3-fleetscope] ──> [4-appfactory] ──> [5-appinfra] ──> [6-appsource]
```

| Stage | Path / Module | Responsibility & Scope | Target Audience |
| :--- | :--- | :--- | :--- |
| **0 - Bootstrap / Test Harness** | `test/setup/`<br>`modules/standalone-harness` | Foundational test projects, Hub VPC networking with Network Connectivity Center (NCC) / VPC Peering, KMS keys, logging buckets, and test Service Accounts. | Platform Admin |
| **2 - Multi-tenant Infrastructure** | `modules/gke`<br>`modules/cluster_network` | Multi-tenant private GKE clusters, Pod/Service CIDR subnets, Cloud NAT, Cloud Armor security policies, and external static IPs. | Platform Admin |
| **3 - Fleet & Governance** | `modules/fleetscope` | GKE Fleet membership, team scopes, namespaces, Config Sync (ACM GitOps), Anthos Service Mesh (ASM), Policy Controller (Gatekeeper constraints), and Kueue. | Platform Admin |
| **4 - App Factory** | `modules/secure-cicd-pipeline` | Tenant admin projects, Cloud Build private worker pools, Artifact Registry repos, Cloud Deploy delivery pipelines, and IAM service accounts. | Platform Admin / Team Lead |
| **5 - App Infrastructure** | `5-appinfra/`<br>`modules/alloydb-psc-setup` | Workload backing resources: AlloyDB/Cloud SQL databases via PSC, Spanner, GCS buckets, Secret Manager secrets, and Kubernetes Workload Identity bindings. | Application Team |
| **6 - App Source & Delivery** | `6-appsource/`<br>`modules/deployment-pipeline` | Application source code, `Dockerfile`, Skaffold configurations, and Kubernetes manifests (Kustomize overlays: `development`, `nonproduction`, `production`). | Application Developer |

---

## 3. Directory Layout & Key Lookup

```
terraform-google-enterprise-application/
├── modules/                        # Reusable Terraform modules
│   ├── gke/                        # Multi-tenant private GKE cluster module
│   ├── fleetscope/                 # GKE Fleet, scopes, Config Sync, ASM, Policy Controller
│   ├── secure-cicd-pipeline/       # Dedicated CI/CD with Cloud Build private pools & VPC-SC
│   ├── deployment-pipeline/        # Cloud Deploy pipelines and targets
│   ├── alloydb-psc-setup/          # AlloyDB with Private Service Connect
│   ├── cluster_network/            # VPC, subnets, secondary ranges, NAT, Cloud Router
│   ├── private_workerpool/         # Cloud Build private worker pools
│   ├── private_install_manifest/   # Manifest mirroring to internal Artifact Registry
│   ├── binary-authz-build-image/   # Binary Authorization attestation builder
│   ├── standalone-harness/         # Single-project / standalone testing harness
│   ├── nat/                        # Cloud NAT router configuration
│   ├── hpc-ai-training-infra/      # HPC AI/ML GPU training infrastructure
│   ├── hpc-monte-carlo-infra/      # HPC Monte Carlo financial batch infrastructure
│   └── htc-infra/                  # HTC batch orchestration with Kueue & Parallelstore
├── examples/                       # End-to-end reference implementations
│   ├── default-example/            # Baseline 3-tier multi-project app deployment (stages 4-6)
│   ├── standalone_single_project/  # All-in-one single GCP project sandbox
│   ├── standalone_single_project_confidential_nodes/ # Single project with Confidential VMs
│   ├── cymbal-bank/                # Full banking microservices architecture (Bank of Anthos)
│   ├── cymbal-shop/                # E-commerce microservices demo (11 services)
│   ├── multitenant-applications/   # Multi-tenancy co-hosting Cymbal Bank & Cymbal Shop
│   ├── agent/                      # GenAI / LLM agent with HPA and Gateway API
│   ├── llm-model/                  # Secure ML/LLM model serving pipeline
│   ├── hpc/                        # HPC Monte Carlo and AI GPU training use cases
│   ├── htc/                        # HTC batch scheduling with Kueue and Parallelstore
│   └── cluster-multicluster-discovery/ # Multi-cluster service discovery across fleets
├── helpers/                        # Auxiliary developer and operator tools
│   └── eab-deployer/               # Go CLI to automate and sequence multi-stage deployments
├── build/                          # CI/CD pipelines & automation scripts
│   ├── tf-wrapper.sh               # Terraform wrapper for workspace & state management
│   ├── cloudbuild-tf-plan.yaml     # Cloud Build Terraform plan specification
│   ├── cloudbuild-tf-apply.yaml    # Cloud Build Terraform apply specification
│   └── int.cloudbuild*.yaml        # Integration build specifications for test environments
├── test/                           # Quality assurance and testing harness
│   ├── setup/                      # Terraform harness provisioning CI test environment
│   └── integration/                # Terratest integration tests written in Go
└── docs/                           # Architecture guides, policy rules, and troubleshooting
```

---

## 4. Agent Working Rules & Coding Conventions

When generating or updating code, AI agents MUST strictly adhere to the following standards:

### 4.1. Terraform Conventions
*   **Formatting**: Always run `terraform fmt -recursive` on modified Terraform directories.
*   **Explicit Types & Descriptions**: Every `variable` and `output` must have an explicit `type` and an informative `description`.
*   **No Hardcoded Resource IDs**: Never hardcode Project IDs, VPC names, or Service Account emails. Parameterize them via variables or derive them from data sources/outputs.
*   **Documentation Hooks**: Do not edit the content inside `<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->` blocks manually. These are generated by `terraform-docs` (via `make generate_docs`).
*   **Version Pinning**: Maintain consistent provider version constraints (`>= 5.0` for `google` / `google-beta`, `>= 1.6` for Terraform core).

### 4.2. Security & IAM Guardrails (Strict Enforcement)
*   **Principle of Least Privilege**: Never assign broad administrative roles (e.g., `roles/owner`, `roles/editor`, `roles/resourcemanager.organizationAdmin`, `roles/accesscontextmanager.policyAdmin`). Always prefer granular or read-only roles (e.g., `roles/resourcemanager.organizationViewer`, `roles/accesscontextmanager.policyReader`).
*   **No Plaintext Secrets**: Store all sensitive tokens, passwords, and private keys in Secret Manager. Reference secrets via secret accessors or Secret Store CSI drivers.
*   **Private Connectivity**: 
    *   GKE clusters must have private nodes and private control plane endpoints.
    *   Managed databases (AlloyDB, Cloud SQL) must communicate exclusively over Private Service Connect (PSC) or private IP.
*   **VPC Service Controls (VPC-SC)**: Infrastructure modules and CI/CD pipelines must support execution inside VPC-SC perimeters.
*   **Isolated CI/CD**: Cloud Build triggers must run inside private worker pools connected to dedicated VPCs.

### 4.3. Go & Integration Test Conventions (`test/integration/`)
*   **Framework**: Integration tests are written in Go using [Terratest](https://terratest.gruntwork.io/).
*   **Formatting**: Format all Go files with `gofmt -s -w <file.go>`.
*   **Test Isolation**: Tests must create unique resource names or utilize prefixes to prevent collision during concurrent CI test runs.
*   **Idempotency & Cleanup**: Every test must include proper `defer terraform.Destroy(t, terraformOptions)` teardown logic.

### 4.4. Kubernetes & Deployment Pipeline Conventions (`6-appsource`)
*   **Kustomize Structure**: Structure manifests with a shared `base/` directory and environment overlays (`overlays/development/`, `overlays/nonproduction/`, `overlays/production/`).
*   **Skaffold & Cloud Deploy**: Keep `skaffold.yaml` configurations aligned with Cloud Deploy delivery pipeline definitions.

---

## 5. Step-by-Step Contribution Workflows for Agents

### Workflow A: Adding or Modifying a Terraform Module (`modules/`)
1. **Implement Terraform Changes**: Update or create resources in `modules/<module-name>/`.
2. **Expose Variables & Outputs**: Ensure all inputs and outputs in `variables.tf` and `outputs.tf` have type constraints and descriptions.
3. **Format Code**: Run `terraform fmt` in the module directory.
4. **Update Documentation**: Update `modules/<module-name>/README.md` or execute `make generate_docs`.
5. **Add Integration Tests**: Add or update the corresponding Go Terratest suite under `test/integration/`.

### Workflow B: Adding or Updating an Example Scenario (`examples/`)
1. **Define Stage Directories**: Implement `4-appfactory`, `5-appinfra`, and `6-appsource` (or a single-project sandbox configuration).
2. **Provide Sample Configuration**: Include clear `terraform.tfvars.example` files explaining each required input.
3. **Include Manifests & Pipelines**: Add `skaffold.yaml`, Kubernetes manifests, and Cloud Deploy delivery pipelines.
4. **Document the Example**: Provide an informative `README.md` detailing the scenario, prerequisites, architecture, and step-by-step execution.

### Workflow C: Updating IAM Permissions & Security Policies
1. **Identify Required Role**: Check the minimal required IAM permissions for the specific API calls.
2. **Avoid Wildcard / Admin Roles**: Replace any overly permissive roles with scoped alternatives.
3. **Test with Harness**: Verify that the changes pass integration tests in `test/setup/` or `test/integration/`.

---

## 6. Testing & Quality Assurance Playbook

Agents should use the following tools and commands to validate changes:

### 1. Code Formatting
```bash
# Format Terraform code across the entire repository
terraform fmt -recursive

# Format Go code
gofmt -s -w helpers/ test/
```

### 2. Linting & Validation (via Docker Developer Tools)
```bash
# Execute lint checks (Terraform, Shell, YAML, Go)
make docker_test_lint

# Generate module documentation tables
make docker_generate_docs
```

### 3. Running Integration Tests Locally
```bash
# Run specific Terratest integration test
cd test/integration
go test -v -run TestDefaultExample ./default-example -timeout 60m
```

---

## 7. Pre-Commit Verification Checklist for Agents

Before completing any task or proposing changes, verify that:

- [ ] `terraform fmt -recursive` runs cleanly without formatting errors.
- [ ] All new variables have explicit `type` definitions and meaningful `description` strings.
- [ ] No hardcoded GCP project IDs, credentials, or sensitive secrets exist in `.tf` or `.yaml` files.
- [ ] IAM roles strictly follow the Principle of Least Privilege.
- [ ] Any modified module has its documentation updated (`README.md` inputs/outputs).
- [ ] Go test files follow `gofmt` style and compile without errors (`go vet ./...`).
- [ ] Commit descriptions follow the Google Engineering Practices standard (clear summary line + explanatory "Why" body).
- [ ] Documentation updates comply with the [Google Developer Documentation Style Guide](https://developers.google.com/style).

---

## 8. Standards & Reference Links

*   **Documentation Style Guide**: [Google Developer Documentation Style Guide](https://developers.google.com/style)
*   **CL / Commit Guidelines**: [Google Engineering Practices on Writing Good CL Descriptions](https://google.github.io/eng-practices/review/developer/cl-descriptions.html)
*   **Code Review Speed**: [Google Engineering Practices on Code Review Speed](https://google.github.io/eng-practices/review/reviewer/speed.html)
*   **Enterprise Application Blueprint Architecture**: [Google Cloud Documentation](https://cloud.google.com/architecture/enterprise-application-blueprint/architecture)
*   **Enterprise Foundation Blueprint**: [terraform-example-foundation](https://github.com/terraform-google-modules/terraform-example-foundation)
*   **Troubleshooting Guide**: Consult [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md) for known edge cases and resolutions.
