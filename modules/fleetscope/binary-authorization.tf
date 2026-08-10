# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "google_binary_authorization_attestor" "attestor" {
  count   = var.attestation_kms_key != null ? 1 : 0
  project = var.cluster_project_id
  name    = "gke-attestor"
  attestation_authority_note {
    note_reference = google_container_analysis_note.note.name
    public_keys {
      id = data.google_kms_crypto_key_version.version[0].id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.version[0].public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.version[0].public_key[0].algorithm
      }
    }
  }
}

data "google_kms_crypto_key_version" "version" {
  count      = var.attestation_kms_key != null ? 1 : 0
  crypto_key = var.attestation_kms_key
}

resource "google_container_analysis_note" "note" {

  project = var.cluster_project_id
  name    = "gke-attestor-note"
  attestation_authority {
    hint {
      human_readable_name = "Attestor Note"
    }
  }
}

resource "google_binary_authorization_policy" "policy" {
  count   = var.attestation_kms_key != null ? 1 : 0
  project = var.cluster_project_id
  default_admission_rule {
    evaluation_mode         = var.attestation_evaluation_mode
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = var.attestation_evaluation_mode == "REQUIRE_ATTESTATION" ? [google_binary_authorization_attestor.attestor[0].name] : null
  }

  dynamic "admission_whitelist_patterns" {
    for_each = concat(var.binary_authz_admission_whitelist_patterns, var.enable_kueue ? [for i in module.kueue : "${i.remote_repository_url}/**"] : [])
    content {
      name_pattern = admission_whitelist_patterns.value
    }
  }

  global_policy_evaluation_mode = "ENABLE"
}
