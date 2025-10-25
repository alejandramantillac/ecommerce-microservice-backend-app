#!/bin/bash
# Script to run performance tests with Locust

set -e

NAMESPACE="${1:-staging}"
API_GATEWAY_URL="${2:-http://api-gateway.staging.svc.cluster.local:8080}"
USERS="${3:-50}"
SPAWN_RATE="${4:-10}"
RUN_TIME="${5:-60s}"

echo "========================================="
echo "Running Performance Tests with Locust"
echo "Namespace: ${NAMESPACE}"
echo "API Gateway: ${API_GATEWAY_URL}"
echo "Users: ${USERS}"
echo "Spawn Rate: ${SPAWN_RATE}"
echo "Run Time: ${RUN_TIME}"
echo "========================================="

echo ""
echo "Setting up Python environment..."
cd tests

python3 -m pip install --break-system-packages -q -r requirements.txt 2>/dev/null || \
    python3 -m pip install -q -r requirements.txt

# Run Locust performance tests
echo ""
echo "Starting Locust performance tests..."

set +e
python3 -m locust -f performance/locustfile.py \
    --host=${API_GATEWAY_URL} \
    --users=${USERS} \
    --spawn-rate=${SPAWN_RATE} \
    --run-time=${RUN_TIME} \
    --html=performance-report.html \
    --csv=performance-data \
    --headless

TEST_EXIT_CODE=$?

# Generate performance summary
echo ""
echo "========================================="
echo "Performance Test Summary"
echo "========================================="
if [ -f performance-data_stats.csv ]; then
    echo "Total Requests: $(tail -n 1 performance-data_stats.csv | cut -d',' -f2)"
    echo "Failed Requests: $(tail -n 1 performance-data_stats.csv | cut -d',' -f3)"
    echo "Average Response Time: $(tail -n 1 performance-data_stats.csv | cut -d',' -f4)ms"
    echo "Requests per Second: $(tail -n 1 performance-data_stats.csv | cut -d',' -f5)"
    echo ""
    echo "Full report available in: performance-report.html"
fi
echo "========================================="

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✓ Performance tests completed successfully"
fi

# Move back to root
cd ..