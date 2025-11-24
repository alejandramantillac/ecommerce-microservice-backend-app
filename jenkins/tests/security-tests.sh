#!/bin/bash
# Script to run OWASP ZAP security tests
# Usage: security-tests.sh <namespace> <api-gateway-url> [scan-type] [report-dir]

set -e

NAMESPACE="${1:-staging}"
API_GATEWAY_URL="${2:-http://api-gateway.staging.svc.cluster.local:8080}"
SCAN_TYPE="${3:-baseline}"  # baseline, full, api
REPORT_DIR="${4:-zap-reports}"

echo "========================================="
echo "Running OWASP ZAP Security Tests"
echo "Namespace: ${NAMESPACE}"
echo "API Gateway: ${API_GATEWAY_URL}"
echo "Scan Type: ${SCAN_TYPE}"
echo "Report Directory: ${REPORT_DIR}"
echo "========================================="

echo ""
echo "Setting up environment..."
cd tests

# Ensure security directory exists
mkdir -p security
cd security

# Make scripts executable
chmod +x zap-baseline-scan.sh zap-full-scan.sh zap-api-scan.sh 2>/dev/null || true

echo ""
echo "Starting OWASP ZAP ${SCAN_TYPE} scan..."

# Run appropriate scan based on type
case "${SCAN_TYPE}" in
    baseline)
        echo "Running baseline scan (quick, ~2-5 minutes)..."
        ./zap-baseline-scan.sh "${API_GATEWAY_URL}" "${REPORT_DIR}" 300
        ;;
    full)
        echo "Running full scan (comprehensive, ~10-30 minutes)..."
        ./zap-full-scan.sh "${API_GATEWAY_URL}" "${REPORT_DIR}" 1800
        ;;
    api)
        echo "Running API scan (targeted, ~5-10 minutes)..."
        ./zap-api-scan.sh "${API_GATEWAY_URL}" "/api" "${REPORT_DIR}" 600
        ;;
    *)
        echo "Unknown scan type: ${SCAN_TYPE}"
        echo "Valid types: baseline, full, api"
        exit 1
        ;;
esac

TEST_EXIT_CODE=$?

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "========================================="
    echo "✓ Security tests completed successfully"
    echo "========================================="
else
    echo "========================================="
    echo "⚠ Security tests found vulnerabilities"
    echo "Please review the reports in: ${REPORT_DIR}/"
    echo "========================================="
fi

# Move reports to repo root so Jenkins can archive them
if [ -d "${REPORT_DIR}" ]; then
    cp -r "${REPORT_DIR}" ../../ 2>/dev/null || true
fi

# Move back to root
cd ../..

exit $TEST_EXIT_CODE

