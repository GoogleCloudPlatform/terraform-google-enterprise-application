applications = {
  "cymbal-shop" = {
    "cymbalshop" = {
      create_infra_project = false
      create_admin_project = true
    },
  }
}

cloudbuildv2_repository_config = {
  repo_type = "GITLABv2"
  repositories = {
    cymbalshop = {
      repository_name = "cymbalshop-i-r"
      repository_url  = "https://gitlab.com/user/cymbalshop-i-r.git"
    }
  }
  # The Secret ID format is: projects/PROJECT_NUMBER/secrets/SECRET_NAME
  gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
  gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
  gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
  secret_project_id                           = "REPLACE_WITH_SECRET_PROJECT_ID"
}
