#!/bin/bash

# Constants
IMAGE_NAME="maxiviper117/ubuntu-vps-simulate"
REGISTRY="docker.io"  # Default registry

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Display usage
usage() {
    echo "Usage: $0 [version]"
    echo "If version is not provided, it will be extracted from git tags"
    exit 1
}

# Error handling function
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Get version
if [ -z "$1" ]; then
    VERSION=$(git describe --tags | sed 's/^v//') || error_exit "Failed to get version from git tags"
else
    VERSION="$1"
fi

# Build image
echo -e "${GREEN}Building image ${IMAGE_NAME}:${VERSION}${NC}"
docker build -t "${REGISTRY}/${IMAGE_NAME}:${VERSION}" . || error_exit "Docker build failed"

# Push version tag
echo -e "${GREEN}Pushing ${IMAGE_NAME}:${VERSION}${NC}"
docker push "${IMAGE_NAME}:${VERSION}" || error_exit "Failed to push version tag"

# Tag and push latest
echo -e "${GREEN}Tagging and pushing latest${NC}"
docker tag "${IMAGE_NAME}:${VERSION}" "${IMAGE_NAME}:latest" || error_exit "Failed to create latest tag"
docker push "${IMAGE_NAME}:latest" || error_exit "Failed to push latest tag"

echo -e "${GREEN}Successfully pushed ${IMAGE_NAME}:${VERSION} and ${IMAGE_NAME}:latest${NC}"