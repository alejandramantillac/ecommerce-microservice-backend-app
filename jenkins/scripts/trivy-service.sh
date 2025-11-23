#!/bin/bash
# Script to scan Docker image for vulnerabilities with Trivy
# Usage: trivy-service.sh <service-name> <registry> <image-tag>
# Example: trivy-service.sh myapp myregistry myapp:latest

SERVICE_NAME="$1"
REGISTRY="$2"
IMAGE_TAG="$3"

if [ -z "$SERVICE_NAME" ] || [ -z "$REGISTRY" ] || [ -z "$IMAGE_TAG" ]; then
    echo "Usage: $0 <service-name> <registry> <image-tag>"
    exit 1
fi
echo "Step 4.5: Scanning Docker image for vulnerabilities with Trivy..."
if [ -f "jenkins/scripts/scan-image-trivy.sh" ]; then
    chmod +x jenkins/scripts/scan-image-trivy.sh
    
    # Get severity threshold from environment or use default
    TRIVY_SEVERITY="$TRIVY_SEVERITY_THRESHOLD"
    TRIVY_EXIT_ON_FAILURE="$TRIVY_EXIT_ON_FAILURE"
    TRIVY_REPORT_FORMAT="$TRIVY_REPORT_FORMAT"
    
    jenkins/scripts/scan-image-trivy.sh \
        "${REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG}" \
        "${TRIVY_SEVERITY}" \
        "${TRIVY_EXIT_ON_FAILURE}" \
        "${TRIVY_REPORT_FORMAT}" || {
        echo "✗ Trivy scan failed for ${SERVICE_NAME}"
        exit 1
    }
else
    echo "⚠ Warning: scan-image-trivy.sh not found, skipping vulnerability scan"
fi