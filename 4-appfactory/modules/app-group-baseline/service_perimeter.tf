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
  infra_projects            = [for key, value in module.app_infra_project : value.project_id]
  hpc_specific_applications = ["hpc-team-a", "hpc-team-b"]
}

###############################################
#              EGRESS POLICIES                #
###############################################

resource "google_access_context_manager_service_perimeter_egress_policy" "secret_manager_egress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Secret Manager Egress from ${data.google_project.admin_project.project_id} to ${local.secret_project_number}"
  egress_from {
    identities = ["serviceAccount:service-${data.google_project.admin_project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
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
  count     = var.service_perimeter_mode == "DRY_RUN" && var.service_perimeter_name != null && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Secret Manager Egress from ${data.google_project.admin_project.project_id} to ${local.secret_project_number}"
  egress_from {
    identities = ["serviceAccount:service-${module.app_admin_project[0].project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
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

resource "google_access_context_manager_service_perimeter_egress_policy" "cloudbuild_egress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Egress from ${data.google_project.admin_project.project_id} to ${data.google_project.workerpool_project.project_id}"
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

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "cloudbuild_egress_policy" {
  count     = var.service_perimeter_mode == "DRY_RUN" && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Egress from ${data.google_project.admin_project.project_id} to ${data.google_project.workerpool_project.project_id}"
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

resource "google_access_context_manager_service_perimeter_egress_policy" "clouddeploy_egress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Cloud Deploy from ${data.google_project.admin_project.project_id} to ${data.google_project.workerpool_project.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    dynamic "sources" {
      for_each = data.google_project.clusters_projects
      content {
        resource = "projects/${sources.value.number}"
      }
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_project.number}"]
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

resource "google_access_context_manager_service_perimeter_egress_policy" "clouddeploy_egress_policy_to_gke_cluster" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Cloud Deploy from ${data.google_project.admin_project.project_id} to GKE Cluster Projects"
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

resource "google_access_context_manager_service_perimeter_egress_policy" "service_directory_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Allow Service Directory from ${data.google_project.admin_project.project_id} to ${data.google_project.workerpool_project.project_id}"
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

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "clouddeploy_egress_policy" {
  count     = var.service_perimeter_mode == "DRY_RUN" && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Cloud Deploy Egress from ${join(", ", var.cluster_projects_ids)} to ${data.google_project.workerpool_project.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    dynamic "sources" {
      for_each = data.google_project.clusters_projects
      content {
        resource = "projects/${sources.value.number}"
      }
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_project.number}"]
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

resource "google_access_context_manager_service_perimeter_egress_policy" "hpc_allow_infra_projects_to_use_workerpool" {
  // Create egress policy only if it is an HPC application (as defined in 'hpc_specific_applications')
  count     = var.service_perimeter_mode == "ENFORCE" && contains(local.hpc_specific_applications, var.service_name) ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "HPC - Allow from [${join(", ", local.infra_projects)}] to ${data.google_project.workerpool_project.project_id}"
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

###############################################
#              INGRESS POLICIES               #
###############################################

# This ingress policy configures the necessary permissions for Cloud Deploy and Worker Pool to deploy the workload on the GKE cluster project
resource "google_access_context_manager_service_perimeter_ingress_policy" "ingress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Ingress from [${data.google_project.admin_project.project_id}, ${data.google_project.workerpool_project.project_id}] to Deployment API's"
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
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_access_level_condition" "access-level-conditions" {
  count        = var.access_level_name != null ? 1 : 0
  access_level = var.access_level_name
  members      = ["serviceAccount:${reverse(split("/", module.tf_cloudbuild_workspace.cloudbuild_sa))[0]}"]
}
