locals {
  csr_repos = [
    "eab-cymbal-bank-accounts-contacts",
    "eab-cymbal-bank-accounts-userservice",
    "eab-cymbal-bank-frontend",
    "eab-cymbal-bank-ledger-balancereader",
    "eab-cymbal-bank-ledger-ledgerwriter",
    "eab-cymbal-bank-ledger-transactionhistory",
    "eab-cymbal-shop-cymbalshop"
  ]
}
# DEPRECATED - TODO: Remove after CSR support is removed
resource "google_sourcerepo_repository" "app_repo" {
  for_each = toset(local.csr_repos)

  project = local.project_id
  name    = each.key

  create_ignore_already_exists = true
}
