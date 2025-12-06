
Interesting query:

SELECT
  start_time,
  jobId,
  initId,
  TIMESTAMP_DIFF(last_process_time, first_process_time, SECOND) as run_secs,
  last_process_time AS last_time,
  remaining_tasks AS queue,
  CAST(SAFE_DIVIDE(100*task_jobs,remaining_tasks+task_jobs) AS STRING FORMAT '999.9') AS perc_done,
  init_jobs,
  CAST(SAFE_DIVIDE(task_compute_secs, task_jobs) AS STRING FORMAT '999999.9') AS init_cpu_avg,
  CAST(SAFE_DIVIDE(init_io_secs_total, init_jobs) AS STRING FORMAT '999999.9') AS init_io_avg,
  task_jobs,
  CAST(SAFE_DIVIDE(task_compute_secs, task_jobs) AS STRING FORMAT '999999.9') AS task_cpu_avg,
  CAST(SAFE_DIVIDE(task_io_secs_total, task_jobs) AS STRING FORMAT '999999.9') AS task_io_avg,
from
  `fsi-scratch-18.workload.messages_summary`
ORDER BY
  start_time DESC
