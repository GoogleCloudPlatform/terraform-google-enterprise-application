/**
 * Copyright 2025 Google LLC
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
  cluster_membership_ids = { for state in data.terraform_remote_state.multitenant : (state.outputs.env) => { "cluster_membership_ids" = (state.outputs.cluster_membership_ids) } }
  cluster_service_accounts = zipmap(
    flatten(
      [for item in data.terraform_remote_state.multitenant : keys(item.outputs.cluster_service_accounts)]
    ),
    flatten(
      [for item in data.terraform_remote_state.multitenant : values(item.outputs.cluster_service_accounts)]
    )
  )
  cluster_projects_id = { for state in data.terraform_remote_state.multitenant : (state.outputs.env) => state.outputs.cluster_project_id }
  app_admin_project   = data.terraform_remote_state.appfactory.outputs.app-group["agent.capital-agent"].app_admin_project_id
}

data "terraform_remote_state" "multitenant" {
  for_each = toset(var.environment_names)

  backend = "gcs"

  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/multi_tenant/${each.value}"
  }
}

data "terraform_remote_state" "appfactory" {
  backend = "gcs"

  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/appfactory/shared"
  }
}

data "terraform_remote_state" "bootstrap" {
  backend = "gcs"

  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/bootstrap"
  }
}

data "terraform_remote_state" "fleetscope" {
  for_each = toset(var.environment_names)

  backend = "gcs"

  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/fleet_scope/${each.value}"
  }
}
