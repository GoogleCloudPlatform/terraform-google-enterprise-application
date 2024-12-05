applications = {
  "cymbal-shop" = {
    "cymbalshop" = {
      create_infra_project = false
      create_admin_project = true
    },
  }
}

cloudbuildv2_repository_config = {
  repo_type = "CSR"
  repositories = {
    "cymbalshop" = {
      repository_name = "cymbalshop"
      repository_url  = ""
    }
  }
}
