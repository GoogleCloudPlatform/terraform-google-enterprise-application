# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

applications = {
  "htc" = {
    "htc" = {
      create_infra_project = true
      create_admin_project = true
    }
  }
}

cloudbuildv2_repository_config = {
  repo_type = "GITLABv2"
  repositories = {
    htc = {
      repository_name = "htc-i-r"
      repository_url  = "https://gitlab.com/user/htc-i-r.git"
    }
  }
  # The Secret ID format is: projects/PROJECT_NUMBER/secrets/SECRET_NAME
  gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
  gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
  gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
  # If you are using a self-hosted instance, you may change the URL below accordingly
  gitlab_enterprise_host_uri = "https://gitlab.com"
  # Format is projects/PROJECT/locations/LOCATION/namespaces/NAMESPACE/services/SERVICE
  gitlab_enterprise_service_directory = "REPLACE_WITH_SERVICE_DIRECTORY"
  # .pem string
  gitlab_enterprise_ca_certificate = <<EOF
REPLACE_WITH_SSL_CERT
EOF
  secret_project_id                = "REPLACE_WITH_SECRET_PROJECT_ID"
}
