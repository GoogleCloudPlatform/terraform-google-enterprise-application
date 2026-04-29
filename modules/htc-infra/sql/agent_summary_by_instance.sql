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

WITH
  SrcData AS (
    SELECT
      meta.infra,
      meta.job_worker_type,
      meta.job_worker_id,
      meta.job_container_id,
      timestamp,
      (timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 60 SECOND)) AS win_1min,
      (timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 5*60 SECOND)) AS win_5min,
      (timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 60*60 SECOND)) AS win_15min,
      bytes,
      ops,
      load
    FROM
      `${project_id}.${dataset_id}.${table_id}`
  )
SELECT
  infra,
  job_worker_type,
  job_worker_id,
  job_container_id,
  MAX(timestamp) AS last_active_time,
  TIMESTAMP_DIFF(MAX(timestamp), MIN(timestamp), SECOND) AS total_active_secs,
  SAFE_DIVIDE(SUM(IF(win_1min,ops,0)),60) AS win_1min_ops_per_second,
  SAFE_DIVIDE(SUM(IF(win_1min,bytes,0)),60) AS win_1min_bytes_per_second,
  SAFE_DIVIDE(SUM(IF(win_1min,load,0)),SUM(IF(win_1min,1,0))) AS win_1min_load_per_second,
  SAFE_DIVIDE(SUM(IF(win_5min,ops,0)),300) AS win_5min_ops_per_second,
  SAFE_DIVIDE(SUM(IF(win_5min,bytes,0)),300) AS win_5min_bytes_per_second,
  SAFE_DIVIDE(SUM(IF(win_5min,load,0)),SUM(IF(win_5min,1,0))) AS win_5min_load_per_second,
  SAFE_DIVIDE(SUM(IF(win_15min,ops,0)),900) AS win_15min_ops_per_second,
  SAFE_DIVIDE(SUM(IF(win_15min,bytes,0)),900) AS win_15min_bytes_per_second,
  SAFE_DIVIDE(SUM(IF(win_15min,load,0)),SUM(IF(win_15min,1,0))) AS win_15min_load_per_second,
  SAFE_DIVIDE(SUM(ops),TIMESTAMP_DIFF(MAX(timestamp), MIN(timestamp), SECOND)) AS life_ops_per_second,
  SAFE_DIVIDE(SUM(bytes),TIMESTAMP_DIFF(MAX(timestamp), MIN(timestamp), SECOND)) AS life_bytes_per_second,
  SAFE_DIVIDE(SUM(load),SUM(1)) AS life_load_per_second
FROM
  SrcData
GROUP BY
  infra,
  job_worker_type,
  job_worker_id,
  job_container_id
