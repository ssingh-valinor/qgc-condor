#!/usr/bin/env bash

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${SOURCE_DIR}/build"
DOCKERFILE_PATH="${SOURCE_DIR}/deploy/docker/Dockerfile-build-ubuntu"
IMAGE_NAME="${IMAGE_NAME:-qgc-ubuntu-docker}"
QGC_BUILD_TYPE="${QGC_BUILD_TYPE:-Release}"

mkdir -p "${BUILD_DIR}"

docker build --file "${DOCKERFILE_PATH}" --tag "${IMAGE_NAME}" "${SOURCE_DIR}"

# Running as the invoking user keeps the artifacts in build/ owned by the host
# user instead of root. Pointing HOME at the bind-mounted build directory also
# persists the ccache between runs, which the container would otherwise discard.
# No FUSE device or added capability is required because the image sets
# APPIMAGE_EXTRACT_AND_RUN.
docker run \
  --rm \
  --user "$(id -u):$(id -g)" \
  --env HOME=/project/build \
  --env QGC_BUILD_TYPE="${QGC_BUILD_TYPE}" \
  --volume "${SOURCE_DIR}:/project/source" \
  --volume "${BUILD_DIR}:/project/build" \
  "${IMAGE_NAME}"
