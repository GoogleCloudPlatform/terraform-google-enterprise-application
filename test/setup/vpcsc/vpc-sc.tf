/**
 * Copyright 2025 Google LLC
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

locals {
  supported_restricted_service = [
    "accessapproval.googleapis.com",
    "addressvalidation.googleapis.com",
    "adsdatahub.googleapis.com",
    "aiplatform.googleapis.com",
    "alloydb.googleapis.com",
    "analyticshub.googleapis.com",
    "apigee.googleapis.com",
    "apigeeconnect.googleapis.com",
    "apihub.googleapis.com",
    "apikeys.googleapis.com",
    "apphub.googleapis.com",
    "artifactregistry.googleapis.com",
    "assuredoss.googleapis.com",
    "assuredworkloads.googleapis.com",
    "auditmanager.googleapis.com",
    "automl.googleapis.com",
    "autoscaling.googleapis.com",
    "backupdr.googleapis.com",
    "baremetalsolution.googleapis.com",
    "batch.googleapis.com",
    "beyondcorp.googleapis.com",
    "biglake.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "bigquerymigration.googleapis.com",
    "bigtable.googleapis.com",
    "binaryauthorization.googleapis.com",
    "blockchainnodeengine.googleapis.com",
    "certificatemanager.googleapis.com",
    "cloud.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudcode.googleapis.com",
    "cloudcontrolspartner.googleapis.com",
    "clouddeploy.googleapis.com",
    "clouderrorreporting.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudprofiler.googleapis.com",
    "cloudquotas.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudsearch.googleapis.com",
    "cloudsecuritycompliance.googleapis.com",
    "cloudsupport.googleapis.com",
    "cloudtasks.googleapis.com",
    "cloudtrace.googleapis.com",
    "commerceorggovernance.googleapis.com",
    "composer.googleapis.com",
    "compute.googleapis.com",
    "confidentialcomputing.googleapis.com",
    "config.googleapis.com",
    "configdelivery.googleapis.com",
    "connectgateway.googleapis.com",
    "connectors.googleapis.com",
    "contactcenteraiplatform.googleapis.com",
    "contactcenterinsights.googleapis.com",
    "container.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerfilesystem.googleapis.com",
    "containerregistry.googleapis.com",
    "containersecurity.googleapis.com",
    "containerthreatdetection.googleapis.com",
    "contentwarehouse.googleapis.com",
    "databasecenter.googleapis.com",
    "databaseinsights.googleapis.com",
    "datacatalog.googleapis.com",
    "dataflow.googleapis.com",
    "dataform.googleapis.com",
    "datafusion.googleapis.com",
    "datalineage.googleapis.com",
    "datamigration.googleapis.com",
    "datapipelines.googleapis.com",
    "dataplex.googleapis.com",
    "dataproc.googleapis.com",
    "dataprocgdc.googleapis.com",
    "datastream.googleapis.com",
    "developerconnect.googleapis.com",
    "dialogflow.googleapis.com",
    "discoveryengine.googleapis.com",
    "dlp.googleapis.com",
    "dns.googleapis.com",
    "documentai.googleapis.com",
    "domains.googleapis.com",
    "earthengine.googleapis.com",
    "edgecontainer.googleapis.com",
    "edgenetwork.googleapis.com",
    "essentialcontacts.googleapis.com",
    "eventarc.googleapis.com",
    "eventarcpublishing.googleapis.com",
    "file.googleapis.com",
    "financialservices.googleapis.com",
    "firebaseappcheck.googleapis.com",
    "firebasecrashlytics.googleapis.com",
    "firebasedataconnect.googleapis.com",
    "firebaserules.googleapis.com",
    "firebasevertexai.googleapis.com",
    "firestore.googleapis.com",
    "gameservices.googleapis.com",
    "geocoding-backend.googleapis.com",
    "gkebackup.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "gkemulticloud.googleapis.com",
    "gkeonprem.googleapis.com",
    "healthcare.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "iap.googleapis.com",
    "iaptunnel.googleapis.com",
    "identitytoolkit.googleapis.com",
    "ids.googleapis.com",
    "integrations.googleapis.com",
    "kmsinventory.googleapis.com",
    "krmapihosting.googleapis.com",
    "kubernetesmetadata.googleapis.com",
    "language.googleapis.com",
    "licensemanager.googleapis.com",
    "lifesciences.googleapis.com",
    "livestream.googleapis.com",
    "logging.googleapis.com",
    "looker.googleapis.com",
    "managedidentities.googleapis.com",
    "managedkafka.googleapis.com",
    "memcache.googleapis.com",
    "memorystore.googleapis.com",
    "meshca.googleapis.com",
    "meshconfig.googleapis.com",
    "metastore.googleapis.com",
    "microservices.googleapis.com",
    "migrationcenter.googleapis.com",
    "ml.googleapis.com",
    "modelarmor.googleapis.com",
    "monitoring.googleapis.com",
    "netapp.googleapis.com",
    "networkconnectivity.googleapis.com",
    "networkmanagement.googleapis.com",
    "networksecurity.googleapis.com",
    "networkservices.googleapis.com",
    "notebooks.googleapis.com",
    "ondemandscanning.googleapis.com",
    "opsconfigmonitoring.googleapis.com",
    "orgpolicy.googleapis.com",
    "osconfig.googleapis.com",
    "oslogin.googleapis.com",
    "parallelstore.googleapis.com",
    "parametermanager.googleapis.com",
    "places.googleapis.com",
    "policysimulator.googleapis.com",
    "policytroubleshooter.googleapis.com",
    "privateca.googleapis.com",
    "privilegedaccessmanager.googleapis.com",
    "publicca.googleapis.com",
    "pubsub.googleapis.com",
    "pubsublite.googleapis.com",
    "rapidmigrationassessment.googleapis.com",
    "recaptchaenterprise.googleapis.com",
    "recommender.googleapis.com",
    "redis.googleapis.com",
    "retail.googleapis.com",
    "run.googleapis.com",
    "seclm.googleapis.com",
    "secretmanager.googleapis.com",
    "securesourcemanager.googleapis.com",
    "securetoken.googleapis.com",
    "securitycenter.googleapis.com",
    "securitycentermanagement.googleapis.com",
    "servicecontrol.googleapis.com",
    "servicedirectory.googleapis.com",
    "servicehealth.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
    "spanner.googleapis.com",
    "speakerid.googleapis.com",
    "speech.googleapis.com",
    "sqladmin.googleapis.com",
    "ssh-serialport.googleapis.com",
    "storage.googleapis.com",
    "storagebatchoperations.googleapis.com",
    "storageinsights.googleapis.com",
    "storagetransfer.googleapis.com",
    "sts.googleapis.com",
    "telemetry.googleapis.com",
    "texttospeech.googleapis.com",
    "timeseriesinsights.googleapis.com",
    "tpu.googleapis.com",
    "trafficdirector.googleapis.com",
    "transcoder.googleapis.com",
    "translate.googleapis.com",
    "videointelligence.googleapis.com",
    "videostitcher.googleapis.com",
    "vision.googleapis.com",
    "visionai.googleapis.com",
    "visualinspection.googleapis.com",
    "vmmigration.googleapis.com",
    "vmwareengine.googleapis.com",
    "vpcaccess.googleapis.com",
    "webrisk.googleapis.com",
    "websecurityscanner.googleapis.com",
    "workflows.googleapis.com",
    "workloadmanager.googleapis.com",
    "workstations.googleapis.com",
  ]

  egress_rules = [
    {
      title = "Egress to service networking project"
      from = {
        identity_type = "ANY_IDENTITY"
        sources = {
          resources = [for i in var.protected_projects : "projects/${i}"]
        }
      },
      to = {
        resources = ["projects/213331819513"], //service networking project
        operations = {
          "compute.googleapis.com" = { methods = ["*"] }
        }
      }
    },
    {
      title = "Egress to bank of anthos by AR, CA and BAuthz"
      from = {
        identity_type = "ANY_IDENTITY"
        sources = {
          resources = [for i in var.protected_projects : "projects/${i}"]
        }
      }
      to = {
        resources = [
          "projects/682719828243" // projects/bank-of-anthos-ci/locations/us-central1/repositories/bank-of-anthos
        ]
        operations = {
          "artifactregistry.googleapis.com"    = { methods = ["*"] }
          "binaryauthorization.googleapis.com" = { methods = ["*"] }
          "cloudkms.googleapis.com"            = { methods = ["*"] }
          "container.googleapis.com"           = { methods = ["*"] }
          "containerfilesystem.googleapis.com" = { methods = ["*"] }
          "containeranalysis.googleapis.com"   = { methods = ["*"] }
          "containerregistry.googleapis.com"   = { methods = ["*"] }
          "storage.googleapis.com"             = { methods = ["*"] }
          "iamcredentials.googleapis.com"      = { methods = ["*"] }
          "compute.googleapis.com"             = { methods = ["*"] }
          "containerfilesystem.googleapis.com" = { methods = ["*"] }
        }
      }
    },
    {
      title = "Egress to Proxy Golang Storage project"
      from = {
        identity_type = "ANY_IDENTITY"
        sources = {
          resources = [for i in var.protected_projects : "projects/${i}"]
        }
      }
      to = {
        resources = [
          "projects/912338787515", //proxy-golang-org-prod
        ]
        operations = {
          "storage.googleapis.com" = { methods = ["*"] }
        }
      }
    },
    {
      title = "Egress to Storage project"
      from = {
        identity_type = "ANY_IDENTITY"
        sources = {
          resources = [for i in var.protected_projects : "projects/${i}"]
        }
      }
      to = {
        resources = [
          "projects/213358688945",
        ]
        operations = {
          "storage.googleapis.com" = { methods = ["*"] }
        }
      }
    },
    {
      title = "Egress to Logging bucket project"
      from = {
        identity_type = "ANY_IDENTITY"
        sources = {
          resources = [for i in var.protected_projects : "projects/${i}"]
        }
      }
      to = {
        resources = [
          "projects/${var.logging_bucket_project_number}" //logging bucket
        ]
        operations = {
          "storage.googleapis.com" = { methods = ["*"] }
        }
      }
    },
    {
      title = "Egress from ANY_IDENTITY to artifact-registry-docker-cache"
      from = {
        identity_type = "ANY_IDENTITY" //https://cloud.google.com/artifact-registry/docs/securing-with-vpc-sc
        sources = {
          resources = [for i in var.protected_projects : "projects/${i}"]
        }
      },
      to = {
        resources = ["projects/342927644502"], //artifact-registry-docker-cache
        operations = {
          "artifactregistry.googleapis.com"    = { methods = ["*"] }
          "binaryauthorization.googleapis.com" = { methods = ["*"] }
          "cloudkms.googleapis.com"            = { methods = ["*"] }
          "container.googleapis.com"           = { methods = ["*"] }
          "containeranalysis.googleapis.com"   = { methods = ["*"] }
          "containerfilesystem.googleapis.com" = { methods = ["*"] }
          "containerregistry.googleapis.com"   = { methods = ["*"] }
          "storage.googleapis.com"             = { methods = ["*"] }
          "iamcredentials.googleapis.com"      = { methods = ["*"] }
          "compute.googleapis.com"             = { methods = ["*"] }
        }
      }
    },
    {
      title = "Allow Services from ${join(",", var.protected_projects)} to ${var.gitlab_project_number}"
      from = {
        identity_type = "ANY_IDENTITY"
        sources = {
          resources = [for i in var.protected_projects : "projects/${i}"]
        }
      }
      to = {
        resources = [
          "projects/${var.gitlab_project_number}" //worker pool project
        ]
        operations = {
          "servicedirectory.googleapis.com" = { methods = ["*"] }
          "cloudbuild.googleapis.com"       = { methods = ["*"] }
          "clouddeploy.googleapis.com"      = { methods = ["*"] }
          "compute.googleapis.com"          = { methods = ["SubnetworksService.Get"] }
        }
      }
    }
  ]

  ingress_rules = contains(var.protected_projects, var.logging_bucket_project_number) ? [
    {
      title = "Ingress from Gitlab to Single Project project - kms service"
      from = {
        sources    = { resources = ["projects/${var.gitlab_project_number}"] }
        identities = ["serviceAccount:service-${var.gitlab_project_number}@gs-project-accounts.iam.gserviceaccount.com"] //gitlab storage identity
      },
      to = {
        resources = ["projects/${var.logging_bucket_project_number}"], //logging-kms bucket
        operations = {
          "cloudkms.googleapis.com" = { methods = ["*"] }
        }
      }
    }
  ] : tolist([])
}

resource "random_string" "prefix" {
  length  = 6
  special = false
  upper   = false
}

resource "google_access_context_manager_access_policy" "policy_org" {
  parent     = "organizations/${var.org_id}"
  title      = "GKE folder ${var.seed_folder_id} Scoped Access Policy"
  scopes     = [var.seed_folder_id]
  depends_on = [time_sleep.destroy_wait_propagation]
}

module "access_level_members" {
  source             = "terraform-google-modules/vpc-service-controls/google//modules/access_level"
  version            = "~> 7.1"
  policy             = google_access_context_manager_access_policy.policy_org.name
  name               = "ac_gke_enterprise_${random_string.prefix.result}"
  members            = var.access_level_members
  combining_function = "OR"
  depends_on         = [time_sleep.destroy_wait_propagation]
}

module "regular_service_perimeter" {
  source         = "terraform-google-modules/vpc-service-controls/google//modules/regular_service_perimeter"
  version        = "~> 7.1"
  policy         = google_access_context_manager_access_policy.policy_org.name
  perimeter_name = "sp_gke_enterprise_${random_string.prefix.result}"
  description    = "Perimeter shielding projects"

  access_levels_dry_run           = [module.access_level_members.name]
  vpc_accessible_services_dry_run = ["*"]
  restricted_services_dry_run     = local.supported_restricted_service
  resources_dry_run               = var.protected_projects
  egress_policies_dry_run         = local.egress_rules
  ingress_policies_dry_run        = local.ingress_rules

  access_levels           = var.service_perimeter_mode == "ENFORCE" ? [module.access_level_members.name] : []
  vpc_accessible_services = var.service_perimeter_mode == "ENFORCE" ? ["*"] : []
  restricted_services     = var.service_perimeter_mode == "ENFORCE" ? local.supported_restricted_service : []
  resources               = var.service_perimeter_mode == "ENFORCE" ? var.protected_projects : []
  egress_policies         = var.service_perimeter_mode == "ENFORCE" ? local.egress_rules : []
  ingress_policies        = var.service_perimeter_mode == "ENFORCE" ? local.ingress_rules : []
  depends_on              = [time_sleep.destroy_wait_propagation]
}

resource "time_sleep" "apply_wait_propagation" {
  create_duration = "5m"

  depends_on = [
    google_access_context_manager_access_policy.policy_org,
    module.access_level_members,
    module.regular_service_perimeter
  ]
}

resource "time_sleep" "destroy_wait_propagation" {
  destroy_duration = "5m"
}
