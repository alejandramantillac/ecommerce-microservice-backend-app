#!/bin/bash
# Script to run integration tests using Python/Pytest

set -e

NAMESPACE="${1:-staging}"
API_GATEWAY_URL="${2:-http://api-gateway.staging.svc.cluster.local:8080}"

echo "========================================="
echo "Running Integration Tests (Python/Pytest)"
echo "Namespace: ${NAMESPACE}"
echo "API Gateway: ${API_GATEWAY_URL}"
echo "========================================="

# Verify all services are running
echo ""
echo "Verifying services are running..."
kubectl --kubeconfig="$KCFG" get pods -n ${NAMESPACE} || true
kubectl --kubeconfig="$KCFG" get svc -n ${NAMESPACE} || true

echo ""
echo "Setting up Python environment..."
cd tests

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment and install dependencies
echo "Installing test dependencies in virtual environment..."
source venv/bin/activate
pip install -q -r requirements.txt

echo ""
echo "Running integration tests..."
export API_GATEWAY_URL="${API_GATEWAY_URL}"

# Run pytest with integration tests
pytest integration/ -v -m integration \
    --html=integration-report.html \
    --self-contained-html \
    --json-report \
    --json-report-file=integration-report.json \
    --tb=short

TEST_EXIT_CODE=$?

# Deactivate virtual environment
deactivate

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "========================================="
    echo "✓ All integration tests passed successfully!"
    echo "========================================="
else
    echo "========================================="
    echo "✗ Some integration tests failed"
    echo "========================================="
    exit $TEST_EXIT_CODE
fi

# Move back to root
cd ..