#!/bin/bash
# Script to run SonarCloud analysis for a single microservice

set -euo pipefail

SERVICE_NAME="${1:-}"

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service-name>"
    exit 1
fi

if [ -z "${SONAR_TOKEN:-}" ]; then
    echo "✗ SONAR_TOKEN is not set; aborting SonarCloud analysis for ${SERVICE_NAME}"
    exit 1
fi

if [ -z "${SONAR_ORGANIZATION:-}" ]; then
    echo "✗ SONAR_ORGANIZATION is not set; aborting SonarCloud analysis for ${SERVICE_NAME}"
    exit 1
fi

if [ -z "${SONAR_HOST_URL:-}" ]; then
    echo "✗ SONAR_HOST_URL is not set; aborting SonarCloud analysis for ${SERVICE_NAME}"
    exit 1
fi

if [ ! -d "${SERVICE_NAME}" ]; then
    echo "✗ Service directory '${SERVICE_NAME}' does not exist"
    exit 1
fi

SONAR_PROJECT_KEY="${SONAR_ORGANIZATION}:${SERVICE_NAME}"
ENFORCE_QUALITY_GATE="${SONAR_ENFORCE_QUALITY_GATE:-true}"

echo "========================================="
echo "SonarCloud Analysis: ${SERVICE_NAME}"
echo "Project Key: ${SONAR_PROJECT_KEY}"
echo "========================================="

pushd "${SERVICE_NAME}" >/dev/null

mvn sonar:sonar \
    -Dsonar.projectKey="${SONAR_PROJECT_KEY}" \
    -Dsonar.organization="${SONAR_ORGANIZATION}" \
    -Dsonar.host.url="${SONAR_HOST_URL}" \
    -Dsonar.token="${SONAR_TOKEN}" \
    -DskipTests

popd >/dev/null

echo "✓ SonarCloud analysis finished for ${SERVICE_NAME}"

if [ "${ENFORCE_QUALITY_GATE}" = "true" ] && [ -f "jenkins/scan/check-sonarqube-quality-gate.sh" ]; then
    echo "Checking Quality Gate for ${SERVICE_NAME}..."
    chmod +x jenkins/scan/check-sonarqube-quality-gate.sh
    jenkins/scan/check-sonarqube-quality-gate.sh \
        "${SONAR_PROJECT_KEY}" \
        "${SONAR_HOST_URL}" \
        "${SONAR_TOKEN}" \
        60
else
    echo "Skipping Quality Gate enforcement for ${SERVICE_NAME} (ENFORCE_QUALITY_GATE=${ENFORCE_QUALITY_GATE})"
fi

