#!/bin/bash
# Script to push Docker images to registry

set -e

REGISTRY="$1"
IMAGE_TAG="$2"
LATEST_TAG="$3"
CHANGED_SERVICES="$4"
DOCKER_USER="$5"
DOCKER_PASS="$6"

if [ -z "$REGISTRY" ] || [ -z "$IMAGE_TAG" ] || [ -z "$CHANGED_SERVICES" ]; then
    echo "Usage: $0 <registry> <image-tag> <latest-tag> <changed-services> <docker-user> <docker-pass>"
    exit 1
fi

echo "========================================="
echo "Pushing Docker images to registry..."
echo "Registry: ${REGISTRY}"
echo "Image Tag: ${IMAGE_TAG}"
echo "========================================="

# Login to Docker registry
echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

# Push changed services
IFS=',' read -ra SERVICE_ARRAY <<< "$CHANGED_SERVICES"
for service_name in "${SERVICE_ARRAY[@]}"; do
    echo "Pushing ${service_name}..."
    docker push "${REGISTRY}/${service_name}:${IMAGE_TAG}"
    docker push "${REGISTRY}/${service_name}:${LATEST_TAG}"
    echo "✓ Successfully pushed ${service_name}"
done

echo ""
echo "✓ All images pushed successfully"

