#!/bin/bash
# Script to run spike tests with Locust (sudden traffic surge)

set -e

NAMESPACE="${1:-staging}"
API_GATEWAY_URL="${2:-http://api-gateway.staging.svc.cluster.local:8080}"
USERS="${3:-200}"
SPAWN_RATE="${4:-100}"
RUN_TIME="${5:-120s}"

echo "========================================="
echo "Running SPIKE Tests with Locust"
echo "Namespace: ${NAMESPACE}"
echo "API Gateway: ${API_GATEWAY_URL}"
echo "Users: ${USERS} (sudden surge)"
echo "Spawn Rate: ${SPAWN_RATE} users/second (very high)"
echo "Run Time: ${RUN_TIME}"
echo "========================================="

echo ""
echo "⚠️  WARNING: This test simulates sudden traffic spikes"
echo "   Monitor system recovery and resilience"
echo ""

echo "Setting up Python environment..."
cd tests

python3 -m pip install --break-system-packages -q -r requirements.txt 2>/dev/null || \
    python3 -m pip install -q -r requirements.txt

# Run Locust spike tests
echo ""
echo "Starting Locust spike tests..."

set +e
python3 -m locust -f performance/locustfile_spike.py \
    --host=${API_GATEWAY_URL} \
    --users=${USERS} \
    --spawn-rate=${SPAWN_RATE} \
    --run-time=${RUN_TIME} \
    --html=spike-report.html \
    --csv=spike-data \
    --headless

TEST_EXIT_CODE=$?

# Generate spike test summary
echo ""
echo "========================================="
echo "Spike Test Summary"
echo "========================================="
if [ -f spike-data_stats.csv ]; then
    echo "Total Requests: $(tail -n 1 spike-data_stats.csv | cut -d',' -f2)"
    echo "Failed Requests: $(tail -n 1 spike-data_stats.csv | cut -d',' -f3)"
    echo "Average Response Time: $(tail -n 1 spike-data_stats.csv | cut -d',' -f4)ms"
    echo "Requests per Second: $(tail -n 1 spike-data_stats.csv | cut -d',' -f5)"
    echo ""
    echo "Full report available in: spike-report.html"
fi
echo "========================================="

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✓ Spike tests completed successfully"
fi

# Move artifacts to repo root so Jenkins can archive them
if [ -f spike-report.html ]; then
    mv spike-report.html ..
fi
if ls spike-data* &>/dev/null; then
    mv spike-data* ..
fi

# Move back to root
cd ..

exit $TEST_EXIT_CODE

