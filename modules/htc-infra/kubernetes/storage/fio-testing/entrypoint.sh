#!/bin/bash

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

# Default values for environment variables
MOUNT_PATH=${MOUNT_PATH:-"/data"}
CONFIG_PATH=${CONFIG_PATH:-"/etc/fio/fio.conf"}

# Function to handle SIGTERM and SIGINT
term_handler() {
  echo "Signal received. Stopping FIO gracefully..."

  # Find FIO processes that are children of *this* script.
  fio_pid=$(pgrep -P $$ fio)

  if [ -n "$fio_pid" ]; then
    echo "Sending SIGINT to FIO process(es): $fio_pid"
    kill -INT "$fio_pid"
  else
    echo "FIO process not found."
  fi

  # Wait for FIO to exit (with a timeout).
  wait_counter=0
  while [ -n "$(pgrep -P $$ fio)" ] && [ "$wait_counter" -lt 10 ]; do
    echo "Waiting for FIO to exit..."
    sleep 1
    wait_counter=$((wait_counter + 1))
  done

   if [ -n "$(pgrep -P $$ fio)" ]; then
        echo "FIO did not exit gracefully after 10 seconds.  Killing forcefully."
        pkill -9 fio || echo "pkill -9 fio returned non-zero (likely no FIO process running)"
    fi


  echo "Exiting entrypoint script."
  exit 0  # Exit with success code (important!)
}

# Trap SIGTERM and SIGINT.  SIGKILL cannot be trapped.
trap term_handler SIGTERM SIGINT

# Function to check if path is mounted
check_mount() {
    local path=$1
    local max_attempts=30
    local attempt=1

    echo "Checking mount point: $path"

    while ! mountpoint -q "${path}"; do
        if [ $attempt -ge $max_attempts ]; then
            echo "Mount point ${path} not ready after ${max_attempts} attempts. Exiting."
            exit 1
        fi
        echo "Waiting for ${path} to be mounted... (attempt $attempt/$max_attempts)"
        sleep 5
        attempt=$((attempt + 1))
    done

    echo "Mount point ${path} is ready"
}

# Function to validate FIO config
validate_fio_config() {
    if [ ! -f "${CONFIG_PATH}" ]; then
        echo "Error: FIO config file ${CONFIG_PATH} not found"
        exit 1
    fi
}

# Main execution
echo "Starting FIO test runner"
echo "Mount path: ${MOUNT_PATH}"
echo "Config file: ${CONFIG_PATH}"

# Run checks
check_mount "${MOUNT_PATH}"
validate_fio_config

# Run FIO in the background, capturing output to a variable
echo "Starting FIO benchmark..."
output=$(fio --directory="${MOUNT_PATH}" \
    --output-format=json+ \
    "${CONFIG_PATH}")
fio_pid=$!

# Wait for the FIO process
wait "$fio_pid"

# Pipe the captured output to jq
echo "$output" | jq -c

# Check FIO exit status
FIO_STATUS=$?

#If termination due to signal, make sure to exit clean
if [ $FIO_STATUS -eq 130 ] || [ $FIO_STATUS -eq 128 ] || [ $FIO_STATUS -eq 0 ]; then
	echo "FIO terminated cleanly"
	exit 0
fi


if [ $FIO_STATUS -ne 0 ]; then
    echo "FIO failed with exit status: ${FIO_STATUS}"
    exit $FIO_STATUS
fi

echo "FIO benchmark completed successfully"
