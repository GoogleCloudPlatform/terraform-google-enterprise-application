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

billing_account     = "REPLACE_WITH_BILLING_ACCOUNT"
common_folder_id    = "REPLACE_WITH_COMMON_FOLDER_ID"
org_id              = "REPLACE_WITH_YOUR_ORGANIZATION_ID"
remote_state_bucket = "REMOTE_STATE_BUCKET"
kms_project_id      = "REPLACE_WITH_KMS_PROJECT_ID"

service_perimeter_name = "accessPolicies/000000000000000/servicePerimeters/sp_gke_enterprise_XXXXX"
service_perimeter_mode = "ENFORCE"
access_level_name      = "accessPolicies/000000000000000/accessLevels/ac_gke_enterprise_XXXXX"

envs = {
  "development" = {
    "billing_account"    = "{BILLING_ACCOUNT}"
    "folder_id"          = "folders/{FOLDER}"
    "network_project_id" = "{PROJECT}"
    "network_self_link"  = "https://www.googleapis.com/compute/v1/projects/{PROJECT}/global/networks/{NETWORK}}"
    "org_id"             = "{ORGANIZATION}"
    "subnets_self_links" = [
      "https://www.googleapis.com/compute/v1/projects/{PROJECT}/regions/{REGION}/subnetworks/{SUBNETWORK}",
    ]
  }
  "nonproduction" = {
    "billing_account"    = "{BILLING_ACCOUNT}"
    "folder_id"          = "folders/{FOLDER}"
    "network_project_id" = "{PROJECT}"
    "network_self_link"  = "https://www.googleapis.com/compute/v1/projects/{PROJECT}/global/networks/{NETWORK}}"
    "org_id"             = "{ORGANIZATION}"
    "subnets_self_links" = [
      "https://www.googleapis.com/compute/v1/projects/{PROJECT}/regions/{REGION}/subnetworks/{SUBNETWORK}",
      "https://www.googleapis.com/compute/v1/projects/{PROJECT}/regions/{REGION}/subnetworks/{SUBNETWORK}",
    ]
  }
  "production" = {
    "billing_account"    = "{BILLING_ACCOUNT}"
    "folder_id"          = "folders/{FOLDER}"
    "network_project_id" = "{PROJECT}"
    "network_self_link"  = "https://www.googleapis.com/compute/v1/projects/{PROJECT}/global/networks/{NETWORK}}"
    "org_id"             = "{ORGANIZATION}"
    "subnets_self_links" = [
      "https://www.googleapis.com/compute/v1/projects/{PROJECT}/regions/{REGION}/subnetworks/{SUBNETWORK}",
      "https://www.googleapis.com/compute/v1/projects/{PROJECT}/regions/{REGION}/subnetworks/{SUBNETWORK}",
    ]
  }
}

applications = {
  "default-example" = {
    "hello-world" = {
      create_infra_project = false
      create_admin_project = true
    }
  }
}

cloudbuildv2_repository_config = {
  repo_type = "GITLABv2"
  repositories = {
    "hello-world" = {
      repository_name = "hello-world-i-r"
      repository_url  = "https://gitlab.com/<replace-with-user-or-group>/hello-world-i-r.git"
    }
  }
  # The Secret ID format is: projects/PROJECT_NUMBER/secrets/SECRET_NAME
  gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
  gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
  gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
  secret_project_id                           = "REPLACE_WITH_SECRET_PROJECT_ID"
}
