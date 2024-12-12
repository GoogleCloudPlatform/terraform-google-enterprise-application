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
        "roles/iam.serviceAccountUser", "roles/source.admin"
      ]
    } },
    {
      for cluster_project_id in var.cluster_projects_ids : cluster_project_id => {
        project_id = cluster_project_id
        roles      = ["roles/privilegedaccessmanager.projectServiceAgent"]
      }
    }
  )

  org_ids = distinct([for env in var.envs : env.org_id])
}


module "app_admin_project" {
  count = var.create_admin_project ? 1 : 0

  source  = "terraform-google-modules/project-factory/google"
  version = "~> 17.0"

  random_project_id        = true
  random_project_id_length = 4
  billing_account          = var.billing_account
  name                     = substr("${var.acronym}-${var.service_name}-admin", 0, 25) # max length 30 chars
  org_id                   = var.org_id
  folder_id                = var.folder_id
  deletion_policy          = "DELETE"
  default_service_account  = "KEEP"
  activate_apis = [
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudfunctions.googleapis.com",
    "apikeys.googleapis.com",
    "sourcerepo.googleapis.com",
    "clouddeploy.googleapis.com"
  ]

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
    }
  ]

}

resource "google_sourcerepo_repository" "app_infra_repo" {
  project                      = local.admin_project_id
  name                         = "${var.service_name}-i-r"
  create_ignore_already_exists = true
}

module "tf_cloudbuild_workspace" {
  source  = "terraform-google-modules/bootstrap/google//modules/tf_cloudbuild_workspace"
  version = "~> 10.0"

  project_id               = local.admin_project_id
  tf_repo_uri              = google_sourcerepo_repository.app_infra_repo.url
  tf_repo_type             = "CLOUD_SOURCE_REPOSITORIES"
  location                 = var.location
  trigger_location         = var.trigger_location
  artifacts_bucket_name    = "${var.bucket_prefix}-${local.admin_project_id}-${var.service_name}-build"
  create_state_bucket_name = "${var.bucket_prefix}-${local.admin_project_id}-${var.service_name}-state"
  log_bucket_name          = "${var.bucket_prefix}-${local.admin_project_id}-${var.service_name}-logs"
  buckets_force_destroy    = var.bucket_force_destroy
  cloudbuild_sa_roles      = local.cloudbuild_sa_roles

  substitutions = {
    "_GAR_REGION"                   = var.location
    "_GAR_PROJECT_ID"               = var.gar_project_id
    "_GAR_REPOSITORY"               = var.gar_repository_name
    "_DOCKER_TAG_VERSION_TERRAFORM" = var.docker_tag_version_terraform
  }

  cloudbuild_plan_filename  = "cloudbuild-tf-plan.yaml"
  cloudbuild_apply_filename = "cloudbuild-tf-apply.yaml"
  tf_apply_branches         = var.tf_apply_branches
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

// Create infra project
module "app_infra_project" {
  source   = "terraform-google-modules/project-factory/google"
  version  = "~> 17.0"
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
}
