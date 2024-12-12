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

resource "google_gke_hub_feature" "poco_feature" {
  name     = "policycontroller"
  location = "global"
  project  = var.fleet_project_id

  fleet_default_member_config {
    policycontroller {
      policy_controller_hub_config {
        audit_interval_seconds = 60
        install_spec           = "INSTALL_SPEC_ENABLED"
        policy_content {
          bundles {
            bundle = "pss-baseline-v2022"
          }
          bundles {
            bundle = "policy-essentials-v2022"
          }
          template_library {
            installation = "ALL"
          }
        }
        referential_rules_enabled = true
      }
    }
  }

  depends_on = [
    google_gke_hub_feature.mcs,
    google_gke_hub_feature.mci
  ]
}

resource "google_gke_hub_feature_membership" "poco_feature_member" {
  for_each = local.cluster_membership_ids
  location = "global"
  project  = var.fleet_project_id

  feature             = google_gke_hub_feature.poco_feature.name
  membership          = regex(local.membership_re, each.value)[2]
  membership_location = regex(local.membership_re, each.value)[1]

  policycontroller {
    policy_controller_hub_config {
      audit_interval_seconds = 60
      install_spec           = "INSTALL_SPEC_ENABLED"
      policy_content {
        bundles {
          bundle_name = "pss-baseline-v2022"
        }
        bundles {
          bundle_name = "policy-essentials-v2022"
        }
        template_library {
          installation = "ALL"
        }
      }
      referential_rules_enabled = true
    }
  }

  depends_on = [
    google_gke_hub_feature_membership.acm_feature_member,
    google_gke_hub_feature.poco_feature
  ]
}
