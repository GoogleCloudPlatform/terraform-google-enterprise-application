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

remote_state_bucket = "REMOTE_STATE_BUCKET"

region = "us-central1"

buckets_force_destroy = "true"

environment_names = ["development", "nonproduction", "production"]

bucket_kms_key = "projects/PROJECT_ID/locations/KMS_KEY_LOCATION/keyRings/KMS_KEYRING_NAME/cryptoKeys/BUCKET_KMS_KEY_NAME"

attestation_kms_key = "projects/PROJECT_ID/locations/KMS_KEY_LOCATION/keyRings/KMS_KEYRING_NAME/cryptoKeys/ATTESTATION_KMS_KEY_NAME"

cloudbuildv2_repository_config = {
  repo_type = "GITLABv2"
  repositories = {
    "eab-default-example-hello-world" = {
      repository_name = "eab-default-example-hello-world"
      repository_url  = "https://gitlab.com/user/eab-default-example-hello-world.git"
    }
  }
  # The Secret ID format is: projects/PROJECT_NUMBER/secrets/SECRET_NAME
  gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
  gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
  gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
  # If you are using a self-hosted instance, you may change the URL below accordingly
  gitlab_enterprise_host_uri = "https://gitlab.com"
}
