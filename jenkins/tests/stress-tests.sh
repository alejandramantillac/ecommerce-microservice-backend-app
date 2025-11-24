#!/bin/bash
# Script to run stress tests with Locust (extreme load)

set -e

NAMESPACE="${1:-staging}"
API_GATEWAY_URL="${2:-http://api-gateway.staging.svc.cluster.local:8080}"
USERS="${3:-500}"
SPAWN_RATE="${4:-50}"
RUN_TIME="${5:-300s}"

echo "========================================="
echo "Running STRESS Tests with Locust"
echo "Namespace: ${NAMESPACE}"
echo "API Gateway: ${API_GATEWAY_URL}"
echo "Users: ${USERS} (extreme load)"
echo "Spawn Rate: ${SPAWN_RATE} users/second"
echo "Run Time: ${RUN_TIME}"
echo "========================================="

echo ""
echo "⚠️  WARNING: This test applies extreme load to find breaking points"
echo ""

echo "Setting up Python environment..."
cd tests

python3 -m pip install --break-system-packages -q -r requirements.txt 2>/dev/null || \
    python3 -m pip install -q -r requirements.txt

# Run Locust stress tests
echo ""
echo "Starting Locust stress tests..."

set +e
python3 -m locust -f performance/locustfile_stress.py \
    --host=${API_GATEWAY_URL} \
    --users=${USERS} \
    --spawn-rate=${SPAWN_RATE} \
    --run-time=${RUN_TIME} \
    --html=stress-report.html \
    --csv=stress-data \
    --headless

TEST_EXIT_CODE=$?

# Generate stress test summary
echo ""
echo "========================================="
echo "Stress Test Summary"
echo "========================================="
if [ -f stress-data_stats.csv ]; then
    echo "Total Requests: $(tail -n 1 stress-data_stats.csv | cut -d',' -f2)"
    echo "Failed Requests: $(tail -n 1 stress-data_stats.csv | cut -d',' -f3)"
    echo "Average Response Time: $(tail -n 1 stress-data_stats.csv | cut -d',' -f4)ms"
    echo "Requests per Second: $(tail -n 1 stress-data_stats.csv | cut -d',' -f5)"
    echo ""
    echo "Full report available in: stress-report.html"
fi
echo "========================================="

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✓ Stress tests completed successfully"
fi

# Move artifacts to repo root so Jenkins can archive them
if [ -f stress-report.html ]; then
    mv stress-report.html ..
fi
if ls stress-data* &>/dev/null; then
    mv stress-data* ..
fi

# Move back to root
cd ..

exit $TEST_EXIT_CODE

