# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  cloud_build_sas = ["serviceAccount:${google_service_account.cloud_build.email}"] # cloud build service accounts used for CI
  membership_re   = "projects/([^/]*)/locations/([^/]*)/memberships/([^/]*)$"
  envs            = keys(var.env_cluster_membership_ids)

  memberships     = flatten([for i in local.envs : var.env_cluster_membership_ids[i].cluster_membership_ids])
  memberships_map = { for i, item in local.memberships : (i) => item }
  gke_projects    = { for i, item in local.memberships : (i) => regex(local.membership_re, item)[0] }
}
# authoritative project-iam-bindings to increase reproducibility
module "project-iam-bindings" {
  source   = "terraform-google-modules/iam/google//modules/projects_iam"
  version  = "~> 8.0"
  projects = [var.project_id]
  mode     = "authoritative"

  bindings = {
    "roles/cloudtrace.agent" = [
      data.google_compute_default_service_account.compute_service_identity.member
    ],
    "roles/monitoring.metricWriter" = [
      data.google_compute_default_service_account.compute_service_identity.member
    ],
    "roles/logging.logWriter" = setunion(
      [
        data.google_compute_default_service_account.compute_service_identity.member,
        "serviceAccount:${google_service_account.cloud_deploy.email}"
      ],
      local.cloud_build_sas
    ),
    "roles/cloudbuild.builds.builder" = setunion(
      [
        google_project_service_identity.cloudbuild_service_identity.member,
      ],
      local.cloud_build_sas
    ),
    "roles/gkehub.gatewayEditor" = [
      "serviceAccount:${google_service_account.cloud_deploy.email}"
    ],
    "roles/gkehub.viewer" = setunion(
      local.cloud_build_sas,
      [
        "serviceAccount:${google_service_account.cloud_deploy.email}"
      ],
    ),
    "roles/clouddeploy.releaser" = local.cloud_build_sas,
    "roles/container.developer" = [
      "serviceAccount:${google_service_account.cloud_deploy.email}"
    ],
    "roles/container.admin" = [
      "serviceAccount:${google_service_account.cloud_deploy.email}"
    ],
  }
}


// added to avoid overwriten of roles for each app service deploy service account, since GKE projects are shared between services
module "cb-gke-project-iam-bindings" {
  source     = "terraform-google-modules/iam/google//modules/member_iam"
  version    = "~> 8.0"
  for_each   = local.gke_projects
  project_id = each.value

  project_roles           = ["roles/container.admin", "roles/container.developer", "roles/gkehub.viewer", "roles/gkehub.gatewayEditor"]
  prefix                  = "serviceAccount"
  service_account_address = google_service_account.cloud_build.email
}

module "deploy-gke-project-iam-bindings" {
  source     = "terraform-google-modules/iam/google//modules/member_iam"
  version    = "~> 8.0"
  for_each   = local.gke_projects
  project_id = each.value

  project_roles           = ["roles/container.admin", "roles/container.developer", "roles/gkehub.viewer", "roles/gkehub.gatewayEditor"]
  prefix                  = "serviceAccount"
  service_account_address = google_service_account.cloud_deploy.email
}
