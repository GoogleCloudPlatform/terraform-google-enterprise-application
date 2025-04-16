cloudbuildv2_repository_config = {
  repo_type = "GITLABv2"
  repositories = {
    applicationfactory = {
      repository_name = "eab-applicationfactory"
      repository_url  = "https://gitlab.com/user/eab-applicationfactory.git"
    }
    fleetscope = {
      repository_name = "eab-fleetscope"
      repository_url  = "https://gitlab.com/user/eab-fleetscope.git"
    }
    multitenant = {
      repository_name = "eab-multitenant"
      repository_url  = "https://gitlab.com/user/eab-multitenant.git"
    }
  }
  # The Secret ID format is: projects/PROJECT_NUMBER/secrets/SECRET_NAME
  gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
  gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
  gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
  secret_project_id                           = "REPLACE_WITH_SECRET_PROJECT_ID"

  # If you are using a self-hosted instance, you may change the URL below accordingly
  gitlab_enterprise_host_uri = "https://gitlab.com"
  # Format is projects/PROJECT/locations/LOCATION/namespaces/NAMESPACE/services/SERVICE
  gitlab_enterprise_service_directory = "REPLACE_WITH_SERVICE_DIRECTORY"
  # .pem string
  gitlab_enterprise_ca_certificate = <<EOF
REPLACE_WITH_SSL_CERT
EOF
}
