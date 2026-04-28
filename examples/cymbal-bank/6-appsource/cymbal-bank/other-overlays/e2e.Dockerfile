# Copyright 2022-2025 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM cypress/included:15.14.1@sha256:fe45121bcb4b604e35b13de801b844520a5dac2df89b42fe37b00cf88bfc4c03

WORKDIR /e2e
COPY . .

# install curl and gpg which are needed for fetching the Google Cloud GPG key
RUN apt-get update
RUN apt-get install -y curl gpg

# install gcloud cli tools to get kubectl context and service/ingress endpoint ip to test
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    apt-get update -y && \
    apt-get install google-cloud-cli -y


# RUN apt-get update
RUN apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin kubectl curl

ENV USE_GKE_GCLOUD_AUTH_PLUGIN=True
ENV XDG_CONFIG_HOME=/e2e

# run custom bash script to set CYPRESS_baseUrl and execute tests
ENTRYPOINT [ "/bin/bash", "-c", "./run_for_env.sh" ]
