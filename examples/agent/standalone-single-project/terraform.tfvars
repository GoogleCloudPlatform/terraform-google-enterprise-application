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

project_id = "<YOUR-PROJECT-ID>"

# Mandatory fleetscope namespaces, it can be {} if there are no namespaces to provide
teams = {
  "namespace" = "your-group@yourdomain.com",
}

# region     = "us-central1"

# Optional: If you already have a private worker pool, specify its ID. If not, a new one will be created.  
# workerpool_id = "projects/PROJECT_ID/locations/LOCATION/workerPools/POOL_NAME"  

# Optional: If a private worker pool is not provided, and you already have a VPC network to use for the private worker pool, specify its ID. If not, a new network will be created.  
# network_id = "projects/PROJECT_ID/global/networks/NETWORK_NAME" 

# Optional: Set to false if you do not want to create a NAT gateway (e.g. if your existing network already has one).
# create_nat = true

# Optional: Cloud Storage bucket to store logs
# logging_bucket = "your-gcs-logging-bucket"

# Optional: KMS Key to encrypt Cloud Storage buckets
# bucket_kms_key = "projects/PROJECT_ID/locations/LOCATION/keyRings/KEYRING/cryptoKeys/KEY"

# Optional: VPC Service Controls configuration
# service_perimeter_name = "<YOUR-SERVICE-PERIMETER-NAME>"
# service_perimeter_mode = "DRY_RUN"
# access_level_name      = "<YOUR-ACCESS-LEVEL-NAME>"

# Optional: Network Connectivity Center (NCC) connection configuration
# ncc_config = {
#   enable_ncc                  = true
#   hub_uri                     = "projects/YOUR_HUB_PROJECT_ID/locations/global/hubs/YOUR_HUB_NAME"
#   spoke_group                 = "edge"
#   spoke_name                  = "vpc-spoke"
#   spoke_description           = "NCC Spoke for standalone cluster network"
#   spoke_labels                = { env = "dev" }
#   spoke_exclude_export_ranges = []
#   spoke_include_export_ranges = []
# }

cloudbuildv2_repository_config = {
  repo_type = "GITLABv2"
  repositories = {
    "eab-agent-capital-agent" = {
      repository_name = "eab-agent-capital-agent"
      repository_url  = "https://gitlab.com/user/eab-agent-capital-agent.git"
    }
  }
  # The Secret ID format is: projects/PROJECT_NUMBER/secrets/SECRET_NAME
  gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
  gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
  gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
  secret_project_id                           = "REPLACE_WITH_SECRET_PROJECT_ID"

  # If you are using a self-hosted instance, you may change the URL below accordingly
  gitlab_enterprise_host_uri = "https://gitlab.com"
  # Format is projects/PROJECT/locations/LOCATION/namespaces/NAMESPACE/services/SERVICE
  gitlab_enterprise_service_directory = "REPLACE_WITH_SERVICE_DIRECTORY"
  # .pem string
  gitlab_enterprise_ca_certificate = <<EOF
REPLACE_WITH_SSL_CERT
EOF
}
