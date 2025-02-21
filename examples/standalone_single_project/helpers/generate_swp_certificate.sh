#!/bin/bash

# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

project_id=${1}
location=${2}

generate_self_signed_certificate() {
    if [[ ! -x "$(command -v openssl)" ]]; then
        echo "openssl not found"
        exit 1
    fi

    openssl req -x509 -newkey rsa:2048 \
        -keyout key.pem \
        -out cert.pem -days 365 \
        -subj '/CN=myswp.example.com' -nodes \
        -addext "subjectAltName=DNS:myswp.example.com"

    gcloud certificate-manager certificates create swp-certificate \
        --certificate-file=cert.pem \
        --private-key-file=key.pem \
        --location="${location}" \
        --project="${project_id}"
}
generate_self_signed_certificate
