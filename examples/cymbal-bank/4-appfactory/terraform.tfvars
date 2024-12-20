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
  repo_type = "CSR"
  repositories = {
    "balancereader" = {
      repository_name = "balancereader"
      repository_url  = ""
    }
    "contacts" = {
      repository_name = "contacts"
      repository_url  = ""
    }
    "frontend" = {
      repository_name = "frontend"
      repository_url  = ""
    }
    "ledgerwriter" = {
      repository_name = "ledgerwriter"
      repository_url  = ""
    }
    "transactionhistory" = {
      repository_name = "transactionhistory"
      repository_url  = ""
    }
    "userservice" = {
      repository_name = "userservice"
      repository_url  = ""
    }
  }
}
