/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# 5-appinfra

# app_01
locals {

  cluster_membership_ids = { (local.env) : { "cluster_membership_ids" : module.multitenant_infra.cluster_membership_ids } }

  sa_cb = [for cicd in module.cicd : "serviceAccount:${cicd.cloudbuild_service_account}"]

  cicd_apps = {
    "contacts" = {
      application_name = "cymbal-bank"
      service_name     = "contacts"
      team_name        = "accounts"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "GITLABv2"
        repositories = {
          "eab-cymbal-bank-accounts-contacts" = {
            repository_name = "eab-cymbal-bank-accounts-contacts"
            repository_url  = "https://gitlab.com/user/eab-cymbal-bank-accounts-contacts.git"
          }
        }
        gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
        gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
        gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
        gitlab_enterprise_host_uri                  = "https://gitlab.com"
      }
    },
    "userservice" = {
      application_name = "cymbal-bank"
      service_name     = "userservice"
      team_name        = "accounts"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "GITLABv2"
        repositories = {
          "eab-cymbal-bank-accounts-userservice" = {
            repository_name = "eab-cymbal-bank-accounts-userservice"
            repository_url  = "https://gitlab.com/user/eab-cymbal-bank-accounts-userservice.git"
          }
        }
        gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
        gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
        gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
        gitlab_enterprise_host_uri                  = "https://gitlab.com"
      }
    },
    "frontend" = {
      application_name = "cymbal-bank"
      service_name     = "frontend"
      team_name        = "frontend"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "GITLABv2"
        repositories = {
          "eab-cymbal-bank-frontend" = {
            repository_name = "eab-cymbal-bank-frontend"
            repository_url  = "https://gitlab.com/user/eab-cymbal-bank-frontend.git"
          }
        }
        gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
        gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
        gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
        gitlab_enterprise_host_uri                  = "https://gitlab.com"
      }
    },
    "balancereader" = {
      application_name = "cymbal-bank"
      service_name     = "balancereader"
      team_name        = "ledger"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "GITLABv2"
        repositories = {
          "eab-cymbal-bank-ledger-balancereader" = {
            repository_name = "eab-cymbal-bank-ledger-balancereader"
            repository_url  = "https://gitlab.com/user/eab-cymbal-bank-ledger-balancereader.git"
          }
        }
        gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
        gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
        gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
        gitlab_enterprise_host_uri                  = "https://gitlab.com"
      }
    },
    "ledgerwriter" = {
      application_name = "cymbal-bank"
      service_name     = "ledgerwriter"
      team_name        = "ledger"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "GITLABv2"
        repositories = {
          "eab-cymbal-bank-ledger-ledgerwriter" = {
            repository_name = "eab-cymbal-bank-ledger-ledgerwriter"
            repository_url  = "https://gitlab.com/user/eab-cymbal-bank-ledger-ledgerwriter.git"
          }
        }
        gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
        gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
        gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
        gitlab_enterprise_host_uri                  = "https://gitlab.com"
      }
    },
    "transactionhistory" = {
      application_name = "cymbal-bank"
      service_name     = "transactionhistory"
      team_name        = "ledger"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "GITLABv2"
        repositories = {
          "eab-cymbal-bank-ledger-transactionhistory" = {
            repository_name = "eab-cymbal-bank-ledger-transactionhistory"
            repository_url  = "https://gitlab.com/user/eab-cymbal-bank-ledger-transactionhistory.git"
          }
        }
        gitlab_authorizer_credential_secret_id      = "REPLACE_WITH_READ_API_SECRET_ID"
        gitlab_read_authorizer_credential_secret_id = "REPLACE_WITH_READ_USER_SECRET_ID"
        gitlab_webhook_secret_id                    = "REPLACE_WITH_WEBHOOK_SECRET_ID"
        gitlab_enterprise_host_uri                  = "https://gitlab.com"
      }
    },
  }
}

module "cicd" {
  source   = "../../5-appinfra/modules/cicd-pipeline"
  for_each = local.cicd_apps

  project_id                 = var.project_id
  region                     = var.region
  env_cluster_membership_ids = local.cluster_membership_ids
  cluster_service_accounts   = { for i, sa in module.multitenant_infra.cluster_service_accounts : (i) => "serviceAccount:${sa}" }

  service_name           = each.value.service_name
  team_name              = each.value.team_name
  repo_name              = each.value.team_name != each.value.service_name ? "eab-${each.value.application_name}-${each.value.team_name}-${each.value.service_name}" : "eab-${each.value.application_name}-${each.value.service_name}"
  repo_branch            = each.value.repo_branch
  app_build_trigger_yaml = "src/${each.value.team_name}/cloudbuild.yaml"

  additional_substitutions = {
    _SERVICE = each.value.service_name
    _TEAM    = each.value.team_name
  }

  ci_build_included_files = ["src/${each.value.team_name}/**", "src/components/**"]

  buckets_force_destroy = true

  cloudbuildv2_repository_config = each.value.cloudbuildv2_repository_config

  private_worker_pool = { workerpool_network_id = var.workerpool_network_id }
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_access_context_manager_service_perimeter_ingress_policy" "ingress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" ? 1 : 0
  perimeter = var.service_perimeter_name
  ingress_from {
    identities = local.sa_cb
    sources {
      access_level = "*"
    }
  }
  ingress_to {
    resources = [
      "projects/${data.google_project.project.number}",
    ]

    operations {
      service_name = "cloudbuild.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "ingress_policy" {
  perimeter = var.service_perimeter_name
  ingress_from {
    identities = local.sa_cb
    sources {
      access_level = "*"
    }
  }
  ingress_to {
    resources = [
      "projects/${data.google_project.project.number}",
    ]

    operations {
      service_name = "cloudbuild.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}
