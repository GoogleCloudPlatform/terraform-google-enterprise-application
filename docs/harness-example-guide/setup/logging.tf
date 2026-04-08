
module "logging_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 10.0"

  name          = "bkt-logging-${random_string.prefix.result}"
  project_id    = module.seed_project.project_id
  location      = var.region
  force_destroy = true

  versioning = true
  encryption = { default_kms_key_name = module.kms.keys["bucket"] }
}