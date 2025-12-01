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

# FROM debian:12-slim AS build

# RUN apt-get update && \
#     apt-get install -y \
#     curl \
#     gnupg2 \
#     libpci3 \
#     apt-transport-https \
#     dirmngr \
#     supervisor \
#     gettext-base && \
#     curl https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | apt-key add - && \
#     echo "deb https://us-central1-apt.pkg.dev/projects/parallelstore-packages v2-6-deb main" > /etc/apt/sources.list.d/artifact-registry.list && \
#     apt-get update && \
#     apt-get install -y daos-client && \
#     rm -rf /var/lib/apt/lists/* && \
#     mkdir -p /var/run/daos_agent /tmp/parallelstore

# FROM debian:12-slim

# ENV LIB_DIR_PREFIX=x86_64 \
#     LD_LINUX_FILE=/lib64/ld-linux-x86-64.so.2 \
#     LIB_DIR=/lib64/ \
#     LD_LIBRARY_PATH=/lib64

# COPY --from=build \
#     /bin/mount \
#     /bin/umount \
#     /bin/sh \
#     /bin/

# COPY --from=build \
#     /usr/bin/supervisord \
#     /usr/bin/supervisorctl \
#     /usr/bin/envsubst \
#     /usr/local/bin/

# COPY --from=build /etc/supervisor/ /etc/supervisor/
# COPY --from=build ${LD_LINUX_FILE} ${LIB_DIR}
# COPY --from=build /lib/lib*.so* /lib/
# COPY --from=build /lib64/lib*.so* /lib64/
# COPY --from=build /lib/${LIB_DIR_PREFIX}-linux-gnu/lib*.so* /lib/${LIB_DIR_PREFIX}-linux-gnu/
# COPY --from=build \
#     /usr/bin/daos_agent \
#     /usr/bin/dfuse \
#     /usr/bin/

# COPY --from=build /etc/daos /etc/daos/
# COPY --from=build /var/run/daos_agent /var/run/daos_agent/
# COPY --from=build /tmp/parallelstore /tmp/parallelstore/

# RUN echo '[supervisord]\n\
# nodaemon=true\n\
# \n\
# [program:daos_agent]\n\
# command=/usr/bin/daos_agent -o /etc/daos/daos_agent.yml\n\
# \n\
# [program:dfuse]\n\
# command=/usr/bin/dfuse %(ENV_DFUSE_ARGS)s\n\
# depends_on=daos_agent' > /etc/supervisord-template.conf

# RUN echo '#!/bin/sh\n\
# if [ -z "$DFUSE_ARGS" ]; then\n\
#     export DFUSE_ARGS="-f -m=/mnt/daos --thread-count=32 --eq-count=16 --pool=default-pool --container=default-container --disable-wb-cache --multi-user"\n\
# fi\n\
# envsubst < /etc/supervisord-template.conf > /etc/supervisor.conf\n\
# exec /usr/local/bin/supervisord -c /etc/supervisor.conf' > /generate-config.sh && \
# chmod +x /generate-config.sh

# EXPOSE 10001

# ENTRYPOINT ["/generate-config.sh"]

####
# Build stage for supervisord
FROM golang:alpine AS supervisor-builder

RUN apk add --no-cache --update git gcc rust

WORKDIR /tmp
RUN git clone https://github.com/ochinchina/supervisord.git
WORKDIR /tmp/supervisord/

RUN go build -a -ldflags "-linkmode external -extldflags -static" -o /usr/local/bin/supervisord github.com/ochinchina/supervisord

# RUN CGO_ENABLED=0 go build -a -ldflags "-linkmode external -extldflags -static" -o /usr/local/bin/supervisord github.com/ochinchina/supervisord


# Build stage for DAOS
FROM debian:12-slim AS build
RUN apt-get update && \
    apt-get install -y \
    curl gnupg2 libpci3 apt-transport-https dirmngr gettext-base && \
    curl https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | apt-key add - && \
    echo "deb https://us-central1-apt.pkg.dev/projects/parallelstore-packages v2-6-deb main" > /etc/apt/sources.list.d/artifact-registry.list && \
    apt-get update && \
    apt-get install -y daos-client && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/run/daos_agent /tmp/parallelstore

# Final stage
FROM gcr.io/distroless/base-debian12

ENV LIB_DIR_PREFIX=x86_64 \
    LD_LINUX_FILE=/lib64/ld-linux-x86-64.so.2 \
    LIB_DIR=/lib64/ \
    LD_LIBRARY_PATH=/lib64

# Copy static supervisord
COPY --from=supervisor-builder /usr/local/bin/supervisord /usr/bin/supervisord

# Copy required binaries and libraries
COPY --from=build \
    /usr/bin/envsubst \
    /usr/bin/daos_agent \
    /usr/bin/dfuse \
    /usr/bin/

COPY --from=build \
    /bin/mount \
    /bin/umount \
    /bin/sh \
    /bin/chmod \
    /bin/

# Copy libraries
COPY --from=build ${LD_LINUX_FILE} ${LIB_DIR}
COPY --from=build /lib/lib*.so* /lib/
COPY --from=build /lib64/lib*.so* /lib64/
COPY --from=build /lib/${LIB_DIR_PREFIX}-linux-gnu/lib*.so* /lib/${LIB_DIR_PREFIX}-linux-gnu/

# Copy DAOS configurations
COPY --from=build /etc/daos /etc/daos/
COPY --from=build /var/run/daos_agent /var/run/daos_agent/
COPY --from=build /tmp/parallelstore /tmp/parallelstore/

# Create supervisor config template
COPY generate-config.sh /generate-config.sh
COPY supervisord-template.conf /etc/supervisord-template.conf

RUN chmod +x /generate-config.sh

EXPOSE 10001

ENTRYPOINT ["/generate-config.sh"]
