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
  version = "~> 11.0"

  name              = "${var.bucket_prefix}-${var.infra_project}-stocks-historical-data"
  project_id        = var.infra_project
  location          = var.region
  log_bucket        = var.logging_bucket
  log_object_prefix = "stocks-${var.infra_project}"

  force_destroy = var.bucket_force_destroy

  public_access_prevention = "enforced"

  versioning = true
  encryption = var.bucket_kms_key == null ? null : {
    default_kms_key_name = var.bucket_kms_key
  }

  internal_encryption_config = var.bucket_kms_key == null ? {
    create_encryption_key = true
    prevent_destroy       = !var.bucket_force_destroy
  } : {}

  depends_on = [time_sleep.wait_cmek_iam_propagation]
}
