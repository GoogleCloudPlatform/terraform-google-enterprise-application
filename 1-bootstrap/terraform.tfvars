cloudbuildv2_repository_config = {
  repo_type = "GITLABv2"
  repositories = {
    applicationfactory = {
      repository_name = "eab-applicationfactory"
      repository_url  = "https://34.173.232.24.nip.io/root/eab-applicationfactory.git"
    }
    fleetscope = {
      repository_name = "eab-fleetscope"
      repository_url  = "https://34.173.232.24.nip.io/root/eab-fleetscope.git"
    }
    multitenant = {
      repository_name = "eab-multitenant"
      repository_url  = "https://34.173.232.24.nip.io/root/eab-multitenant.git"
    }
  }
  # The Secret ID format is: projects/PROJECT_NUMBER/secrets/SECRET_NAME
  gitlab_authorizer_credential_secret_id      = "projects/565644641497/secrets/gitlab-pat-from-vm"
  gitlab_read_authorizer_credential_secret_id = "projects/565644641497/secrets/gitlab-pat-from-vm"
  gitlab_webhook_secret_id                    = "projects/eab-gitlab-self-hosted-nixb/secrets/gitlab-webhook"
  # If you are using a self-hosted instance, you may change the URL below accordingly
  gitlab_enterprise_host_uri = "https://34.173.232.24.nip.io"
}
