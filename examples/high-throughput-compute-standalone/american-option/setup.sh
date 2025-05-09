#!/bin/bash
#
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


# Ensure python3 is installed
if ! $(which python3 > /dev/null); then
  echo "python3 needs to be installed"
  exit 1
fi

ROOT="$(dirname $0)"
VENV="${ROOT}/.venv"

# Create virtual environment
[ -d "${VENV}" ] || (
  echo "creating virtual environment"
  python3 -m venv "${VENV}"
  "${VENV}/bin/python3" -m ensurepip
  "${VENV}/bin/python3" -m pip install uv
)

# Lock requirements if needed
if [ -f "${ROOT}/requirements.in" ] && [ "${ROOT}/requirements.in" -nt "${ROOT}/requirements.txt" ]; then
  "${VENV}/bin/python3" -m uv --quiet pip compile --generate-hashes "${ROOT}/requirements.in" > "${ROOT}/requirements.txt"
fi

# Sync
"${VENV}/bin/python3" -m uv --quiet pip sync "${ROOT}/requirements.txt"

# Re-generate protobuf code
"${VENV}/bin/python3" -m grpc_tools.protoc --proto_path="${ROOT}" --python_out="${ROOT}" "${ROOT}"/*.proto
"${VENV}/bin/python3" -m grpc_tools.protoc -I"${ROOT}" --python_out="${ROOT}" --grpc_python_out="${ROOT}" "${ROOT}/service.proto"
