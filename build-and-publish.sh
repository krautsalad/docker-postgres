#!/bin/sh
set -ex

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
VERSION=$(git describe --tags "$(git rev-list --tags --max-count=1)")

BUILD_CONTEXT="${SCRIPT_DIR}/"

docker buildx build \
--no-cache \
--platform linux/amd64,linux/arm64 \
--progress=plain \
-f "${SCRIPT_DIR}/docker/Dockerfile" \
-t krautsalad/postgres:latest \
-t krautsalad/postgres:${VERSION} \
"${BUILD_CONTEXT}"

until docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --push \
    -f "${SCRIPT_DIR}/docker/Dockerfile" \
    -t krautsalad/postgres:latest \
    -t krautsalad/postgres:${VERSION} \
    "${BUILD_CONTEXT}"; do
    echo "Retrying push for krautsalad/postgres…" ; sleep 2
done
