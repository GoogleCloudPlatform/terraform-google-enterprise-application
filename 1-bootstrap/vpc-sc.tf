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

resource "google_access_context_manager_access_level_condition" "access-level-conditions" {
  count        = var.access_level_name != null ? 1 : 0
  access_level = var.access_level_name
  members      = concat([for sa in local.cb_service_accounts_emails : "serviceAccount:${sa}"], [google_service_account.builder.member])
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "access_to_remote_state_project" {
  count     = var.service_perimeter_name != null && var.access_level_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "storage-access_level-${var.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      access_level = var.access_level_name
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.project.number}"]
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

resource "google_access_context_manager_service_perimeter_egress_policy" "access_to_remote_state_project" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.access_level_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "storage-access_level-${var.project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      access_level = var.access_level_name
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.project.number}"]
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
