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

# Setup

locals {
  subnet_ip                  = "10.3.0.0/24"
  proxy_ip                   = "10.3.0.10"
  private_service_connect_ip = "10.2.0.0"
  peering_address            = "192.165.0.0"
}

resource "google_compute_subnetwork" "swp_subnetwork_proxy" {
  name          = "sb-swp-${var.region}"
  ip_cidr_range = "10.129.0.0/23"
  project       = var.project_id
  region        = var.region
  network       = var.network_id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_access_context_manager_service_perimeter_egress_policy" "egress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" ? 1 : 0
  perimeter = var.service_perimeter_name
  egress_from {
    identity_type = "ANY_IDENTITY"
  }
  egress_to {
    resources = [
      "projects/342927644502",
      "projects/213358688945",
      "projects/907015832414"
    ] //google project, bank of anthos

    operations {
      service_name = "cloudbuild.googleapis.com"
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
      service_name = "secretmanager.googleapis.com"
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

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "egress_policy" {
  count     = var.service_perimeter_mode == "DRY_RUN" ? 1 : 0
  perimeter = var.service_perimeter_name
  egress_from {
    identity_type = "ANY_IDENTITY"
  }
  egress_to {
    resources = [
      "projects/342927644502",
      "projects/213358688945",
      "projects/907015832414"
    ] //google project, bank of anthos

    operations {
      service_name = "cloudbuild.googleapis.com"
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
      service_name = "secretmanager.googleapis.com"
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

resource "time_sleep" "wait_propagation" {
  depends_on = [
    google_access_context_manager_service_perimeter_egress_policy.egress_policy,
  ]
  create_duration  = "1m"
  destroy_duration = "1m"
}

