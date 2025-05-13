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

from google.cloud import parallelstore_v1
import logging
import os
import sys
import argparse
import time

# Configure logging
logging.basicConfig(stream=sys.stdout, level=logging.INFO)
logger = logging.getLogger(__name__)


def import_data_to_parallelstore(
    gcs_bucket, path, instance, location, request_id, project_id
):
    """Imports data from GCS to Parallelstore."""

    client = parallelstore_v1.ParallelstoreClient()

    source_gcs_bucket = parallelstore_v1.SourceGcsBucket()
    source_gcs_bucket.uri = f"gs://{gcs_bucket}"

    request = parallelstore_v1.ImportDataRequest(
        source_gcs_bucket=source_gcs_bucket,
        name=f"projects/{project_id}/locations/{location}/instances/{instance}",
    )
    if request_id is not None:
        request.request_id = request_id
    if path != "/":
        request.destination_parallelstore = path

    operation = client.import_data(request=request)
    log_operation_start(
        "Import", gcs_bucket, instance, location, project_id, request_id
    )

    wait_for_operation(operation)

    if operation.done():
        response = operation.result()
        logger.info(f"Operation succeeded: {response}")


def export_data_to_gcs(gcs_bucket, path, instance, location, request_id, project_id):
    """Exports data from Parallelstore to GCS."""

    client = parallelstore_v1.ParallelstoreClient()

    destination_gcs_bucket = parallelstore_v1.DestinationGcsBucket()
    destination_gcs_bucket.uri = f"gs://{gcs_bucket}"

    request = parallelstore_v1.ExportDataRequest(
        name=f"projects/{project_id}/locations/{location}/instances/{instance}",
        destination_gcs_bucket=destination_gcs_bucket,
    )

    if request_id is not None:
        request.request_id = request_id
    if path != "/":
        request.destination_parallelstore = path

    operation = client.export_data(request=request)
    log_operation_start(
        "Export", gcs_bucket, instance, location, project_id, request_id
    )

    wait_for_operation(operation)

    if operation.done():
        response = operation.result()
        logger.info(f"Operation succeeded: {response}")


def log_operation_start(
    operation_type, gcs_bucket, instance, location, project_id, request_id
):
    """Logs the start of an import/export operation."""
    logger.info(f"Starting {operation_type}")
    logger.info(f"GCS Bucket: {gcs_bucket}")
    logger.info(f"Parallelstore Instance: {instance}")
    logger.info(f"Location: {location}")
    logger.info(f"Project ID: {project_id}")
    logger.info(f"Request ID: {request_id}")


def wait_for_operation(operation):
    """Waits for a long-running operation to complete."""
    while not operation.done():
        logger.info("Waiting for operation to complete...")
        time.sleep(10)


def main():
    parser = argparse.ArgumentParser(
        description="Import or Export data between Parallelstore and GCS",
        epilog="Example usage: python import_data.py --mode import --gcsbucket my-bucket-name --instance my-instance-name --location us-central1-a",
    )
    parser.add_argument(
        "--mode",
        required=True,
        help="Import or Export data to / from a Parallelstore Instance",
    )
    parser.add_argument(
        "--gcsbucket",
        required=False,
        help="specifies the URI to a Cloud Storage bucket, or a path within a bucket, using the format gs://<bucket_name>/<optional_path_inside_bucket>",
    )
    parser.add_argument(
        "--path",
        required=False,
        default="/",
        help="Root directory path to the Parallelstore file system",
    )
    parser.add_argument(
        "--instance", required=False, help="Parallelstore instance name"
    )
    parser.add_argument(
        "--location",
        required=False,
        help="Parallelstore location, must be a supported zone.",
    )
    parser.add_argument("--project-id", required=False, help="Project ID")
    parser.add_argument(
        "--request-id",
        required=False,
        default=None,
        help="allows you to assign a unique ID to this request. If you retry this request using the same request ID, the server will ignore the request if it has already been completed. Must be a valid UUID that is not all zeros.",
    )
    args = parser.parse_args()

    # Get values from environment variables or command-line arguments
    gcs_bucket = os.environ.get("GCS_BUCKET", args.gcsbucket)
    path = os.environ.get("PARALLELSTORE_PATH", args.path)
    instance = os.environ.get("PARALLELSTORE_INSTANCE", args.instance)
    location = os.environ.get("PARALLELSTORE_LOCATION", args.location)
    project_id = os.environ.get("PROJECT_ID", args.project_id)
    request_id = os.environ.get("REQUEST_ID", args.request_id)

    # Check for missing values
    missing_args = []
    for arg_name, arg_value in [
        ("GCS_BUCKET", gcs_bucket),
        ("PARALLELSTORE_INSTANCE", instance),
        ("PARALLELSTORE_LOCATION", location),
        ("project_id", project_id),
    ]:
        if arg_value is None:
            missing_args.append(arg_name)

    if missing_args:
        logger.error(f"Error: Missing required arguments: {', '.join(missing_args)}")
        logger.error(
            "Please provide them through command-line arguments or environment variables."
        )
        exit(1)  # Exit with an error code

    if args.mode == "import":
        import_data_to_parallelstore(
            gcs_bucket, path, instance, location, request_id, project_id
        )
    elif args.mode == "export":
        export_data_to_gcs(gcs_bucket, path, instance, location, request_id, project_id)
    else:
        logger.error("Missing operation mode")


if __name__ == "__main__":
    main()
