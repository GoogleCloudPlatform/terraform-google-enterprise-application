/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  admin_project_id = var.create_admin_project ? module.app_admin_project[0].project_id : var.admin_project_id
  cloudbuild_sa_roles = merge(var.create_infra_project ? { for env in keys(var.envs) : env => {
    project_id = module.app_infra_project[env].project_id
    roles      = var.cloudbuild_sa_roles[env].roles
    } } : {}, {
    "admin" : {
      project_id = local.admin_project_id
      roles = [
        "roles/browser", "roles/serviceusage.serviceUsageAdmin",
        "roles/storage.admin", "roles/iam.serviceAccountAdmin",
        "roles/artifactregistry.admin", "roles/clouddeploy.admin",
        "roles/cloudbuild.builds.editor", "roles/privilegedaccessmanager.projectServiceAgent",
        "roles/iam.serviceAccountUser", "roles/source.admin", "roles/cloudbuild.connectionAdmin"
      ]
    } },
    {
      for cluster_project_id in var.cluster_projects_ids : cluster_project_id => {
        project_id = cluster_project_id
        roles      = ["roles/privilegedaccessmanager.projectServiceAgent"]
      }
    }
  )

  org_ids             = distinct([for env in var.envs : env.org_id])
  use_csr             = var.cloudbuildv2_repository_config.repo_type == "CSR"
  service_repo_name   = var.cloudbuildv2_repository_config.repositories[var.service_name].repository_name
  worker_pool_project = element(split("/", var.workerpool_id), index(split("/", var.workerpool_id), "projects") + 1, )

  secret_id             = var.cloudbuildv2_repository_config.github_secret_id != null ? var.cloudbuildv2_repository_config.github_secret_id : var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id
  secret_project_number = regex("projects/([^/]*)/", local.secret_id)[0]
}

data "google_project" "admin_project" {
  project_id = local.admin_project_id
}

data "google_project" "workerpool_project" {
  project_id = local.worker_pool_project
}

data "google_project" "clusters_projects" {
  for_each   = toset(var.cluster_projects_ids)
  project_id = each.value
}

module "cloudbuild_repositories" {
  count = local.use_csr ? 0 : 1

  source  = "terraform-google-modules/bootstrap/google//modules/cloudbuild_repo_connection"
  version = "~> 11.0"

  project_id = local.admin_project_id

  connection_config = {
    connection_type                             = var.cloudbuildv2_repository_config.repo_type
    github_secret_id                            = var.cloudbuildv2_repository_config.github_secret_id
    github_app_id_secret_id                     = var.cloudbuildv2_repository_config.github_app_id_secret_id
    gitlab_read_authorizer_credential_secret_id = var.cloudbuildv2_repository_config.gitlab_read_authorizer_credential_secret_id
    gitlab_authorizer_credential_secret_id      = var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id
    gitlab_webhook_secret_id                    = var.cloudbuildv2_repository_config.gitlab_webhook_secret_id
    gitlab_enterprise_host_uri                  = var.cloudbuildv2_repository_config.gitlab_enterprise_host_uri
    gitlab_enterprise_service_directory         = var.cloudbuildv2_repository_config.gitlab_enterprise_service_directory
    gitlab_enterprise_ca_certificate            = var.cloudbuildv2_repository_config.gitlab_enterprise_ca_certificate
  }
  cloud_build_repositories = var.cloudbuildv2_repository_config.repositories

  depends_on = [time_sleep.wait_propagation]
}

resource "time_sleep" "wait_propagation" {
  create_duration = "120s"

  depends_on = [google_access_context_manager_service_perimeter_egress_policy.cloudbuild_egress_policy, google_access_context_manager_service_perimeter_dry_run_egress_policy.cloudbuild_egress_policy]
}

module "app_admin_project" {
  count = var.create_admin_project ? 1 : 0

  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  random_project_id        = true
  random_project_id_length = 4
  billing_account          = var.billing_account
  name                     = substr("${var.acronym}-${var.service_name}-admin", 0, 25) # max length 30 chars
  org_id                   = var.org_id
  folder_id                = var.folder_id
  deletion_policy          = "DELETE"
  default_service_account  = "KEEP"
  activate_apis = [
    "apikeys.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
    "sourcerepo.googleapis.com",
  ]

  disable_services_on_destroy = false
  disable_dependent_services  = false

  vpc_service_control_attach_dry_run = var.service_perimeter_name != null && var.service_perimeter_mode == "DRY_RUN"
  vpc_service_control_attach_enabled = var.service_perimeter_name != null && var.service_perimeter_mode == "ENFORCE"
  vpc_service_control_perimeter_name = var.service_perimeter_name

  activate_api_identities = [
    {
      api   = "compute.googleapis.com",
      roles = []
    },
    {
      api = "cloudbuild.googleapis.com",
      roles = [
        "roles/cloudbuild.builds.builder",
        "roles/cloudbuild.connectionAdmin",
      ]
    },
    {
      api   = "workflows.googleapis.com",
      roles = ["roles/workflows.serviceAgent"]
    },
    {
      api   = "config.googleapis.com",
      roles = ["roles/cloudconfig.serviceAgent"]
    },
    {
      api   = "container.googleapis.com",
      roles = ["roles/compute.networkUser", "roles/serviceusage.serviceUsageConsumer", "roles/container.serviceAgent"]
    },
  ]

}

resource "google_sourcerepo_repository" "app_infra_repo" {
  // conditionally create the cloud source repo if the user did not define a cloud build 2nd gen repository.
  count = local.use_csr ? 1 : 0

  project                      = local.admin_project_id
  name                         = "${var.service_name}-i-r"
  create_ignore_already_exists = true
}

module "tf_cloudbuild_workspace" {
  source  = "terraform-google-modules/bootstrap/google//modules/tf_cloudbuild_workspace"
  version = "~> 11.0"

  project_id               = local.admin_project_id
  tf_repo_uri              = local.use_csr ? google_sourcerepo_repository.app_infra_repo[0].url : module.cloudbuild_repositories[0].cloud_build_repositories_2nd_gen_repositories[var.service_name].id
  tf_repo_type             = local.use_csr ? "CLOUD_SOURCE_REPOSITORIES" : "CLOUDBUILD_V2_REPOSITORY"
  location                 = var.location
  trigger_location         = var.trigger_location
  artifacts_bucket_name    = "${var.bucket_prefix}-${local.admin_project_id}-${var.service_name}-build"
  create_state_bucket_name = "${var.bucket_prefix}-${local.admin_project_id}-${var.service_name}-state"
  log_bucket_name          = "${var.bucket_prefix}-${local.admin_project_id}-${var.service_name}-logs"
  buckets_force_destroy    = var.bucket_force_destroy
  cloudbuild_sa_roles      = local.cloudbuild_sa_roles

  substitutions = merge({
    "_GAR_REGION"                   = var.location
    "_GAR_PROJECT_ID"               = var.gar_project_id
    "_GAR_REPOSITORY"               = var.gar_repository_name
    "_DOCKER_TAG_VERSION_TERRAFORM" = var.docker_tag_version_terraform
    "_PRIVATE_POOL"                 = var.workerpool_id
  })

  cloudbuild_plan_filename  = "cloudbuild-tf-plan.yaml"
  cloudbuild_apply_filename = "cloudbuild-tf-apply.yaml"
  tf_apply_branches         = var.tf_apply_branches
}

resource "google_project_iam_member" "worker_pool_builder_logging_writer" {
  member  = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
  project = local.worker_pool_project
  role    = "roles/logging.logWriter"
}

resource "google_project_iam_member" "worker_pool_roles_privilegedaccessmanager_projectServiceAgent" {
  member  = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
  project = local.worker_pool_project
  role    = "roles/privilegedaccessmanager.projectServiceAgent"
}

resource "google_project_iam_member" "cloud_build_builder" {
  member  = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
  project = local.worker_pool_project
  role    = "roles/cloudbuild.builds.builder"
}

resource "google_project_iam_member" "workerPoolUser_cb_sa" {
  member  = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
  project = local.worker_pool_project
  role    = "roles/cloudbuild.workerPoolUser"
}

resource "google_project_iam_member" "connection_admin_cb_sa" {
  member  = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
  project = local.admin_project_id
  role    = "roles/cloudbuild.connectionAdmin"
}

resource "google_project_iam_member" "log_writer_cb_si" {
  member  = "serviceAccount:${data.google_project.admin_project.number}@cloudbuild.gserviceaccount.com"
  project = local.worker_pool_project
  role    = "roles/logging.logWriter"
}

resource "google_project_iam_member" "service_agent_cb_si" {
  member  = "serviceAccount:${data.google_project.admin_project.number}@cloudbuild.gserviceaccount.com"
  project = local.worker_pool_project
  role    = "roles/cloudbuild.builds.builder"
}

resource "google_project_iam_member" "cloud_build_sa_roles" {
  for_each = toset(["roles/storage.objectUser", "roles/artifactregistry.reader"])

  member  = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
  project = var.gar_project_id
  role    = each.value
}

resource "google_service_account_iam_member" "account_access" {
  for_each = toset(["roles/iam.serviceAccountUser", "roles/iam.serviceAccountTokenCreator"])

  service_account_id = module.tf_cloudbuild_workspace.cloudbuild_sa
  role               = each.value
  member             = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
}

resource "google_organization_iam_member" "builder_organization_browser" {
  for_each = toset(local.org_ids)
  member   = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
  org_id   = each.value
  role     = "roles/browser"
}

resource "google_organization_iam_member" "app_factory_org_organization_service_agent" {
  for_each = toset(local.org_ids)
  member   = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
  org_id   = each.value
  role     = "roles/privilegedaccessmanager.organizationServiceAgent"
}

resource "google_organization_iam_member" "organizationServiceAgent_role" {
  for_each = toset(local.org_ids)
  member   = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
  org_id   = each.value
  role     = "roles/privilegedaccessmanager.organizationServiceAgent"
}

resource "google_organization_iam_member" "organization_xpn_role" {
  for_each = toset(local.org_ids)
  member   = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
  org_id   = each.value
  role     = "roles/compute.xpnAdmin"
}

resource "google_organization_iam_member" "orgPolicyAdmin_role" {
  for_each = toset(local.org_ids)
  member   = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
  org_id   = each.value
  role     = "roles/orgpolicy.policyAdmin"
}

resource "google_organization_iam_member" "policyAdmin_role" {
  for_each = toset(local.org_ids)
  member   = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
  org_id   = each.value
  role     = "roles/accesscontextmanager.policyAdmin"
}

// Create infra project
module "app_infra_project" {
  source   = "terraform-google-modules/project-factory/google"
  version  = "~> 18.0"
  for_each = var.create_infra_project ? var.envs : {}

  random_project_id        = true
  random_project_id_length = 4
  billing_account          = each.value.billing_account
  name                     = substr("eab-${var.acronym}-${var.service_name}-${each.key}", 0, 25) # max length 30 chars
  org_id                   = each.value.org_id
  folder_id                = each.value.folder_id
  activate_apis            = var.infra_project_apis
  deletion_policy          = "DELETE"
  default_service_account  = "KEEP"

  vpc_service_control_attach_dry_run = var.service_perimeter_name != null && var.service_perimeter_mode == "DRY_RUN"
  vpc_service_control_attach_enabled = var.service_perimeter_name != null && var.service_perimeter_mode == "ENFORCE"
  vpc_service_control_perimeter_name = var.service_perimeter_name

  svpc_host_project_id = each.value.network_project_id
}

resource "google_project_iam_member" "secretManager_admin" {
  project = var.cloudbuildv2_repository_config.secret_project_id
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"
}
