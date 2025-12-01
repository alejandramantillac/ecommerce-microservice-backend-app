#!/bin/bash
# Script to run OWASP ZAP security scan against API Gateway
# Usage: zap-security-scan.sh <namespace> <api-gateway-url> [report-dir]

set -e

NAMESPACE="${1:-prod}"
API_GATEWAY_URL="${2:-}"
REPORT_DIR="${3:-tests/zap-reports}"
ZAP_CONTAINER_NAME="zap-daemon-${NAMESPACE}"

echo "========================================="
echo "Running OWASP ZAP Security Scan"
echo "Namespace: ${NAMESPACE}"
echo "========================================="

# Get API Gateway URL if not provided
if [ -z "${API_GATEWAY_URL}" ]; then
    echo "Getting API Gateway LoadBalancer IP..."
    API_GATEWAY_IP=$(kubectl --kubeconfig="$KCFG" get svc api-gateway -n ${NAMESPACE} \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -z "${API_GATEWAY_IP}" ]; then
        echo "Warning: Could not get API Gateway IP from LoadBalancer"
        echo "Trying NodePort or ClusterIP..."
        API_GATEWAY_IP=$(kubectl --kubeconfig="$KCFG" get svc api-gateway -n ${NAMESPACE} \
            -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
        
        if [ -z "${API_GATEWAY_IP}" ]; then
            echo "Error: Could not determine API Gateway address"
            exit 1
        fi
    fi
    
    API_GATEWAY_URL="http://${API_GATEWAY_IP}:8080"
fi

echo "API Gateway URL: ${API_GATEWAY_URL}"

# Clean up any existing ZAP container
echo "Cleaning up any existing ZAP containers..."
docker stop ${ZAP_CONTAINER_NAME} 2>/dev/null || true
docker rm ${ZAP_CONTAINER_NAME} 2>/dev/null || true

# Start ZAP daemon in background
echo "Starting ZAP daemon..."
docker run -d --name ${ZAP_CONTAINER_NAME} \
    -p 8080:8080 \
    -i owasp/zap2docker-stable zap.sh -daemon -host 0.0.0.0 -port 8080 \
    -config api.disablekey=true \
    -config api.addrs.addr.name=.* \
    -config api.addrs.addr.regex=true || {
    echo "Error: Failed to start ZAP container"
    exit 1
}

# Wait for ZAP to be ready
echo "Waiting for ZAP to be ready..."
MAX_WAIT=60
WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if curl -s http://127.0.0.1:8080/JSON/core/view/version/ >/dev/null 2>&1; then
        echo "ZAP is ready"
        break
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    echo "Error: ZAP did not become ready in time"
    docker logs ${ZAP_CONTAINER_NAME}
    docker stop ${ZAP_CONTAINER_NAME} || true
    docker rm ${ZAP_CONTAINER_NAME} || true
    exit 1
fi

# Setup Python environment
echo "Setting up Python environment..."
cd tests
mkdir -p zap-reports

python3 -m pip install --break-system-packages -q -r requirements.txt 2>/dev/null || \
    python3 -m pip install -q -r requirements.txt

# Run ZAP tests
echo "Running ZAP security scan..."
export API_GATEWAY_URL="${API_GATEWAY_URL}"

python3 -m pytest security/test_zap_scan.py -v -m security \
    --html=zap-reports/zap-report.html \
    --self-contained-html \
    --json-report \
    --json-report-file=zap-reports/zap-report.json \
    --tb=short || TEST_EXIT_CODE=$?

# Generate ZAP HTML report using zap-cli
echo "Generating ZAP HTML report..."
docker exec ${ZAP_CONTAINER_NAME} zap-cli report -o /zap/report.html -f html 2>/dev/null || true
docker cp ${ZAP_CONTAINER_NAME}:/zap/report.html zap-reports/zap-full-report.html 2>/dev/null || true

# Generate JSON report
docker exec ${ZAP_CONTAINER_NAME} zap-cli report -o /zap/report.json -f json 2>/dev/null || true
docker cp ${ZAP_CONTAINER_NAME}:/zap/report.json zap-reports/zap-full-report.json 2>/dev/null || true

# Stop and remove ZAP container
echo "Stopping ZAP container..."
docker stop ${ZAP_CONTAINER_NAME} || true
docker rm ${ZAP_CONTAINER_NAME} || true

cd ..

# Set exit code
if [ -z "${TEST_EXIT_CODE:-}" ]; then
    TEST_EXIT_CODE=0
fi

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "========================================="
    echo "✓ ZAP security scan completed successfully"
    echo "========================================="
else
    echo "========================================="
    echo "⚠ ZAP scan found vulnerabilities (see reports)"
    echo "========================================="
fi

exit $TEST_EXIT_CODE

