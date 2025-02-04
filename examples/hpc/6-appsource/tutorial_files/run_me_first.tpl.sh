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

export GKEBATCH_CLUSTER_NAME=${cluster_name}
export GKEBATCH_REGION=${region}
export GKEBATCH_PROJECT_ID=${project_id}
export GKEBATCH_BUCKETNAME=${bucket_name}

gcloud container clusters get-credentials $GKEBATCH_CLUSTER_NAME \
    --location=$GKEBATCH_REGION \
    --project=$GKEBATCH_PROJECT_ID

gcloud config set project $GKEBATCH_PROJECT_ID
export GKEBATCH_PROJECT_NUMBER=`gcloud projects list \
--filter="$(gcloud config get-value project)" \
--format="value(PROJECT_NUMBER)"`

python3 -m pip install -q -r requirements.txt
sudo apt-get install kubectl google-cloud-cli-gke-gcloud-auth-plugin
