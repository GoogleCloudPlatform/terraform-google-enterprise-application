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
  hpc_specific_applications = ["hpc-team-a", "hpc-team-b"]
}

###############################################
#              EGRESS POLICIES                #
###############################################

resource "google_access_context_manager_service_perimeter_egress_policy" "backend_egress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "bkt-${data.google_project.admin_project.project_id}-${data.google_project.remote_state_project.project_id}"
  egress_from {
    identities = ["serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"]
  }
  egress_to {
    resources = ["projects/${data.google_project.remote_state_project.number}"]
    operations {
      service_name = "storage.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "backend_egress_policy" {
  count     = var.service_perimeter_name != null && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "bkt-${data.google_project.admin_project.project_id}-${data.google_project.remote_state_project.project_id}"
  egress_from {
    identities = ["serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"]
  }
  egress_to {
    resources = ["projects/${data.google_project.remote_state_project.number}"]
    operations {
      service_name = "storage.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_egress_policy" "secret_manager_egress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.create_admin_project && local.secret_project_number != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "scr-${data.google_project.admin_project.project_id}-${local.secret_project_number}"
  egress_from {
    identities = ["serviceAccount:service-${data.google_project.admin_project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
    sources {
      resource = "projects/${data.google_project.admin_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${local.secret_project_number}"]
    operations {
      service_name = "secretmanager.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "secret_manager_egress_policy" {
  count     = var.service_perimeter_name != null && var.create_admin_project && local.secret_project_number != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "scr-${data.google_project.admin_project.project_id}-${local.secret_project_number}"
  egress_from {
    identities = ["serviceAccount:service-${module.app_admin_project[0].project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
    sources {
      resource = "projects/${data.google_project.admin_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${local.secret_project_number}"]
    operations {
      service_name = "secretmanager.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "admin_to_kms_egress_policy" {
  count     = var.service_perimeter_name != null && var.create_admin_project && var.kms_project_id != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "kms-${data.google_project.admin_project.project_id}-${data.google_project.kms_project[0].project_id}"
  egress_from {
    identities = ["serviceAccount:service-${module.app_admin_project[0].project_number}@gs-project-accounts.iam.gserviceaccount.com"]
    sources {
      resource = "projects/${data.google_project.admin_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.kms_project[0].number}"]
    operations {
      service_name = "cloudkms.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_egress_policy" "admin_to_kms_egress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.create_admin_project && var.kms_project_id != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "kms-${data.google_project.admin_project.project_id}-${data.google_project.kms_project[0].project_id}"
  egress_from {
    identities = ["serviceAccount:service-${module.app_admin_project[0].project_number}@gs-project-accounts.iam.gserviceaccount.com"]
    sources {
      resource = "projects/${data.google_project.admin_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.kms_project[0].number}"]
    operations {
      service_name = "cloudkms.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "env_to_kms_egress_policy" {
  for_each  = var.service_perimeter_mode == "DRY_RUN" && var.service_perimeter_name != null && var.kms_project_id != null && var.create_infra_project ? data.google_storage_project_service_account.gcs_account : {}
  perimeter = var.service_perimeter_name
  title     = "kms-${each.value.project}-${data.google_project.kms_project[0].project_id}"
  egress_from {
    identities = [each.value.member]
    sources {
      resource = "projects/${module.app_infra_project[each.key].project_number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.kms_project[0].number}"]
    operations {
      service_name = "cloudkms.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_egress_policy" "env_to_kms_egress_policy" {
  for_each  = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.kms_project_id != null && var.create_infra_project ? data.google_storage_project_service_account.gcs_account : {}
  perimeter = var.service_perimeter_name
  title     = "kms-${each.value.project}-${data.google_project.kms_project[0].project_id}"
  egress_from {
    identities = [each.value.member]
    sources {
      resource = "projects/${module.app_infra_project[each.key].project_number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.kms_project[0].number}"]
    operations {
      service_name = "cloudkms.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_egress_policy" "cloudbuild_egress_admin_to_workerpool_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "cicd-${data.google_project.admin_project.project_id}-${data.google_project.workerpool_project.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.admin_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_project.number}"]
    operations {
      service_name = "cloudbuild.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "clouddeploy.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "logging.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "cloudbuild_egress_admin_to_workerpool_policy" {
  count     = var.service_perimeter_name != null && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "cicd-${data.google_project.admin_project.project_id}-${data.google_project.workerpool_project.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.admin_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_project.number}"]
    operations {
      service_name = "cloudbuild.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "clouddeploy.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "logging.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_egress_policy" "clouddeploy_egress_policy_admin_to_gke_cluster" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "depl-${data.google_project.admin_project.project_id}-gke"
  egress_from {
    identity_type = "ANY_IDENTITY"
  }
  egress_to {
    resources = [for project in data.google_project.clusters_projects : "projects/${project.number}"]
    operations {
      service_name = "clouddeploy.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "clouddeploy_egress_policy_admin_to_gke_cluster" {
  count     = var.create_admin_project && var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "depl-${data.google_project.admin_project.project_id}-gke"
  egress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.admin_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = [for project in data.google_project.clusters_projects : "projects/${project.number}"]
    operations {
      service_name = "clouddeploy.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_egress_policy" "service_directory_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "srvdir-${data.google_project.admin_project.project_id}-${data.google_project.workerpool_project.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.admin_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_project.number}"]
    operations {
      service_name = "servicedirectory.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "service_directory_policy" {
  count     = var.create_admin_project && var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "srvdir-${data.google_project.admin_project.project_id}-${data.google_project.workerpool_project.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.admin_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_project.number}"]
    operations {
      service_name = "servicedirectory.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
}

resource "google_access_context_manager_service_perimeter_egress_policy" "hpc_allow_infra_projects_to_use_workerpool" {
  // Create egress policy only if it is an HPC application (as defined in 'hpc_specific_applications')
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && contains(local.hpc_specific_applications, var.service_name) ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "hpc-${var.service_name}-infra-${data.google_project.workerpool_project.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    dynamic "sources" {
      for_each = module.app_infra_project
      content {
        resource = "projects/${sources.value.project_number}"
      }
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_project.number}"]
    operations {
      service_name = "cloudbuild.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "hpc_allow_infra_projects_to_use_workerpool" {
  // Create egress policy only if it is an HPC application (as defined in 'hpc_specific_applications')
  count     = contains(local.hpc_specific_applications, var.service_name) && var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "HPC-${var.service_name}-infra-${data.google_project.workerpool_project.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    dynamic "sources" {
      for_each = module.app_infra_project
      content {
        resource = "projects/${sources.value.project_number}"
      }
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_project.number}"]
    operations {
      service_name = "cloudbuild.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
}

resource "google_access_context_manager_service_perimeter_egress_policy" "egress_from_vpc_project_to_admin" {
  // Create egress policy only if it is an HPC application (as defined in 'hpc_specific_applications')
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "vpc-to-${data.google_project.admin_project.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    dynamic "sources" {
      for_each = data.google_project.vpc_projects
      content {
        resource = "projects/${sources.value.number}"
      }
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.admin_project.number}"]
    operations {
      service_name = "containerfilesystem.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "egress_from_vpc_project_to_admin" {
  count     = var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "vpc-to-${data.google_project.admin_project.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    dynamic "sources" {
      for_each = data.google_project.vpc_projects
      content {
        resource = "projects/${sources.value.number}"
      }
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.admin_project.number}"]
    operations {
      service_name = "containerfilesystem.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
}

###############################################
#              INGRESS POLICIES               #
###############################################

# This ingress policy configures the necessary permissions for Cloud Deploy and Worker Pool to deploy the workload on the GKE cluster project
resource "google_access_context_manager_service_perimeter_ingress_policy" "ingress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "cicd-[${data.google_project.admin_project.project_id}, ${data.google_project.workerpool_project.project_id}] to Deployment API's"
  ingress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.admin_project.number}"
    }
    sources {
      resource = "projects/${data.google_project.workerpool_project.number}"
    }
  }
  ingress_to {
    resources = ["*"]
    operations {
      service_name = "logging.googleapis.com"
      method_selectors {
        method = "*"
      }
    }

    operations {
      service_name = "artifactregistry.googleapis.com"
      method_selectors {
        method = "*"
      }
    }

    operations {
      service_name = "storage.googleapis.com"
      method_selectors {
        method = "*"
      }
    }

    operations {
      service_name = "clouddeploy.googleapis.com"
      method_selectors {
        method = "*"
      }
    }

    operations {
      service_name = "gkehub.googleapis.com"
      method_selectors {
        method = "*"
      }
    }

    operations {
      service_name = "connectgateway.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "cloudkms.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "containeranalysis.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "compute.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }

}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "ingress_policy" {
  count     = var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "cicd-[${data.google_project.admin_project.project_id}, ${data.google_project.workerpool_project.project_id}] to Deployment API's"
  ingress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.admin_project.number}"
    }
    sources {
      resource = "projects/${data.google_project.workerpool_project.number}"
    }
  }
  ingress_to {
    resources = ["*"]
    operations {
      service_name = "logging.googleapis.com"
      method_selectors {
        method = "*"
      }
    }

    operations {
      service_name = "artifactregistry.googleapis.com"
      method_selectors {
        method = "*"
      }
    }

    operations {
      service_name = "storage.googleapis.com"
      method_selectors {
        method = "*"
      }
    }

    operations {
      service_name = "clouddeploy.googleapis.com"
      method_selectors {
        method = "*"
      }
    }

    operations {
      service_name = "gkehub.googleapis.com"
      method_selectors {
        method = "*"
      }
    }

    operations {
      service_name = "connectgateway.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "cloudkms.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "containeranalysis.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "compute.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

# This ingress policy configures the necessary permissions for Cloud Deploy and Worker Pool to deploy the workload on the GKE cluster project
resource "google_access_context_manager_service_perimeter_ingress_policy" "identities_search_ingress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "identities-[${data.google_project.admin_project.project_id}, ${data.google_project.workerpool_project.project_id}]-cicd"
  ingress_from {
    identities = ["serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"]
    sources {
      access_level = "*"
    }
  }
  ingress_to {
    resources = ["*"]
    operations {
      service_name = "storage.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "compute.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "iam.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "binaryauthorization.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "cloudresourcemanager.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "clouddeploy.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "serviceusage.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "artifactregistry.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "cloudbuild.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "gkehub.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "identities_search_ingress_policy" {
  count     = var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "identities-[${data.google_project.admin_project.project_id}, ${data.google_project.workerpool_project.project_id}]-cicd"
  ingress_from {
    identities = ["serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"]
    sources {
      access_level = "*"
    }
  }
  ingress_to {
    resources = ["*"]
    operations {
      service_name = "storage.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "compute.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "iam.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "binaryauthorization.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "cloudresourcemanager.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "clouddeploy.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "serviceusage.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "artifactregistry.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "cloudbuild.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "gkehub.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}
