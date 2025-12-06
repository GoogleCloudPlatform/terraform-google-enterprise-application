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
  meta,
  INT64(JSON_QUERY(json_payload, "$.bytes")) AS bytes,
  INT64(JSON_QUERY(json_payload, "$.ops")) as ops,
  FLOAT64(JSON_QUERY(json_payload, "$.load")) as load,
  INT64(JSON_QUERY(json_payload, "$.lat_min")) AS lat_min,
  INT64(JSON_QUERY(json_payload, "$.lat_50")) AS lat_50,
  INT64(JSON_QUERY(json_payload, "$.lat_95")) AS lat_95,
  INT64(JSON_QUERY(json_payload, "$.lat_99")) AS lat_99,
  INT64(JSON_QUERY(json_payload, "$.lat_max")) AS lat_max
FROM
  `${project_id}.${dataset_id}.${table_id}`
WHERE
  meta.job_container_id IN ('agent', 'controller') AND
  meta.job_worker_type IS NOT NULL AND
  JSON_VALUE(json_payload, "$.msg") = 'statistics'
