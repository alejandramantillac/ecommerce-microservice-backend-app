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

# Run the unit tests
echo "Step 2: Running unit tests for ${SERVICE_NAME}..."
mvn test -pl "${SERVICE_NAME}" -am

# Run SonarQube analysis
echo "Step 2.5: Running SonarQube analysis for ${SERVICE_NAME}..."
if [ -f "${SERVICE_NAME}/sonar-project.properties" ]; then
    if [ -z "${SONAR_TOKEN}" ]; then
        echo "⚠ Warning: SONAR_TOKEN not set, skipping SonarQube analysis"
    else
        SONAR_PROJECT_KEY="ecommerce-microservice-backend:${SERVICE_NAME}"
        SONAR_HOST="${SONAR_HOST_URL:-http://localhost:9000}"
        
        # Run SonarQube analysis
        echo "Running SonarQube analysis..."
        if ! mvn sonar:sonar \
            -pl "${SERVICE_NAME}" \
            -am \
            -Dsonar.projectKey="${SONAR_PROJECT_KEY}" \
            -Dsonar.host.url="${SONAR_HOST}" \
            -Dsonar.login="${SONAR_TOKEN}" \
            -DskipTests; then
            echo "✗ SonarQube analysis failed"
            exit 1
        fi
        
        echo "✓ SonarQube analysis completed"
        
        # Check Quality Gate
        echo ""
        echo "Step 2.6: Checking SonarQube Quality Gate..."
        if [ -f "jenkins/scripts/check-sonarqube-quality-gate.sh" ]; then
            chmod +x jenkins/scripts/check-sonarqube-quality-gate.sh
            
            # Check if Quality Gate enforcement is enabled (default: true)
            ENFORCE_QUALITY_GATE="${SONAR_ENFORCE_QUALITY_GATE:-true}"
            
            if [ "$ENFORCE_QUALITY_GATE" = "true" ]; then
                jenkins/scripts/check-sonarqube-quality-gate.sh \
                    "${SONAR_PROJECT_KEY}" \
                    "${SONAR_HOST}" \
                    "${SONAR_TOKEN}" \
                    60 || {
                    echo ""
                    echo "✗ Build failed: Quality Gate did not pass"
                    echo "Please fix the quality issues and try again."
                    echo "View details in SonarQube: ${SONAR_HOST}/dashboard?id=${SONAR_PROJECT_KEY}"
                    exit 1
                }
                echo "✓ Quality Gate PASSED"
            else
                echo "⚠ Quality Gate enforcement is disabled (SONAR_ENFORCE_QUALITY_GATE=false)"
                echo "⚠ Continuing build without Quality Gate check"
            fi
        else
            echo "⚠ Warning: check-sonarqube-quality-gate.sh not found, skipping Quality Gate check"
        fi
    fi
else
    echo "⚠ Warning: sonar-project.properties not found for ${SERVICE_NAME}, skipping SonarQube analysis"
fi

# Package the service
echo "Step 3: Packaging ${SERVICE_NAME}..."
mvn package -pl "${SERVICE_NAME}" -am -DskipTests

# Create the Docker image
echo "Step 4: Building Docker image for ${SERVICE_NAME}..."
docker build -f "${SERVICE_NAME}/Dockerfile" \
    -t "${REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG}" \
    -t "${REGISTRY}/${SERVICE_NAME}:${LATEST_TAG}" \
    .

echo "✓ Successfully built ${SERVICE_NAME}:${IMAGE_TAG}"
echo ""

# Scan Docker image with Trivy
echo "Step 4.5: Scanning Docker image for vulnerabilities with Trivy..."
if [ -f "jenkins/scripts/scan-image-trivy.sh" ]; then
    chmod +x jenkins/scripts/scan-image-trivy.sh
    
    # Get severity threshold from environment or use default
    TRIVY_SEVERITY="${TRIVY_SEVERITY_THRESHOLD:-CRITICAL,HIGH}"
    TRIVY_EXIT_ON_FAILURE="${TRIVY_EXIT_ON_FAILURE:-true}"
    
    jenkins/scripts/scan-image-trivy.sh \
        "${REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG}" \
        "${TRIVY_SEVERITY}" \
        "${TRIVY_EXIT_ON_FAILURE}" \
        "json" || {
        echo "✗ Trivy scan failed for ${SERVICE_NAME}"
        exit 1
    }
else
    echo "⚠ Warning: scan-image-trivy.sh not found, skipping vulnerability scan"
fi

echo ""

