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

set -e

die() {
  echo "${0##*/}: error: $*" >&2
  exit 1
}

if [ $# -eq 0 ]; then
    python3 /work/parse_arguments.py --help
    die "missing arguments"
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    python3 /work/parse_arguments.py --help
    exit 0
fi

# Parse arguments using the python helper
OUTPUT=$(python3 /work/parse_arguments.py "$@")
declare -A args="($OUTPUT)"

echo "Pull image ${args[artifact_url]}"
docker pull "${args[artifact_url]}"

echo "Resolving correct digest for ${args[artifact_url]}..."

ALL_DIGESTS=$(docker inspect "${args[artifact_url]}" --format='{{range .RepoDigests}}{{.}} {{end}}')
echo "All local digests found: $ALL_DIGESTS"

TARGET_BASE="${args[artifact_url]%%@*}"
TARGET_BASE="${TARGET_BASE%%:*}"
echo "Looking for repo base: ${TARGET_BASE}@"

IMAGE_AND_DIGEST=""

for digest in $ALL_DIGESTS; do
    if [[ "$digest" == "${TARGET_BASE}"* ]]; then
        IMAGE_AND_DIGEST="$digest"
        break
    fi
done

if [[ -z "$IMAGE_AND_DIGEST" ]]; then
    echo "Warning: Specific repository digest not found in local Docker list. Falling back to first available..."
    IMAGE_AND_DIGEST="${ALL_DIGESTS%% *}"
fi

echo "Selected Docker digest: ${IMAGE_AND_DIGEST}"

if ! echo "$IMAGE_AND_DIGEST" | grep -Eq "^[a-z0-9-]+-docker\.pkg\.dev/.+/.+@sha256:[a-f0-9]{64}$"; then
    echo "Local digest is not in Artifact Registry format. Attempting cloud lookup..."
    DIGEST_ONLY=$(gcloud artifacts docker images describe "${args[artifact_url]}" --format='value(image_summary.digest)')
    IMAGE_AND_DIGEST="${TARGET_BASE}@${DIGEST_ONLY}"
    echo "Cloud resolved digest: ${IMAGE_AND_DIGEST}"
fi

if [[ -z "$IMAGE_AND_DIGEST" ]] || [[ "$IMAGE_AND_DIGEST" != *"@"* ]]; then
    die "Critical failure: Not possible to get image digest (Host + Digest)."
fi

if [ -n "${args[pgp_key_fingerprint]}" ]; then
    if [ -z "$PGP_SECRET_KEY" ]; then
        die "PGP_SECRET_KEY environment variable is required if providing the PGP signing key through an environment variable."
    fi

    gcloud container binauthz create-signature-payload \
        --artifact-url="$IMAGE_AND_DIGEST" > binauthz_signature_payload.json

    mkdir -p ~/.gnupg
    echo allow-loopback-pinentry > ~/.gnupg/gpg-agent.conf
    if [ -z "$PGP_SECRET_KEY_PASSPHRASE" ]; then
        COMMON_FLAGS="--no-tty --pinentry-mode loopback"
    else
        COMMON_FLAGS="--no-tty --pinentry-mode loopback --passphrase ${PGP_SECRET_KEY_PASSPHRASE}"
    fi

    echo -n "$PGP_SECRET_KEY" | gpg2 "$COMMON_FLAGS" --import
    gpg2 "$COMMON_FLAGS" --output generated_signature.pgp --local-user "${args[pgp_key_fingerprint]}" --armor --sign binauthz_signature_payload.json
    gcloud container binauthz attestations create \
        --artifact-url="$IMAGE_AND_DIGEST" \
        --attestor="${args[attestor]}" \
        --signature-file=./generated_signature.pgp \
        --public-key-id="${args[pgp_key_fingerprint]}"
else
    gcloud beta container binauthz attestations sign-and-create \
        --attestor="${args[attestor]}" \
        --artifact-url="$IMAGE_AND_DIGEST" \
        --keyversion="${args[keyversion]}"
fi
echo "Successfully created attestation"
