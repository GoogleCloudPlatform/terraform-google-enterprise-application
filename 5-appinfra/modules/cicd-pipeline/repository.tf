locals {
  service_repo_name = var.cloudbuildv2_repository_config.repositories[var.repo_name].repository_name
  use_csr           = var.cloudbuildv2_repository_config.repo_type == "CSR"
}

resource "google_sourcerepo_repository" "app_repo" {
  count = local.use_csr ? 1 : 0


  project = var.project_id
  name    = var.repo_name

  create_ignore_already_exists = true
}

resource "google_sourcerepo_repository_iam_member" "member" {
  count = local.use_csr ? 1 : 0


  project    = var.project_id
  repository = google_sourcerepo_repository.app_repo[0].name
  role       = "roles/source.admin"
  member     = google_project_service_identity.cloudbuild_service_identity.member
}

module "cloudbuild_repositories" {
  count = local.use_csr ? 0 : 1

  source  = "terraform-google-modules/bootstrap/google//modules/cloudbuild_repo_connection"
  version = "~> 10.0"

  project_id = var.project_id

  connection_config = {
    connection_type                             = var.cloudbuildv2_repository_config.repo_type
    github_secret_id                            = var.cloudbuildv2_repository_config.github_secret_id
    github_app_id_secret_id                     = var.cloudbuildv2_repository_config.github_app_id_secret_id
    gitlab_read_authorizer_credential_secret_id = var.cloudbuildv2_repository_config.gitlab_read_authorizer_credential_secret_id
    gitlab_authorizer_credential_secret_id      = var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id
    gitlab_webhook_secret_id                    = var.cloudbuildv2_repository_config.gitlab_webhook_secret_id
  }
  cloud_build_repositories = var.cloudbuildv2_repository_config.repositories
}
