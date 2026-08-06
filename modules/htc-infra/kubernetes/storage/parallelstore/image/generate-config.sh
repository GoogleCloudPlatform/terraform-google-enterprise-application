#!/bin/sh

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

# Set default DFUSE_ARGS if not provided
if [ -z "$DFUSE_ARGS" ]; then
    export DFUSE_ARGS="-f -m=/mnt/daos --thread-count=32 --eq-count=16 --pool=default-pool --container=default-container --disable-wb-cache --multi-user"
fi

# Generate final supervisor config
envsubst < /etc/supervisord-template.conf > /etc/supervisor.conf

# Start supervisor with generated config
exec /usr/bin/supervisord -c /etc/supervisor.conf
