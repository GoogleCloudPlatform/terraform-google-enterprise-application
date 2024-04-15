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
}

# authoritative project-iam-bindings to increase reproducibility
module "project-iam-bindings" {
  source   = "terraform-google-modules/iam/google//modules/projects_iam"
  version  = "~> 7.7"
  projects = [var.project_id, regex(local.membership_re, var.cluster_membership_id_dev)[0], regex(local.membership_re, var.cluster_membership_ids_nonprod[0])[0], regex(local.membership_re, var.cluster_membership_ids_prod[0])[0]]
  mode     = "additive"

  bindings = {
    "roles/cloudtrace.agent" = [
      "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
    ],
    "roles/monitoring.metricWriter" = [
      "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
    ],
    "roles/logging.logWriter" = setunion(
      [
        "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com",
        "serviceAccount:${google_service_account.cloud_deploy.email}"
      ],
      local.cloud_build_sas
    ),
    "roles/cloudbuild.builds.builder" = setunion(
      [
        "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com",
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
  }
}
