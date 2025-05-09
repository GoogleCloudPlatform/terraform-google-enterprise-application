# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from google.cloud import bigquery

import numpy as np
import pandas as pd

import functools
import argparse
import datetime
import time
import gradio as gr
import asyncio
import yaml
import os
import stat
import tempfile
import logging
import textwrap


logger = logging.getLogger(__name__)


# Markdown help
def get_markdown(config):
    return textwrap.dedent(f"""
    # Research and Risk Solution Workload Manager

    ## Overview

    This allows you to access quick links into Google Cloud console as well as launch some jobs.

    It is designed to mimic what a basic job control interface may look like.

    ## Useful links:

    * [Monitoring Dashboard]({config['urls']['dashboard']})
    * [Cluster Dashboard]({config['urls']['cluster']})

    ## BigQuery

    * Open up the [BigQuery Cloud Run](https://console.cloud.google.com/run/detail/{config['region']}/workload-worker-bigquery/metrics?project={config['project_id']}) interface for monitoring.
    * Open up the [BigQuery RDF](https://console.cloud.google.com/bigquery?project={config['project_id']}&ws=!1m5!1m4!6m3!1s{config['project_id']}!2sworkload!3sworkload) function.
    * Click Invoke Persistent Function.
    * Run the following SQL which will do 1,000 tasks of 100ms each:
    ```sql
    SELECT
      `workload.workload`(TO_JSON(STRUCT(
        STRUCT(
          100000 AS min_micros
        ) AS task
      )))
    FROM
      UNNEST(GENERATE_ARRAY(1, 100)) AS i;
    ```
    """)


# BigQuery client
@functools.cache
def bigquery_client():
    return bigquery.Client()


# Run query in BigQuery
def run_query(config):
    jobs_query = textwrap.dedent(f"""
    SELECT
      jobId as JobId,
      start_time as Start,
      first_process_time as First,
      last_process_time as Last,
      remaining_tasks as Remaining,
      task_jobs as Done
    FROM
      `{config["pubsub_summary_table"]}`
    WHERE
      start_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3600 * 24 * 7 SECOND)
    ORDER BY
      start_time DESC
    """)

    logger.info("Running jobs query on BigQuery")
    query_job = bigquery_client().query(jobs_query)
    query_result = query_job.result()
    df = query_result.to_dataframe()
    df = df[
        [
            "JobId",
            "Start",
            "First",
            "Last",
            "Remaining",
            "Done",
        ]
    ]
    df = df.astype({"JobId": np.str_, "Done": np.int64})
    styler = df.style.format(
        {
            "Start": lambda v: v.strftime("%Y-%m-%d %H:%M:%S"),
            "Last": lambda v: v.strftime("%H:%M:%S")
            if isinstance(v, pd.Timestamp)
            else " ",
            "First": lambda v: v.strftime("%H:%M:%S")
            if isinstance(v, pd.Timestamp)
            else " ",
        }
    )
    logger.info("Done query on BigQuery")

    return styler


# Current timestamp
def timestamp():
    return datetime.datetime.fromtimestamp(time.time()).strftime("%Y-%m-%d %H:%M:%S")


# Run the shell asynchronously
async def run_shell(task):
    logging.info(f"Running shell task {task['name']}")
    with tempfile.NamedTemporaryFile(mode="w", suffix=".sh", delete=False) as t:
        os.chmod(t.name, stat.S_IXUSR | stat.S_IRUSR | stat.S_IWUSR)
        t.write(task["script"])
        t.close()

        # Record the output
        output = [
            f"{timestamp()} Running {task['name']} ({t.name})",
        ]
        yield "\n".join(output)

        # Launch the process
        proc = await asyncio.create_subprocess_shell(
            str(t.name),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )

        # Wait until it's done
        stdout, stderr = await proc.communicate()

        # Capture exit code
        logging.info(f"Task {task['name']} exited with {proc.returncode}")
        if proc.returncode > 0:
            output.append(f"{timestamp()} Process exited with code {proc.returncode}")
        else:
            output.append(f"{timestamp()} Process ran successfully")

        # Capture the stdout and stderr
        output.append("")
        for m in stdout.decode().split("\n"):
            output.append(m)
        all_output = "\n".join(output)

        if proc.returncode > 0:
            logging.info(f"Stdout/stderr: {all_output}")

        # Return the output
        yield all_output


def run_gradio(config, port=8080):
    # Default refresh rate (seconds)
    dftl_refresh = 30

    with gr.Blocks(
        theme=gr.themes.Glass(),
        analytics_enabled=False,
        title="Research and Risk Solution",
    ) as demo:
        with gr.Column():
            with gr.Accordion("Overview"):
                gr.Markdown(get_markdown(config))

            data_timer = gr.Timer(dftl_refresh)

            with gr.Accordion("Jobs", open=False):
                with gr.Row():
                    refresh_btn = gr.Button("Manual Refresh")
                    refresh_slider = gr.Slider(
                        interactive=True,
                        minimum=10.0,
                        maximum=60.0,
                        value=dftl_refresh,
                        step=1.0,
                        label="Refresh speed",
                    )
                    refresh_slider.change(
                        fn=lambda r: r, inputs=refresh_slider, outputs=data_timer
                    )
                    display_timestamp = gr.Textbox(label="Last Updated")

                # Display jobs
                display_jobs = gr.DataFrame(
                    lambda: run_query(config), row_count=10, every=data_timer
                )

                # On change, update timestamp
                display_jobs.change(
                    lambda: timestamp(),
                    outputs=display_timestamp,
                    show_progress="minimal",
                )

                # Re-run on Refresh
                refresh_btn.click(
                    fn=lambda: run_query(config),
                    inputs=None,
                    outputs=display_jobs,
                    show_progress="minimal",
                )

            with gr.Accordion("Launcher", open=False):
                with gr.Row():
                    with gr.Column(scale=1):
                        with gr.Group():
                            choice = gr.Dropdown(
                                choices=[t["name"] for t in config["tasks"]],
                                value=config["tasks"][0]["name"],
                                type="index",
                                label="Test Launch Configuration",
                                show_label=True,
                            )
                            btn1 = gr.Button(size="sm")
                    with gr.Column(scale=5):
                        desc = gr.Textbox(
                            value=config["tasks"][0]["description"],
                            interactive=False,
                            show_label=False,
                            max_lines=3,
                            lines=3,
                        )

                    choice.change(
                        lambda idx: config["tasks"][idx]["description"],
                        inputs=choice,
                        outputs=desc,
                    )

                output = gr.Textbox(
                    label="Output",
                    lines=10,
                    max_lines=20,
                    show_label=True,
                    interactive=False,
                    autoscroll=True,
                    render=True,
                    show_copy_button=True,
                )

        # Async wrapper function for the configuration
        async def run_task(idx):
            async for v in run_shell(config["tasks"][idx]):
                yield v

        btn1.click(fn=run_task, inputs=choice, outputs=output, show_progress="minimal")

    demo.launch(
        share=False, server_name="0.0.0.0", enable_monitoring=False, server_port=port
    )


# Launch the main
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-d",
        "--debug",
        help="Show debug information",
        action="store_const",
        dest="loglevel",
        const=logging.DEBUG,
        default=logging.INFO,
    )
    parser.add_argument(
        "-p",
        "--port",
        type=int,
        help="Port to listen to",
        dest="port",
        default=8080,
    )
    parser.add_argument(
        "config",
        type=argparse.FileType("rt"),
        help="Configuration file (normally config.yaml) for Gradio",
    )
    args = parser.parse_args()

    # Configure logging
    logging.basicConfig(
        format="%(asctime)s %(message)s",
        datefmt="%m/%d/%Y %H:%M:%S",
        level=args.loglevel,
    )

    # Show app
    run_gradio(config=yaml.load(args.config, Loader=yaml.SafeLoader), port=args.port)
