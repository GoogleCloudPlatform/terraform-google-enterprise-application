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
  cicd_apps = { "contacts" = {
    application_name = "cymbal-bank"
    service_name     = "contacts"
    team_name        = "accounts"
    repo_branch      = "main"
    cloudbuildv2_repository_config = {
      repo_type = "CSR"
      repositories = {
        "eab-cymbal-bank-accounts-contacts" = {
          repository_name = "eab-cymbal-bank-accounts-contacts"
          repository_url  = ""
        }
      }
    }
    },
    "userservice" = {
      application_name = "cymbal-bank"
      service_name     = "userservice"
      team_name        = "accounts"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "CSR"
        repositories = {
          "eab-cymbal-bank-accounts-userservice" = {
            repository_name = "eab-cymbal-bank-accounts-userservice"
            repository_url  = ""
          }
        }
      }
    },
    "frontend" = {
      application_name = "cymbal-bank"
      service_name     = "frontend"
      team_name        = "frontend"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "CSR"
        repositories = {
          "eab-cymbal-bank-frontend" = {
            repository_name = "eab-cymbal-bank-frontend"
            repository_url  = ""
          }
        }
      }
    },
    "balancereader" = {
      application_name = "cymbal-bank"
      service_name     = "balancereader"
      team_name        = "ledger"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "CSR"
        repositories = {
          "eab-cymbal-bank-ledger-balancereader" = {
            repository_name = "eab-cymbal-bank-ledger-balancereader"
            repository_url  = ""
          }
        }
      }
    },
    "ledgerwriter" = {
      application_name = "cymbal-bank"
      service_name     = "ledgerwriter"
      team_name        = "ledger"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "CSR"
        repositories = {
          "eab-cymbal-bank-ledger-ledgerwriter" = {
            repository_name = "eab-cymbal-bank-ledger-ledgerwriter"
            repository_url  = ""
          }
        }
      }
    },
    "transactionhistory" = {
      application_name = "cymbal-bank"
      service_name     = "transactionhistory"
      team_name        = "ledger"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "CSR"
        repositories = {
          "eab-cymbal-bank-ledger-transactionhistory" = {
            repository_name = "eab-cymbal-bank-ledger-transactionhistory"
            repository_url  = ""
          }
        }
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

  network_id = module.multitenant_infra.network_id

  create_artifact_registry_remote_dockerhub = each.value.service_name == "contacts"
  create_artifact_registry_remote_python    = each.value.service_name == "contacts"

  depends_on = [time_sleep.wait_propagation]
}

resource "google_access_context_manager_service_perimeter_egress_policy" "egress_policy" {
  perimeter = var.service_perimeter_name
  egress_from {
    sources {
      access_level = "*"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/265687763945", "projects/220271587623", "projects/682719828243", "projects/848655640797"] //google project, bank of anthos
    operations {
      service_name = "cloudbuild.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "storage.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "logging.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "iamcredentials.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "artifactregistry.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "clouddeploy.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [module.cicd]
}

# resource "google_access_context_manager_service_perimeter_ingress_policy" "ingress_policy" {
#   perimeter = var.service_perimeter_name
#   ingress_from {
#     sources {
#       access_level = "*"
#     }
#     identities = [
#       "serviceAccount:ci-ledgerwriter@${var.project_id}.iam.gserviceaccount.com",
#       "serviceAccount:ci-transactionhistory@${var.project_id}.iam.gserviceaccount.com",
#       "serviceAccount:ci-frontend@${var.project_id}.iam.gserviceaccount.com",
#       "serviceAccount:ci-balancereader@${var.project_id}.iam.gserviceaccount.com",
#       "serviceAccount:ci-userservice@${var.project_id}.iam.gserviceaccount.com",
#       "serviceAccount:ci-contacts@${var.project_id}.iam.gserviceaccount.com",
#       "serviceAccount:deploy-ledgerwriter@${var.project_id}.iam.gserviceaccount.com",
#       "serviceAccount:deploy-transactionhistory@${var.project_id}.iam.gserviceaccount.com",
#       "serviceAccount:deploy-frontend@${var.project_id}.iam.gserviceaccount.com",
#       "serviceAccount:deploy-balancereader@${var.project_id}.iam.gserviceaccount.com",
#       "serviceAccount:deploy-userservice@${var.project_id}.iam.gserviceaccount.com",
#       "serviceAccount:deploy-contacts@${var.project_id}.iam.gserviceaccount.com"
#     ]
#   }
#   ingress_to {
#     resources = ["*"]
#     operations {
#       service_name = "cloudbuild.googleapis.com"
#       method_selectors {
#         method = "*"
#       }
#     }
#     operations {
#       service_name = "storage.googleapis.com"
#       method_selectors {
#         method = "*"
#       }
#     }
#     operations {
#       service_name = "logging.googleapis.com"
#       method_selectors {
#         method = "*"
#       }
#     }
#     operations {
#       service_name = "iamcredentials.googleapis.com"
#       method_selectors {
#         method = "*"
#       }
#     }
#     operations {
#       service_name = "artifactregistry.googleapis.com"
#       method_selectors {
#         method = "*"
#       }
#     }
#     operations {
#       service_name = "clouddeploy.googleapis.com"
#       method_selectors {
#         method = "*"
#       }
#     }
#   }
#   lifecycle {
#     create_before_destroy = true
#   }

#   depends_on = [module.cicd]
# }
