#!/bin/bash
# Script to build and test a microservice

set -e

SERVICE_NAME="$1"
REGISTRY="$2"
IMAGE_TAG="$3"
LATEST_TAG="${4:-latest}"

if [ -z "$SERVICE_NAME" ] || [ -z "$REGISTRY" ] || [ -z "$IMAGE_TAG" ]; then
    echo "Usage: $0 <service-name> <registry> <image-tag> [latest-tag]"
    exit 1
fi

echo "========================================="
echo "Building ${SERVICE_NAME}..."
echo "Registry: ${REGISTRY}"
echo "Image Tag: ${IMAGE_TAG}"
echo "========================================="

# Build the service
echo "Step 1: Compiling ${SERVICE_NAME}..."
mvn clean compile -pl "${SERVICE_NAME}" -am

# Run the unit tests with coverage
echo "Step 2: Running unit tests with coverage for ${SERVICE_NAME}..."
mvn test -pl "${SERVICE_NAME}" -am


# Generate coverage reports
echo "Step 3: Generating coverage reports for ${SERVICE_NAME}..."
mvn jacoco:report -pl "${SERVICE_NAME}" -am || echo "Warning: Coverage report generation failed, continuing..."

# Package the service
echo "Step 4: Packaging ${SERVICE_NAME}..."
mvn package -pl "${SERVICE_NAME}" -am -DskipTests

# Create the Docker image
echo "Step 5: Building Docker image for ${SERVICE_NAME}..."
docker build -f "${SERVICE_NAME}/Dockerfile" \
    -t "${REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG}" \
    -t "${REGISTRY}/${SERVICE_NAME}:${LATEST_TAG}" \
    .

echo "✓ Successfully built ${SERVICE_NAME}:${IMAGE_TAG}"
echo ""
