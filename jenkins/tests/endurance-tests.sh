#!/bin/bash
# Script to run endurance tests with Locust (sustained load)

set -e

NAMESPACE="${1:-staging}"
API_GATEWAY_URL="${2:-http://api-gateway.staging.svc.cluster.local:8080}"
USERS="${3:-100}"
SPAWN_RATE="${4:-10}"
RUN_TIME="${5:-1800s}"

echo "========================================="
echo "Running ENDURANCE Tests with Locust"
echo "Namespace: ${NAMESPACE}"
echo "API Gateway: ${API_GATEWAY_URL}"
echo "Users: ${USERS} (sustained load)"
echo "Spawn Rate: ${SPAWN_RATE} users/second"
echo "Run Time: ${RUN_TIME} (30 minutes default)"
echo "========================================="

echo ""
echo "ℹ️  INFO: This test runs for extended periods to detect"
echo "   memory leaks and performance degradation over time"
echo ""

echo "Setting up Python environment..."
cd tests

python3 -m pip install --break-system-packages -q -r requirements.txt 2>/dev/null || \
    python3 -m pip install -q -r requirements.txt

# Run Locust endurance tests
echo ""
echo "Starting Locust endurance tests..."

set +e
python3 -m locust -f performance/locustfile_endurance.py \
    --host=${API_GATEWAY_URL} \
    --users=${USERS} \
    --spawn-rate=${SPAWN_RATE} \
    --run-time=${RUN_TIME} \
    --html=endurance-report.html \
    --csv=endurance-data \
    --headless

TEST_EXIT_CODE=$?

# Generate endurance test summary
echo ""
echo "========================================="
echo "Endurance Test Summary"
echo "========================================="
if [ -f endurance-data_stats.csv ]; then
    echo "Total Requests: $(tail -n 1 endurance-data_stats.csv | cut -d',' -f2)"
    echo "Failed Requests: $(tail -n 1 endurance-data_stats.csv | cut -d',' -f3)"
    echo "Average Response Time: $(tail -n 1 endurance-data_stats.csv | cut -d',' -f4)ms"
    echo "Requests per Second: $(tail -n 1 endurance-data_stats.csv | cut -d',' -f5)"
    echo ""
    echo "Full report available in: endurance-report.html"
    echo ""
    echo "Review results for:"
    echo "  - Memory leaks (check memory usage over time)"
    echo "  - Performance degradation (response times should remain stable)"
    echo "  - Resource exhaustion (CPU, memory, connections)"
fi
echo "========================================="

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✓ Endurance tests completed successfully"
fi

# Move artifacts to repo root so Jenkins can archive them
if [ -f endurance-report.html ]; then
    mv endurance-report.html ..
fi
if ls endurance-data* &>/dev/null; then
    mv endurance-data* ..
fi

# Move back to root
cd ..

exit $TEST_EXIT_CODE

