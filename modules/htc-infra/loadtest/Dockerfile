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

FROM golang:1.24 AS bld

# Fetch building tools
RUN apt-get update && apt-get install -y \
  ca-certificates openssl \
  golang-google-protobuf-dev \
  protoc-gen-go \
  protoc-gen-go-grpc \
  && rm -rf /var/lib/apt/lists/*

# Fetch Dependencies
WORKDIR /build/go
COPY go.* /build/go/
RUN go mod download

# Copy in code and build
COPY . /build/go/
RUN go generate
RUN CGO_ENABLED=0 go build

# Final build
FROM gcr.io/distroless/static-debian12

COPY --from=bld /build/go/loadtest /loadtest

ENTRYPOINT [ "/loadtest" ]
