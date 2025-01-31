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
    "adsdatahub.googleapis.com",
    "aiplatform.googleapis.com",
    "alloydb.googleapis.com",
    "alpha-documentai.googleapis.com",
    "analyticshub.googleapis.com",
    "apigee.googleapis.com",
    "apigeeconnect.googleapis.com",
    "artifactregistry.googleapis.com",
    "assuredworkloads.googleapis.com",
    "automl.googleapis.com",
    "baremetalsolution.googleapis.com",
    "batch.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "bigquerymigration.googleapis.com",
    "bigqueryreservation.googleapis.com",
    "bigtable.googleapis.com",
    "binaryauthorization.googleapis.com",
    "cloud.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddebugger.googleapis.com",
    "clouddeploy.googleapis.com",
    "clouderrorreporting.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudprofiler.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudsearch.googleapis.com",
    "cloudtrace.googleapis.com",
    "composer.googleapis.com",
    "compute.googleapis.com",
    "connectgateway.googleapis.com",
    "contactcenterinsights.googleapis.com",
    "container.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerfilesystem.googleapis.com",
    "containerregistry.googleapis.com",
    "containerthreatdetection.googleapis.com",
    "datacatalog.googleapis.com",
    "dataflow.googleapis.com",
    "datafusion.googleapis.com",
    "datamigration.googleapis.com",
    "dataplex.googleapis.com",
    "dataproc.googleapis.com",
    "datastream.googleapis.com",
    "dialogflow.googleapis.com",
    "dlp.googleapis.com",
    "dns.googleapis.com",
    "documentai.googleapis.com",
    "domains.googleapis.com",
    "eventarc.googleapis.com",
    "file.googleapis.com",
    "firebaseappcheck.googleapis.com",
    "firebaserules.googleapis.com",
    "firestore.googleapis.com",
    "gameservices.googleapis.com",
    "gkebackup.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "healthcare.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "iaptunnel.googleapis.com",
    "ids.googleapis.com",
    "integrations.googleapis.com",
    "kmsinventory.googleapis.com",
    "krmapihosting.googleapis.com",
    "language.googleapis.com",
    "lifesciences.googleapis.com",
    "logging.googleapis.com",
    "managedidentities.googleapis.com",
    "memcache.googleapis.com",
    "meshca.googleapis.com",
    "meshconfig.googleapis.com",
    "metastore.googleapis.com",
    "ml.googleapis.com",
    "monitoring.googleapis.com",
    "networkconnectivity.googleapis.com",
    "networkmanagement.googleapis.com",
    "networksecurity.googleapis.com",
    "networkservices.googleapis.com",
    "notebooks.googleapis.com",
    "opsconfigmonitoring.googleapis.com",
    "orgpolicy.googleapis.com",
    "osconfig.googleapis.com",
    "oslogin.googleapis.com",
    "privateca.googleapis.com",
    "pubsub.googleapis.com",
    "pubsublite.googleapis.com",
    "recaptchaenterprise.googleapis.com",
    "recommender.googleapis.com",
    "redis.googleapis.com",
    "retail.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicecontrol.googleapis.com",
    "servicedirectory.googleapis.com",
    "spanner.googleapis.com",
    "speakerid.googleapis.com",
    "speech.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "storagetransfer.googleapis.com",
    "sts.googleapis.com",
    "texttospeech.googleapis.com",
    "timeseriesinsights.googleapis.com",
    "tpu.googleapis.com",
    "trafficdirector.googleapis.com",
    "transcoder.googleapis.com",
    "translate.googleapis.com",
    "videointelligence.googleapis.com",
    "vision.googleapis.com",
    "visionai.googleapis.com",
    "vmmigration.googleapis.com",
    "vpcaccess.googleapis.com",
    "webrisk.googleapis.com",
    "workflows.googleapis.com",
    "workstations.googleapis.com",
  ]
}

resource "random_string" "prefix" {
  length  = 6
  special = false
  upper   = false
}

data "google_access_context_manager_access_policy" "policy_org" {
  parent = "organizations/${var.org_id}"
}

module "access_level_members" {
  source  = "terraform-google-modules/vpc-service-controls/google//modules/access_level"
  version = "~> 6.2"
  policy  = data.google_access_context_manager_access_policy.policy_org.name
  name    = "ac_gke_enterprise_${random_string.prefix.result}"
  members = var.access_level_members
}

module "regular_service_perimeter" {
  source         = "terraform-google-modules/vpc-service-controls/google//modules/regular_service_perimeter"
  version        = "~> 6.2"
  policy         = data.google_access_context_manager_access_policy.policy_org.name
  perimeter_name = "sp_gke_enterprise_${random_string.prefix.result}"
  description    = "Perimeter shielding projects"

  access_levels_dry_run           = var.service_perimeter_mode == "DRY_RUN" ? [module.access_level_members.name] : []
  vpc_accessible_services_dry_run = var.service_perimeter_mode == "DRY_RUN" ? ["*"] : []
  restricted_services_dry_run     = var.service_perimeter_mode == "DRY_RUN" ? local.supported_restricted_service : []
  resources_dry_run               = var.service_perimeter_mode == "DRY_RUN" ? [var.project_number, var.gitlab_project_number] : []
  egress_policies_dry_run = var.service_perimeter_mode == "DRY_RUN" ? [
    {
      from = {
        sources = { access_level = ["*"] }
      },
      to = {
        resources = ["projects/213331819513", "projects/360590781837"], //service networking project
        operations = {
          "compute.googleapis.com" = { methods = ["*"] }
        }
      }
    }
  ] : []

  access_levels           = var.service_perimeter_mode == "ENFORCE" ? [module.access_level_members.name] : []
  vpc_accessible_services = var.service_perimeter_mode == "ENFORCE" ? ["*"] : []
  restricted_services     = var.service_perimeter_mode == "ENFORCE" ? local.supported_restricted_service : []
  resources               = var.service_perimeter_mode == "ENFORCE" ? [var.project_number, var.gitlab_project_number] : []
  egress_policies = var.service_perimeter_mode == "ENFORCE" ? [
    {
      from = {
        sources = { access_level = ["*"] }
      },
      to = {
        resources = ["projects/213331819513", "projects/360590781837"], //service networking projects
        operations = {
          "compute.googleapis.com" = { methods = ["*"] }
        }
      }
    }
  ] : []
}
