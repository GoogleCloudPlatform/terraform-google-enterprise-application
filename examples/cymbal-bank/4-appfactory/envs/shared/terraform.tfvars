applications = {
  "cymbal-bank" = {
    "balancereader" = {
      create_infra_project = false
      create_cicd_project  = true
    }
    "contacts" = {
      create_infra_project = false
      create_cicd_project  = true
    }
    "frontend" = {
      create_infra_project = false
      create_cicd_project  = true
    }
    "ledgerwriter" = {
      create_infra_project = true
      create_cicd_project  = true
    }
    "transactionhistory" = {
      create_infra_project = false
      create_cicd_project  = true
    }
    "userservice" = {
      create_infra_project = true
      create_cicd_project  = true
    }
  }
}
