#!/bin/bash
# Script to run end-to-end tests using Python/Pytest

set -e

NAMESPACE="${1:-staging}"
API_GATEWAY_URL="${2:-http://api-gateway.staging.svc.cluster.local:8080}"

echo "========================================="
echo "Running End-to-End Tests (Python/Pytest)"
echo "Namespace: ${NAMESPACE}"
echo "API Gateway: ${API_GATEWAY_URL}"
echo "========================================="

echo ""
echo "Setting up Python environment..."
cd tests

python3 -m pip install --break-system-packages -q -r requirements.txt 2>/dev/null || \
    python3 -m pip install -q -r requirements.txt

echo ""
echo "Running E2E tests..."
export API_GATEWAY_URL="${API_GATEWAY_URL}"

# Run pytest with E2E tests
pytest e2e/ -v -m e2e \
    --html=e2e-report.html \
    --self-contained-html \
    --json-report \
    --json-report-file=e2e-report.json \
    --tb=short

TEST_EXIT_CODE=$?

# Deactivate virtual environment
deactivate

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "========================================="
    echo "✓ All E2E tests passed successfully!"
    echo "========================================="
else
    echo "========================================="
    echo "✗ Some E2E tests failed"
    echo "========================================="
    exit $TEST_EXIT_CODE
fi

# Move back to root
cd ..