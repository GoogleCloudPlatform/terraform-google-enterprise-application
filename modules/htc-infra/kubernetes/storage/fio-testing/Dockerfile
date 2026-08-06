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

FROM ubuntu:24.04

# Install FIO and supporting tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    fio \
    jq \
    python3 \
    python3-pip \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Create directories for tests and results
RUN mkdir -p /fio/jobs /fio/results

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["sh", "-c", "echo Using config file: $CONFIG_PATH; fio --directory=$MOUNT_PATH --output-format=json+ $CONFIG_PATH | jq -c"]
