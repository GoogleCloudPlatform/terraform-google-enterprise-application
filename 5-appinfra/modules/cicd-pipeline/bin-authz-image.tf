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


module "build_terraform_image" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 3.1"
  upgrade = false

  create_cmd_triggers = {
    "tag_version" = "v1"
  }

  create_cmd_entrypoint = "bash"
  create_cmd_body       = <<EOT
  git clone https://github.com/GoogleCloudPlatform/cloud-builders-community.git
  cd cloud-builders-community/binauthz-attestation 
  gcloud builds submit . --config cloudbuild.yaml \
  --project=${var.project_id} \
  --service-account=${google_service_account.cloud_build.id} \
  --worker-pool=${var.workerpool_id}"
EOT
  module_depends_on     = [time_sleep.wait_iam_propagation]
}