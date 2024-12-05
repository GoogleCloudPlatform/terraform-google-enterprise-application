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
  application_names = [for k, v in var.applications : k]

  expanded_microservices = flatten([
    for key, services in var.applications : [
      for service_name, service in services : {
        app_name     = key
        service_name = service_name
        acronym      = local.acronym[key]
        service      = service
      }
    ]
  ])
  use_csr   = var.cloudbuildv2_repository_config.repo_type == "CSR"
  csr_repos = local.use_csr ? [for k, v in var.cloudbuildv2_repository_config.repositories : v.repository_name] : []
}

// One folder per application, will group admin/service projects under it
resource "google_folder" "app_folder" {
  for_each = toset(local.application_names)

  display_name        = each.key
  parent              = var.common_folder_id
  deletion_protection = false
}

module "components" {
  source = "../../modules/app-group-baseline"

  for_each = tomap({
    for app_service in local.expanded_microservices : "${app_service.app_name}.${app_service.service_name}" => app_service
  })

  service_name = each.value.service_name
  acronym      = each.value.acronym

  org_id                       = var.org_id
  billing_account              = var.billing_account
  folder_id                    = google_folder.app_folder[each.value.app_name].folder_id
  envs                         = var.envs
  bucket_prefix                = var.bucket_prefix
  location                     = var.location
  trigger_location             = var.trigger_location
  bucket_force_destroy         = var.bucket_force_destroy
  tf_apply_branches            = var.tf_apply_branches
  gar_project_id               = local.gar_project_id
  gar_repository_name          = local.gar_image_name
  docker_tag_version_terraform = local.gar_tag_version
  cluster_projects_ids         = local.cluster_projects_ids

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

  // microservices-specific configuration to baseline module
  admin_project_id     = each.value.service.admin_project_id
  create_admin_project = each.value.service.create_admin_project
  create_infra_project = each.value.service.create_infra_project


  cloudbuildv2_repository_config = var.cloudbuildv2_repository_config
}
