#!/bin/bash
# Script to run specified integration tests using Python/Pytest

set -e

NAMESPACE="${1:-staging}"
API_GATEWAY_URL="${2:-http://api-gateway.staging.svc.cluster.local:8080}"
# TEST_FILES: comma-separated list of test files or modules to run, e.g. "integration/test_order_service.py,integration/test_another.py"
TEST_FILES="${3:-}"

echo "========================================="
echo "Running Integration Tests (Python/Pytest)"
echo "Namespace: ${NAMESPACE}"
echo "API Gateway: ${API_GATEWAY_URL}"
echo "Test Files: ${TEST_FILES}"
echo "========================================="

# Verify all services are running
echo ""
echo "Verifying services are running..."
kubectl --kubeconfig="$KCFG" get pods -n ${NAMESPACE} || true
kubectl --kubeconfig="$KCFG" get svc -n ${NAMESPACE} || true

echo ""
echo "Setting up Python environment..."
cd tests

python3 -m pip install --break-system-packages -q -r requirements.txt 2>/dev/null || \
    python3 -m pip install -q -r requirements.txt

echo ""
echo "Running integration tests..."
export API_GATEWAY_URL="${API_GATEWAY_URL}"

# Only run integration tests passed in TEST_FILES
if [[ -z "$TEST_FILES" ]]; then
    echo "ERROR: No test files specified in TEST_FILES. Skipping integration tests."
    exit 0
fi

# Convert comma-separated TEST_FILES to space-separated for pytest
IFS=',' read -ra files_array <<< "$TEST_FILES"
PYTEST_FILES="${files_array[@]}"

python3 -m pytest $PYTEST_FILES -v -m integration \
    --html=integration-report.html \
    --self-contained-html \
    --json-report \
    --json-report-file=integration-report.json \
    --cov=. \
    --cov-report=html:coverage-integration \
    --cov-report=xml:coverage-integration.xml \
    --cov-report=json:coverage-integration.json \
    --cov-report=term \
    --tb=short

TEST_EXIT_CODE=$?

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "========================================="
    echo "✓ All specified integration tests passed successfully!"
    echo "========================================="
else
    echo "========================================="
    echo "✗ Some specified integration tests failed"
    echo "========================================="
    exit $TEST_EXIT_CODE
fi

# Generate coverage summary
echo ""
echo "========================================="
echo "Coverage Summary (Integration Tests)"
echo "========================================="
if [ -f "coverage-integration.json" ]; then
    python3 << EOF
import json
import sys

try:
    with open('coverage-integration.json', 'r') as f:
        data = json.load(f)
    
    totals = data.get('totals', {})
    percent_covered = totals.get('percent_covered', 0)
    covered_lines = totals.get('covered_lines', 0)
    num_statements = totals.get('num_statements', 0)
    
    print(f"Coverage: {percent_covered:.2f}%")
    print(f"Covered Lines: {covered_lines}/{num_statements}")
    print(f"Coverage Report: coverage-integration/index.html")
    
    if percent_covered < 50:
        print("\n⚠ WARNING: Coverage is below 50%")
        sys.exit(0)
    else:
        print("\n✓ Coverage meets minimum threshold (50%)")
        sys.exit(0)
except Exception as e:
    print(f"Error reading coverage report: {e}")
    sys.exit(0)
EOF
fi

# Move reports to repo root so Jenkins can archive them
if [ -d "coverage-integration" ]; then
    cp -r coverage-integration .. 2>/dev/null || true
fi
if [ -f "coverage-integration.xml" ]; then
    cp coverage-integration.xml .. 2>/dev/null || true
fi
if [ -f "coverage-integration.json" ]; then
    cp coverage-integration.json .. 2>/dev/null || true
fi

# Move back to root
cd ..