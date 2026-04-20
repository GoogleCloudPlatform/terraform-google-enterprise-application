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
# shellcheck disable=SC2154
export GKEBATCH_CLUSTER_NAME=${cluster_name}
export GKEBATCH_REGION=${region}
export GKEBATCH_PROJECT_ID=${project_id}
export GKEBATCH_BUCKETNAME=${bucket_name}

gcloud container fleet memberships get-credentials "$GKEBATCH_CLUSTER_NAME" \
    --location="$GKEBATCH_REGION" \
    --project="$GKEBATCH_PROJECT_ID"

gcloud config set project "$GKEBATCH_PROJECT_ID"
GKEBATCH_PROJECT_NUMBER=$(gcloud projects list \
--filter="$(gcloud config get-value project)" \
--format="value(PROJECT_NUMBER)")

export GKEBATCH_PROJECT_NUMBER

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

python3 -m pip install -q -r requirements.txt
sudo update && sudo apt-get install kubectl google-cloud-cli-gke-gcloud-auth-plugin packer -y
