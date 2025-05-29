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

module "stocks_data" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 10.0"

  name              = "${var.infra_project}-stocks-historical-data"
  project_id        = var.infra_project
  location          = var.region
  log_bucket        = var.logging_bucket
  log_object_prefix = "stocks-${var.infra_project}"

  force_destroy = var.bucket_force_destroy

  public_access_prevention = "enforced"

  versioning = true
  encryption = { default_kms_key_name = var.bucket_kms_key }

  depends_on = [time_sleep.wait_cmek_iam_propagation]
}

