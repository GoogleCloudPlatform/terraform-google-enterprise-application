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
  app_services = {
    "cymbal-bank" = [
      "balancereader",
      "contacts",
      "frontend",
      "ledgerwriter",
      "transactionhistory",
      "userservice",
    ]
  }

  expanded_app_services = flatten([
    for key, services in local.app_services : [
      for service in services : {
        app_name     = key
        service_name = service
      }
    ]
  ])
}

// One folder per application, will group admin/service projects under it
resource "google_folder" "app_folder" {
  for_each = local.app_services

  display_name = each.key
  parent       = var.common_folder_id
}

module "components" {
  for_each = tomap({
    for app_service in local.expanded_app_services : "${app_service.app_name}.${app_service.service_name}" => app_service
  })
  source = "../../modules/app-group-baseline"

  application_name    = each.value.service_name
  create_env_projects = true

  org_id               = var.org_id
  billing_account      = var.billing_account
  folder_id            = google_folder.app_folder[each.value.app_name].folder_id
  envs                 = var.envs
  bucket_prefix        = var.bucket_prefix
  location             = var.location
  trigger_location     = var.trigger_location
  bucket_force_destroy = var.bucket_force_destroy
  tf_apply_branches    = var.tf_apply_branches

  cloudbuild_sa_roles = {
    development = {
      roles = ["roles/owner"]
    }
    nonproduction = {
      roles = ["roles/owner"]
    }
    production = {
      roles = ["roles/owner"]
    }
  }
}
