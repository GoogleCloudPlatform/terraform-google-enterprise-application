/*
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

SELECT
  timestamp,
  STRUCT(
    resource.type AS infra,
    IF(resource.type='cloud_run_job',
      JSON_VALUE(resource.labels, "$.job_name"),
      IF(resource.type='cloud_run_revision',
        JSON_VALUE(resource.labels, "$.service_name"),
        JSON_VALUE(labels, "$.\"k8s-pod/app\""))
      ) AS job_worker_type,
    IF(resource.type IN ('cloud_run_job', 'cloud_run_revision'),
      JSON_VALUE(labels, "$.instanceId"),
      JSON_VALUE(resource.labels, "$.pod_name")) AS job_worker_id,
    IF(resource.type IN ('cloud_run_job', 'cloud_run_revision'),
      COALESCE(JSON_VALUE(labels, "$.container_name"), JSON_VALUE(resource.labels, "$.job_name")),
      JSON_VALUE(resource.labels, "$.container_name")) AS job_container_id
  ) AS meta,
  * EXCEPT (timestamp)
FROM
  `${project_id}.${dataset_id}._AllLogs`
WHERE
  resource.type IN ('k8s_container', 'cloud_run_job', 'cloud_run_revision') AND
  json_payload IS NOT NULL
