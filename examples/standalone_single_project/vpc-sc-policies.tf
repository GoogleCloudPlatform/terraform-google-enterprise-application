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


data "google_project" "workerpool_project" {
  project_id = local.worker_pool_project
}


###############################################
#              EGRESS POLICIES                #
###############################################

resource "google_access_context_manager_service_perimeter_egress_policy" "egress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" ? 1 : 0
  perimeter = var.service_perimeter_name
  egress_from {
    identities = ["serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
  }
  egress_to {
    resources = [for project_number in local.secret_project_numbers : "projects/${project_number}"]
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

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "egress_policy" {
  perimeter = var.service_perimeter_name
  egress_from {
    identities = ["serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
  }
  egress_to {
    resources = [for project_number in local.secret_project_numbers : "projects/${project_number}"]
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

resource "google_access_context_manager_service_perimeter_egress_policy" "service_directory_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Allow Services from ${data.google_project.project.project_id} to ${data.google_project.workerpool_project.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.project.number}"
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
      service_name = "compute.googleapis.com"
      method_selectors {
        method = "SubnetworksService.Get"
      }
    }
  }
}

###############################################
#              INGRESS POLICIES               #
###############################################

resource "google_access_context_manager_service_perimeter_ingress_policy" "ingress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" ? 1 : 0
  perimeter = var.service_perimeter_name
  ingress_from {
    identities = local.sa_cb
    sources {
      access_level = "*"
    }
  }
  ingress_to {
    resources = [
      "projects/${data.google_project.project.number}",
    ]

    operations {
      service_name = "cloudbuild.googleapis.com"
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
  perimeter = var.service_perimeter_name
  ingress_from {
    identities = local.sa_cb
    sources {
      access_level = "*"
    }
  }
  ingress_to {
    resources = [
      "projects/${data.google_project.project.number}",
    ]

    operations {
      service_name = "cloudbuild.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "cymbal_bank_private_deployment" {
  title     = "Allow from ${data.google_project.workerpool_project.project_id} API's for private gkehub deployment"
  perimeter = var.service_perimeter_name
  ingress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.workerpool_project.number}"
    }
  }
  ingress_to {
    resources = [
      "projects/${data.google_project.project.number}",
    ]

    operations {
      service_name = "storage.googleapis.com"
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
    operations {
      service_name = "artifactregistry.googleapis.com"
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
      service_name = "binaryauthorization.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_ingress_policy" "cymbal_bank_private_deployment" {
  count     = var.service_perimeter_mode == "ENFORCE" ? 1 : 0
  title     = "Allow from ${data.google_project.workerpool_project.project_id} API's for private gkehub deployment"
  perimeter = var.service_perimeter_name
  ingress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.workerpool_project.number}"
    }
  }
  ingress_to {
    resources = [
      "projects/${data.google_project.project.number}",
    ]

    operations {
      service_name = "storage.googleapis.com"
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
    operations {
      service_name = "artifactregistry.googleapis.com"
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
      service_name = "binaryauthorization.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}
