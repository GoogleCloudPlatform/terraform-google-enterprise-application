data "google_storage_project_service_account" "ci_gcs_account" {
  project = module.seed_project.project_id
}

module "kms" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 4.0"

  project_id     = module.seed_project.project_id
  location       = var.region
  keyring        = "kms-bucket-encryption"
  keys           = ["bucket"]
  set_owners_for = ["bucket"]
  owners = [
    "serviceAccount:${var.cloud_build_sa}"
  ]
  set_encrypters_for = ["bucket"]
    encrypters = [
    data.google_storage_project_service_account.ci_gcs_account.member,
    "serviceAccount:${var.cloud_build_sa}",
  ]
  set_decrypters_for = ["bucket"]
  decrypters = [
    data.google_storage_project_service_account.ci_gcs_account.member,
    "serviceAccount:${var.cloud_build_sa}",
  ]
  prevent_destroy = false
}

module "kms_attestor" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 4.0"

  project_id          = module.seed_project.project_id
  location            = var.region
  keyring             = "kms-attestation-sign"
  keys                = ["attestation"]
  set_owners_for      = ["attestation"]
  purpose             = "ASYMMETRIC_SIGN"
  key_algorithm       = "RSA_SIGN_PKCS1_4096_SHA512"
  key_rotation_period = null
  owners = [
    "serviceAccount:${var.cloud_build_sa}"
  ]
  set_encrypters_for = ["attestation"]
  encrypters = [
    "${data.google_storage_project_service_account.ci_gcs_account.member},serviceAccount:${var.cloud_build_sa}",
  ]
  set_decrypters_for = ["attestation"]
  decrypters = [
    "${data.google_storage_project_service_account.ci_gcs_account.member},serviceAccount:${var.cloud_build_sa}",
  ]
  prevent_destroy = false
}