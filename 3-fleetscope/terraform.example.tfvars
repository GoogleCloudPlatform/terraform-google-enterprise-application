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

namespace_ids = {
  "cb-frontend" = "your-frontend-group@yourdomain.com",
  "cb-accounts" = "your-accounts-group@yourdomain.com",
  "cb-ledger"   = "your-ledger-group@yourdomain.com"
}

remote_state_bucket = "REMOTE_STATE_BUCKET"

attestation_kms_key = "projects/PROJECT_ID/locations/KMS_KEY_LOCATION/keyRings/KMS_KEYRING_NAME/cryptoKeys/KMS_KEY_NAME"

config_sync_secret_type = "token"

config_sync_repository_url = "https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-fleetscope.git"

config_sync_branch = "production"

config_sync_policy_dir = "envs/production"
