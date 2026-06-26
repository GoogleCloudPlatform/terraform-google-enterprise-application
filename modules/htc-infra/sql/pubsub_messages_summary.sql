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
      request_time,
      response_time,
      jobId,
      msgId,
      hostname,
      request_initId AS initId,
      response_initBytesRead/(1024*1024) AS init_mb_read,
      response_initFilesRead as init_files_read,
      (response_initTotalMicros - response_initComputeMicros)/1e6 as init_io_secs,
      response_initComputeMicros/1e6 AS init_compute_secs,
      response_taskBytesRead/(1024*1024) as task_mb_read,
      response_taskBytesWritten/(1024*1024) as task_mb_written,
      (response_taskTotalMicros - response_taskComputeMicros)/1e6 AS task_io_secs,
      response_taskComputeMicros/1e6 AS task_compute_secs
    FROM
      `${project_id}.${dataset_id}.${joined_table_id}`
  ),
  SumStats AS (
    SELECT
      jobId,
      initId,

      -- Job metrics and timings
      MIN(request_time) AS start_time,
      MIN(response_time) AS first_process_time,
      MAX(response_time) AS last_process_time,
      COUNTIF(task_compute_secs IS NULL) AS remaining_tasks,

      -- Init stats
      COUNTIF(init_compute_secs>0) AS init_jobs,
      SUM(init_compute_secs) AS init_compute_secs,
      MAX(init_io_secs) AS init_io_secs_max,
      MIN(IF(init_io_secs>0,init_io_secs,999999999)) AS init_io_secs_min,
      SUM(init_io_secs) AS init_io_secs_total,
      SUM(init_mb_read) AS init_mb_read_total,

      -- Task stats
      COUNTIF(task_compute_secs>0) AS task_jobs,
      SUM(task_compute_secs) AS task_compute_secs,
      MAX(task_io_secs) AS task_io_secs_max,
      MIN(IF(task_io_secs>0, task_io_secs,999999999)) AS task_io_secs_min,
      SUM(task_io_secs) AS task_io_secs_total,
      SUM(task_mb_read) AS task_mb_read_total,

    FROM
      SrcData
    GROUP BY
      JobId,
      initId
  )
SELECT
  *
FROM
  SumStats;
