#!/bin/bash
# Script to run specified end-to-end tests using Python/Pytest

set -e

NAMESPACE="${1:-staging}"
API_GATEWAY_URL="${2:-http://api-gateway.staging.svc.cluster.local:8080}"
# TEST_FILES: comma-separated list of test files or modules to run, e.g. "e2e/test_user_flow.py,e2e/test_another.py"
TEST_FILES="${3:-}"

echo "========================================="
echo "Running End-to-End Tests (Python/Pytest)"
echo "Namespace: ${NAMESPACE}"
echo "API Gateway: ${API_GATEWAY_URL}"
echo "Test Files: ${TEST_FILES}"
echo "========================================="

echo ""
echo "Setting up Python environment..."
cd tests

python3 -m pip install --break-system-packages -q -r requirements.txt 2>/dev/null || \
    python3 -m pip install -q -r requirements.txt

echo ""
echo "Running E2E tests..."
export API_GATEWAY_URL="${API_GATEWAY_URL}"

# Only run E2E tests passed in TEST_FILES
if [[ -z "$TEST_FILES" ]]; then
    echo "WARNING: No test files specified in TEST_FILES. Running all E2E tests."
    PYTEST_FILES="e2e/"
else
    # Convert comma-separated TEST_FILES to space-separated for pytest
    IFS=',' read -ra files_array <<< "$TEST_FILES"
    PYTEST_FILES="${files_array[@]}"
fi

python3 -m pytest $PYTEST_FILES -v -m e2e \
    --html=e2e-report.html \
    --self-contained-html \
    --json-report \
    --json-report-file=e2e-report.json \
    --cov=. \
    --cov-report=html:coverage-e2e \
    --cov-report=xml:coverage-e2e.xml \
    --cov-report=json:coverage-e2e.json \
    --cov-report=term \
    --tb=short

TEST_EXIT_CODE=$?

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

# Generate coverage summary
echo ""
echo "========================================="
echo "Coverage Summary (E2E Tests)"
echo "========================================="
if [ -f "coverage-e2e.json" ]; then
    python3 << EOF
import json
import sys

try:
    with open('coverage-e2e.json', 'r') as f:
        data = json.load(f)
    
    totals = data.get('totals', {})
    percent_covered = totals.get('percent_covered', 0)
    covered_lines = totals.get('covered_lines', 0)
    num_statements = totals.get('num_statements', 0)
    
    print(f"Coverage: {percent_covered:.2f}%")
    print(f"Covered Lines: {covered_lines}/{num_statements}")
    print(f"Coverage Report: coverage-e2e/index.html")
    
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
if [ -d "coverage-e2e" ]; then
    cp -r coverage-e2e .. 2>/dev/null || true
fi
if [ -f "coverage-e2e.xml" ]; then
    cp coverage-e2e.xml .. 2>/dev/null || true
fi
if [ -f "coverage-e2e.json" ]; then
    cp coverage-e2e.json .. 2>/dev/null || true
fi

# Move back to root
cd ..