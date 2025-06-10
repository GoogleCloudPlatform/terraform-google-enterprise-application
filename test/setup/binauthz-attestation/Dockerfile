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

FROM gcr.io/google.com/cloudsdktool/cloud-sdk:alpine

RUN apk update && apk upgrade --no-cache

RUN gcloud components install beta --quiet

RUN apk add --no-cache docker gnupg bash python3

WORKDIR /work
ADD create_binauthz_attestation.sh /work
ADD parse_arguments.py /work
RUN chmod +x /work/create_binauthz_attestation.sh

ENTRYPOINT [ "/work/create_binauthz_attestation.sh" ]
