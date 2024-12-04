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

output "app-group" {
  description = "Description on the app-group components"
  value = {
    for k, value in module.components : k => {
      app_infra_project_ids : value.app_infra_project_ids,
      app_admin_project_id : value.app_admin_project_id,
      app_infra_repository_name : (value.app_infra_repository_name == "CLOUDBUILD_V2_REPOSITORY" ? module.cloudbuild_repositories[0].cloud_build_repositories_2nd_gen_repositories[value.service_name].name : value.app_infra_repository_name),
      app_infra_repository_url : (value.app_infra_repository_url == "CLOUDBUILD_V2_REPOSITORY" ? module.cloudbuild_repositories[0].cloud_build_repositories_2nd_gen_repositories[value.service_name].remote_uri : value.app_infra_repository_url),
      app_cloudbuild_workspace_apply_trigger_id : value.app_cloudbuild_workspace_apply_trigger_id,
      app_cloudbuild_workspace_plan_trigger_id : value.app_cloudbuild_workspace_plan_trigger_id,
      app_cloudbuild_workspace_artifacts_bucket_name : value.app_cloudbuild_workspace_artifacts_bucket_name,
      app_cloudbuild_workspace_logs_bucket_name : value.app_cloudbuild_workspace_logs_bucket_name,
      app_cloudbuild_workspace_state_bucket_name : value.app_cloudbuild_workspace_state_bucket_name,
    }
  }
}

output "app-folders-ids" {
  description = "Pair of app-name and folder_id"
  value = {
    for k, v in google_folder.app_folder : k => v.folder_id
  }
}
