applications = {
  "cymbal-bank" = {
    "balancereader" = {
      create_infra_project = false
      create_admin_project = true
    }
    "contacts" = {
      create_infra_project = false
      create_admin_project = true
    }
    "frontend" = {
      create_infra_project = false
      create_admin_project = true
    }
    "ledgerwriter" = {
      create_infra_project = true
      create_admin_project = true
    }
    "transactionhistory" = {
      create_infra_project = false
      create_admin_project = true
    }
    "userservice" = {
      create_infra_project = true
      create_admin_project = true
    }
  }
}

cloudbuildv2_repository_config = {
  repo_type = "GITLABv2"
  repositories = {
    balancereader = {
      repository_name = "balancereader-i-r"
      repository_url  = "https://gitlab.com/user/balancereader-i-r.git"
    }
    contacts = {
      repository_name = "contacts-i-r"
      repository_url  = "https://gitlab.com/user/contacts-i-r.git"
    }
    frontend = {
      repository_name = "frontend-i-r"
      repository_url  = "https://gitlab.com/user/frontend-i-r.git"
    }
    ledgerwriter = {
      repository_name = "ledgerwriter-i-r"
      repository_url  = "https://gitlab.com/user/ledgerwriter-i-r.git"
    }
    transactionhistory = {
      repository_name = "transactionhistory-i-r"
      repository_url  = "https://gitlab.com/user/transactionhistory-i-r.git"
    }
    userservice = {
      repository_name = "userservice-i-r"
      repository_url  = "https://gitlab.com/user/userservice-i-r.git"
    }
  }
  # The Secret ID format is: projects/PROJECT_NUMBER/secrets/SECRET_NAME
  gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
  gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
  gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
  secret_project_id                           = "REPLACE_WITH_SECRET_PROJECT_ID"
}
