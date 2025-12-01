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
  Src AS (
    SELECT
      JSON_VALUE(attributes, "$.srcId") AS msgId,
      REGEXP_EXTRACT(subscription_name, r"^projects/[0-9]+/subscriptions/(.*)$") AS subscription_name,
      message_id,
      publish_time,
      SAFE_CAST(JSON_VALUE(attributes, "$.srcTimeNano") AS INT64) AS srcTimeNano,
      JSON_VALUE(attributes, "$.Hostname") AS hostname,
      data
    FROM
      `${project_id}.${dataset_id}.${table_id}`
  ),
  Request AS (
    SELECT
      msgId,

      subscription_name AS request_subscription_name,
      message_id AS request_message_id,
      publish_time AS request_time,

      LAX_INT64(JSON_QUERY(data, "$.init.id")) AS request_initId,
      LAX_FLOAT64(JSON_QUERY(data, "$.init.percCrash")) AS request_initPercCrash,
      LAX_FLOAT64(JSON_QUERY(data, "$.init.percFail")) AS request_initPercFail,
      LAX_INT64(JSON_QUERY(data, "$.init.maxMicros")) AS request_initMaxMicros,
      LAX_INT64(JSON_QUERY(data, "$.init.minMicros")) AS request_initMinMicros,
      LAX_INT64(JSON_QUERY(data, "$.init.resultSize")) AS request_initResultSize,
      LENGTH(JSON_VALUE(data, "$.init.payload")) AS request_initPayloadSize,
      JSON_VALUE(data, "$.init.readFile") AS request_initReadFile,
      JSON_VALUE(data, "$.init.readDir") AS request_initReadDir,
      JSON_VALUE(data, "$.init.writeFile") AS request_initWriteFile,
      LAX_INT64(JSON_QUERY(data, "$.init.writeBytes")) AS request_initWriteBytes,

      LAX_INT64(JSON_QUERY(data, "$.task.id")) AS request_taskId,
      LAX_FLOAT64(JSON_QUERY(data, "$.task.percCrash")) AS request_taskPercCrash,
      LAX_FLOAT64(JSON_QUERY(data, "$.task.percFail")) AS request_taskPercFail,
      LAX_INT64(JSON_QUERY(data, "$.task.maxMicros")) AS request_taskMaxMicros,
      LAX_INT64(JSON_QUERY(data, "$.task.minMicros")) AS request_taskMinMicros,
      LAX_INT64(JSON_QUERY(data, "$.task.resultSize")) AS request_taskResultSize,
      LENGTH(JSON_VALUE(data, "$.task.payload")) AS request_taskPayloadSize,
      JSON_VALUE(data, "$.task.readFile") AS request_taskReadFile,
      JSON_VALUE(data, "$.task.readDir") AS request_taskReadDir,
      JSON_VALUE(data, "$.task.writeFile") AS request_taskWriteFile,
      LAX_INT64(JSON_QUERY(data, "$.task.writeBytes")) AS request_taskWriteBytes
    FROM
      Src s
    WHERE
      hostname IS NULL
  ),
  Response AS (
    SELECT
      msgId,

      subscription_name AS response_subscription_name,
      message_id AS response_message_id,
      publish_time AS response_time,
      hostname,

      LAX_INT64(JSON_QUERY(data, "$.init.id")) AS response_initId,
      LENGTH(JSON_VALUE(data, "$.init.payload")) AS response_initPayloadSize,
      LAX_INT64(JSON_QUERY(data, "$.init.compute_micros")) AS response_initComputeMicros,
      LAX_INT64(JSON_QUERY(data, "$.init.files_read")) AS response_initFilesRead,
      LAX_INT64(JSON_QUERY(data, "$.init.bytes_read")) AS response_initBytesRead,
      LAX_INT64(JSON_QUERY(data, "$.init.bytes_written")) AS response_initBytesWritten,
      LAX_INT64(JSON_QUERY(data, "$.init.total_micros")) AS response_initTotalMicros,

      LAX_INT64(JSON_QUERY(data, "$.task.id")) AS response_taskId,
      LENGTH(JSON_VALUE(data, "$.task.payload")) AS response_taskPayloadSize,
      LAX_INT64(JSON_QUERY(data, "$.task.compute_micros")) AS response_taskComputeMicros,
      LAX_INT64(JSON_QUERY(data, "$.task.files_read")) AS response_taskFilesRead,
      LAX_INT64(JSON_QUERY(data, "$.task.bytes_read")) AS response_taskBytesRead,
      LAX_INT64(JSON_QUERY(data, "$.task.bytes_written")) AS response_taskBytesWritten,
      LAX_INT64(JSON_QUERY(data, "$.task.total_micros")) AS response_taskTotalMicros
    FROM
      Src
    WHERE
      hostname IS NOT NULL
  )
SELECT
  REGEXP_EXTRACT(msgId, "Job-([0-9]+)-") AS jobId,
  *
FROM
  Request
  LEFT JOIN Response USING (msgId);
