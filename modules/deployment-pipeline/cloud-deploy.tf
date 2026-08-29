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

# create delivery pipeline for service including all targets
resource "google_clouddeploy_delivery_pipeline" "delivery-pipeline" {
  project  = var.project_id
  location = var.region
  name     = var.service_name
  serial_pipeline {
    dynamic "stages" {
      for_each = google_clouddeploy_target.clouddeploy_targets
      content {
        # TODO: use "production" profile once validated.
        profiles  = [endswith(stages.value.anthos_cluster[0].membership, "-development") ? "development" : (endswith(stages.value.anthos_cluster[0].membership, "-nonproduction") ? "staging" : "production")]
        target_id = stages.value.name
      }
    }
  }
}

data "google_project" "eab_cluster_project" {
  for_each   = local.gke_projects
  project_id = each.value
}

data "google_project" "eab_workerpool_project" {
  count      = var.private_workerpool.use_private_workerpool ? 1 : 0
  project_id = local.worker_pool_project
}

resource "google_access_context_manager_service_perimeter_egress_policy" "clouddeploy_egress_cluster_to_workerpool_policy" {
  count     = var.service_perimeter_name != null && var.service_perimeter_mode == "ENFORCE" && var.private_workerpool.use_private_workerpool ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "deploy-${join(",", values(local.gke_projects))}-${local.worker_pool_project}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    dynamic "sources" {
      for_each = data.google_project.eab_cluster_project
      content {
        resource = "projects/${sources.value.number}"
      }
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.eab_workerpool_project[0].number}"]
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

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "clouddeploy_egress_cluster_to_workerpool_policy" {
  count     = var.service_perimeter_name != null && var.private_workerpool.use_private_workerpool ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "deploy-${join(",", values(local.gke_projects))}-${local.worker_pool_project}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    dynamic "sources" {
      for_each = data.google_project.eab_cluster_project
      content {
        resource = "projects/${sources.value.number}"
      }
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.eab_workerpool_project[0].number}"]
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
