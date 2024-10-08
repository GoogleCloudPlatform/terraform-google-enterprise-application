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

apps = {
  "cymbal-bank" : {
    "ip_address_names" : [
      "frontend-ip",
    ]
    "certificates" : {
      "frontend-example-com" : ["frontend.example.com"]
    }
    "acronym" = "cb",
  }
}

envs = {
  "development" = {
    "billing_account"    = "010ECE-40301B-50DDD5"
    "folder_id"          = "folders/86141427775"
    "network_project_id" = "eab-vpc-development-e9p0"
    "network_self_link"  = "https://www.googleapis.com/compute/v1/projects/eab-vpc-development-e9p0/global/networks/eab-vpc-development"
    "org_id"             = "1055058813388"
    "subnets_self_links" = [
      "https://www.googleapis.com/compute/v1/projects/eab-vpc-development-e9p0/regions/us-central1/subnetworks/eab-development-region01",
      "https://www.googleapis.com/compute/v1/projects/eab-vpc-development-e9p0/regions/us-east4/subnetworks/eab-development-region02",
    ]
  }
  "nonproduction" = {
    "billing_account"    = "010ECE-40301B-50DDD5"
    "folder_id"          = "folders/619291735267"
    "network_project_id" = "eab-vpc-nonproduction-9ixg"
    "network_self_link"  = "https://www.googleapis.com/compute/v1/projects/eab-vpc-nonproduction-9ixg/global/networks/eab-vpc-nonproduction"
    "org_id"             = "1055058813388"
    "subnets_self_links" = [
      "https://www.googleapis.com/compute/v1/projects/eab-vpc-nonproduction-9ixg/regions/us-central1/subnetworks/eab-nonproduction-region01",
      "https://www.googleapis.com/compute/v1/projects/eab-vpc-nonproduction-9ixg/regions/us-east4/subnetworks/eab-nonproduction-region02",
    ]
  }
  "production" = {
    "billing_account"    = "010ECE-40301B-50DDD5"
    "folder_id"          = "folders/594110332329"
    "network_project_id" = "eab-vpc-production-c1e4"
    "network_self_link"  = "https://www.googleapis.com/compute/v1/projects/eab-vpc-production-c1e4/global/networks/eab-vpc-production"
    "org_id"             = "1055058813388"
    "subnets_self_links" = [
      "https://www.googleapis.com/compute/v1/projects/eab-vpc-production-c1e4/regions/us-central1/subnetworks/eab-production-region01",
      "https://www.googleapis.com/compute/v1/projects/eab-vpc-production-c1e4/regions/us-east4/subnetworks/eab-production-region02",
    ]
  }
}
