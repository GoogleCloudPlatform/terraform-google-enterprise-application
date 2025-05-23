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

FROM python:3.12

# Update
RUN apt-get update && \
    apt-get install --yes --no-install-recommends apt-transport-https ca-certificates gnupg curl

RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

RUN apt-get update && apt-get install --yes --no-install-recommends \
    google-cloud-cli \
    google-cloud-sdk-gke-gcloud-auth-plugin \
    kubectl
#    python3 \
#    python3-venv \
#    python3-pip

# Install dependencies using require-hashes
WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN python3 -m venv .venv
RUN .venv/bin/python3 -m pip install --require-hashes -r requirements.txt

# Copy across files
COPY main.py config.yaml /app/

# Entrypoint
ENTRYPOINT [ ".venv/bin/python3", "main.py", "./config.yaml" ]
