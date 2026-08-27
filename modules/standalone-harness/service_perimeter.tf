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

###############################################
#              EGRESS POLICIES                #
###############################################

resource "google_access_context_manager_service_perimeter_egress_policy" "secret_manager_egress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.create_project && var.network_id != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "scr-${local.project_id}-to-${local.workerpool_network_project_id}"
  egress_from {
    identities = ["serviceAccount:service-${local.workerpool_project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
    sources {
      resource = "projects/${local.workerpool_project_number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_network_project[0].number}"]
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
  count     = var.service_perimeter_name != null && var.create_project && var.network_id != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "scr-${local.project_id}-to-${local.workerpool_network_project_id}"
  egress_from {
    identities = ["serviceAccount:service-${local.workerpool_project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
    sources {
      resource = "projects/${local.workerpool_project_number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_network_project[0].number}"]
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
  count     = var.service_perimeter_name != null && var.create_project && var.bucket_kms_key != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "kms-stor-${local.project_id}-${data.google_project.kms_project[0].project_id}"
  egress_from {
    identities = ["serviceAccount:service-${local.workerpool_project_number}@gs-project-accounts.iam.gserviceaccount.com", "serviceAccount:${local.workerpool_project_number}-compute@developer.gserviceaccount.com"]
    sources {
      resource = "projects/${local.workerpool_project_number}"
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

resource "google_access_context_manager_service_perimeter_egress_policy" "admin_to_kms_egress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.create_project && var.bucket_kms_key != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "kms-stor-${local.project_id}-${data.google_project.kms_project[0].project_id}"
  egress_from {
    identities = ["serviceAccount:service-${local.workerpool_project_number}@gs-project-accounts.iam.gserviceaccount.com", "serviceAccount:${local.workerpool_project_number}-compute@developer.gserviceaccount.com"]
    sources {
      resource = "projects/${local.workerpool_project_number}"
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

resource "google_access_context_manager_service_perimeter_egress_policy" "service_directory_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.create_project && var.service_perimeter_name != null && var.create_project && var.network_id != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "srvdir-${local.project_id}-${data.google_project.workerpool_network_project[0].project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${local.workerpool_project_number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_network_project[0].number}"]
    operations {
      service_name = "servicedirectory.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "service_directory_policy" {
  count     = var.create_project && var.service_perimeter_name != null && var.create_project && var.network_id != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "srvdir-${local.project_id}-${data.google_project.workerpool_network_project[0].project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${local.workerpool_project_number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_network_project[0].number}"]
    operations {
      service_name = "servicedirectory.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}


resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "ingress_to_kms_project" {
  count     = var.service_perimeter_name != null && var.create_project && var.bucket_kms_key != null && var.network_id != null ? 1 : 0
  title     = "llm-model-cicd-${local.workerpool_network_project_id}-to-${data.google_project.kms_project[0].project_id}"
  perimeter = var.service_perimeter_name
  ingress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.workerpool_network_project[0].number}"
    }
  }
  ingress_to {
    resources = [
      "projects/${data.google_project.kms_project[0].number}",
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
      service_name = "iamcredentials.googleapis.com"
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
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_ingress_policy" "ingress_to_kms_project" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.create_project && var.bucket_kms_key != null && var.network_id != null ? 1 : 0
  title     = "llm-model-cicd-${local.workerpool_network_project_id}-to-${data.google_project.kms_project[0].project_id}"
  perimeter = var.service_perimeter_name
  ingress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.workerpool_network_project[0].number}"
    }
  }
  ingress_to {
    resources = [
      "projects/${data.google_project.kms_project[0].number}",
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
      service_name = "iamcredentials.googleapis.com"
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
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "time_sleep" "wait_access_level_propagation" {
  depends_on = [
    google_access_context_manager_service_perimeter_dry_run_egress_policy.admin_to_kms_egress_policy,
    google_access_context_manager_service_perimeter_dry_run_egress_policy.service_directory_policy,
    google_access_context_manager_service_perimeter_dry_run_egress_policy.secret_manager_egress_policy,
    google_access_context_manager_service_perimeter_egress_policy.admin_to_kms_egress_policy,
    google_access_context_manager_service_perimeter_egress_policy.service_directory_policy,
    google_access_context_manager_service_perimeter_egress_policy.secret_manager_egress_policy,
    google_access_context_manager_service_perimeter_ingress_policy.ingress_to_kms_project,
    google_access_context_manager_service_perimeter_dry_run_ingress_policy.ingress_to_kms_project,
  ]
  destroy_duration = "5m"
  create_duration  = "2m"
}
