#!/bin/bash
# Script to scan Docker images for vulnerabilities using Trivy
# Usage: scan-image-trivy.sh <image-name:tag> [severity-threshold] [exit-on-failure]

# Don't use set -e here because we need to capture exit codes from Trivy
# set -e

IMAGE_NAME="$1"
SEVERITY_THRESHOLD="${2:-CRITICAL,HIGH}"  # Default: CRITICAL and HIGH
EXIT_ON_FAILURE="${3:-true}"  # Default: exit on failure
REPORT_FORMAT="${4:-table}"  # table, json, sarif

if [ -z "$IMAGE_NAME" ]; then
    echo "Usage: $0 <image-name:tag> [severity-threshold] [exit-on-failure] [report-format]"
    echo "Example: $0 myapp:latest CRITICAL true table"
    exit 1
fi

echo "========================================="
echo "Scanning Docker image with Trivy..."
echo "Image: ${IMAGE_NAME}"
echo "Severity Threshold: ${SEVERITY_THRESHOLD}"
echo "========================================="

# Check if Trivy is available (as Docker container or binary)
if command -v trivy &> /dev/null; then
    TRIVY_CMD="trivy"
elif docker ps &> /dev/null; then
    TRIVY_CMD="docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest"
else
    echo "✗ Error: Trivy not found and Docker is not available"
    exit 1
fi

# Create reports directory
REPORTS_DIR="trivy-reports"
mkdir -p "${REPORTS_DIR}"

# Extract image name and tag for report filename
IMAGE_BASENAME=$(echo "${IMAGE_NAME}" | sed 's/[\/:]/-/g')
REPORT_FILE="${REPORTS_DIR}/${IMAGE_BASENAME}-trivy-report.json"
EXIT_CODE=0

echo ""
echo "Running Trivy scan..."

# Run Trivy scan and show results in console
echo ""
echo "Scan Results:"
if [ "$TRIVY_CMD" = "trivy" ]; then
    # Trivy binary - show table first and capture exit code
    set +e  # Temporarily disable exit on error to capture exit code
    trivy image \
        --severity "${SEVERITY_THRESHOLD}" \
        --format table \
        "${IMAGE_NAME}"
    EXIT_CODE=$?
    set -e  # Re-enable exit on error
    
    # Generate JSON report
    trivy image \
        --severity "${SEVERITY_THRESHOLD}" \
        --format json \
        --output "${REPORT_FILE}" \
        --exit-code 0 \
        "${IMAGE_NAME}" || true
else
    # Trivy Docker container - show table first and capture exit code
    set +e  # Temporarily disable exit on error to capture exit code
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        aquasec/trivy:latest \
        image \
        --severity "${SEVERITY_THRESHOLD}" \
        --format table \
        "${IMAGE_NAME}"
    EXIT_CODE=$?
    set -e  # Re-enable exit on error
    
    # Generate JSON report
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$(pwd)/${REPORTS_DIR}:/reports" \
        aquasec/trivy:latest \
        image \
        --severity "${SEVERITY_THRESHOLD}" \
        --format json \
        --output "/reports/${IMAGE_BASENAME}-trivy-report.json" \
        --exit-code 0 \
        "${IMAGE_NAME}" || true
fi

echo ""
echo "Report saved to: ${REPORT_FILE}"

# Check JSON report for vulnerabilities (even if marked as "fixed")
# Count vulnerabilities with CRITICAL or HIGH severity
VULN_COUNT=0
if [ -f "${REPORT_FILE}" ]; then
    # Use jq if available, otherwise use Python
    if command -v jq &> /dev/null; then
        # Parse severity threshold
        if echo "${SEVERITY_THRESHOLD}" | grep -qi "CRITICAL"; then
            CRITICAL_COUNT=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "${REPORT_FILE}" 2>/dev/null || echo "0")
            VULN_COUNT=$((VULN_COUNT + CRITICAL_COUNT))
        fi
        if echo "${SEVERITY_THRESHOLD}" | grep -qi "HIGH"; then
            HIGH_COUNT=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "${REPORT_FILE}" 2>/dev/null || echo "0")
            VULN_COUNT=$((VULN_COUNT + HIGH_COUNT))
        fi
    elif command -v python3 &> /dev/null; then
        # Fallback to Python
        VULN_COUNT=$(python3 -c "
import json
import sys
severities = [s.upper() for s in '${SEVERITY_THRESHOLD}'.split(',')]
try:
    with open('${REPORT_FILE}', 'r') as f:
        data = json.load(f)
    count = 0
    for result in data.get('Results', []):
        for vuln in result.get('Vulnerabilities', []):
            if vuln.get('Severity', '').upper() in severities:
                count += 1
    print(count)
except:
    print(0)
" 2>/dev/null || echo "0")
    fi
fi

# Check if vulnerabilities were found
if [ $VULN_COUNT -gt 0 ] || [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "⚠ WARNING: Vulnerabilities found in image ${IMAGE_NAME}"
    echo "Severity threshold: ${SEVERITY_THRESHOLD}"
    if [ $VULN_COUNT -gt 0 ]; then
        echo "Found ${VULN_COUNT} vulnerabilities matching threshold"
    fi
    
    if [ "$EXIT_ON_FAILURE" = "true" ]; then
        echo ""
        echo "✗ Build failed due to security vulnerabilities"
        echo "Please review the report and fix the issues before proceeding."
        exit 1
    else
        echo "⚠ Continuing build despite vulnerabilities (exit-on-failure=false)"
    fi
else
    echo ""
    echo "✓ No vulnerabilities found above threshold: ${SEVERITY_THRESHOLD}"
fi

echo ""

