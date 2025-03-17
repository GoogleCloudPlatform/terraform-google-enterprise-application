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

resource "google_access_context_manager_service_perimeter_egress_policy" "secret_manager_egress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.create_admin_project ? 1 : 0
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
  count     = var.service_perimeter_mode == "DRY_RUN" && var.create_admin_project ? 1 : 0
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
  title     = "Cloud Build and Logging Egress from ${data.google_project.admin_project.project_id} to ${data.google_project.workerpool_project.project_id}"
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
  title     = "Cloud Build and Logging Egress from ${data.google_project.admin_project.project_id} to ${data.google_project.workerpool_project.project_id}"
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

resource "google_access_context_manager_service_perimeter_ingress_policy" "logging_ingress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Logging Ingress from ${data.google_project.workerpool_project.project_id} to ${data.google_project.admin_project.project_id}"
  ingress_from {
    sources {
      resource = "projects/${data.google_project.workerpool_project.number}"
    }
  }
  ingress_to {
    resources = ["projects/${data.google_project.admin_project.number}"]
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

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "logging_ingress_policy" {
  count     = var.service_perimeter_mode == "DRY_RUN" && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Logging Ingress from ${data.google_project.workerpool_project.project_id} to ${data.google_project.admin_project.project_id}"
  ingress_from {
    sources {
      resource = "projects/${data.google_project.workerpool_project.number}"
    }
  }
  ingress_to {
    resources = ["projects/${data.google_project.admin_project.number}"]
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

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "storage_logging_ingress_policy" {
  count     = var.service_perimeter_mode == "DRY_RUN" && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Logging Ingress from ${data.google_project.gar_project.project_id} to ${data.google_project.admin_project.project_id}"
  ingress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.gar_project.number}"
    }
  }
  ingress_to {
    resources = ["projects/${data.google_project.admin_project.number}"]
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
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_ingress_policy" "storage_logging_ingress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.create_admin_project ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Logging Ingress from ${data.google_project.gar_project.project_id} to ${data.google_project.admin_project.project_id}"
  ingress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.gar_project.number}"
    }
  }
  ingress_to {
    resources = ["projects/${data.google_project.admin_project.number}"]
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
  }
  lifecycle {
    create_before_destroy = true
  }
}
