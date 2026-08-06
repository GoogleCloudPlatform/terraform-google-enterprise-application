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
  app_admin_project = data.terraform_remote_state.appfactory.outputs.app-group["htc.htc"].app_admin_project_id
  app_infra_project = data.terraform_remote_state.appfactory.outputs.app-group["htc.htc"].app_infra_project_ids[local.env]

  gke_cluster_names        = data.terraform_remote_state.multitenant.outputs.cluster_names
  network_name             = data.terraform_remote_state.multitenant.outputs.network_names
  regions                  = data.terraform_remote_state.multitenant.outputs.cluster_regions
  cluster_project_id       = data.terraform_remote_state.multitenant.outputs.cluster_project_id
  cluster_project_number   = data.terraform_remote_state.multitenant.outputs.cluster_project_number
  remote_infra_bucket      = split("/", data.terraform_remote_state.appfactory.outputs.app-group["htc.htc"].app_cloudbuild_workspace_state_bucket_name)
  remote_infra_bucket_name = local.remote_infra_bucket[length(local.remote_infra_bucket) - 1]
}


data "terraform_remote_state" "bootstrap" {
  backend = "gcs"

  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/bootstrap"
  }
}

data "terraform_remote_state" "multitenant" {
  backend = "gcs"
  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/multi_tenant/${local.env}"
  }
}

data "terraform_remote_state" "appfactory" {
  backend = "gcs"

  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/appfactory/shared"
  }
}

data "terraform_remote_state" "appinfra" {
  backend = "gcs"

  config = {
    bucket = local.remote_infra_bucket_name
    prefix = "terraform/appinfra/htc/htc/shared"
  }
}
