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

fleet_project_id   = "{FLEET_PROJECT}"
cluster_project_id = "{CLUSTER_PROJECT}"
network_project_id = "{NETWORK_PROJECT}"
cluster_membership_ids = [
  "//gkehub.googleapis.com/projects/{CLUSTER_PROJECT}/locations/{REGION}/memberships/{MEMBERSHIP_ID}",
  "//gkehub.googleapis.com/projects/{CLUSTER_PROJECT}/locations/{REGION}/memberships/{MEMBERSHIP_ID}",
]
