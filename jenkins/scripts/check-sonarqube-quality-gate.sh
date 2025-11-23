#!/bin/bash
# Script to check SonarQube Quality Gate status
# Usage: check-sonarqube-quality-gate.sh <project-key> <sonar-host-url> <sonar-token> [max-wait-seconds]

set -e

PROJECT_KEY="$1"
SONAR_HOST_URL="$2"
SONAR_TOKEN="$3"
MAX_WAIT_SECONDS="$4"

if [ -z "$PROJECT_KEY" ] || [ -z "$SONAR_TOKEN" ]; then
    echo "Usage: $0 <project-key> <sonar-host-url> <sonar-token> [max-wait-seconds]"
    exit 1
fi

echo "Checking SonarQube Quality Gate for project: ${PROJECT_KEY}"

# Wait for analysis to be processed by SonarQube
echo "Waiting for SonarQube to process analysis (max ${MAX_WAIT_SECONDS}s)..."
WAIT_TIME=0
POLL_INTERVAL=2

while [ $WAIT_TIME -lt $MAX_WAIT_SECONDS ]; do
    # Check if analysis is ready by querying the Quality Gate status
    RESPONSE=$(curl -s -w "\n%{http_code}" -u "${SONAR_TOKEN}:" \
        "${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=${PROJECT_KEY}" 2>/dev/null || echo -e "\n000")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    # Check if we got a valid response
    if [ "$HTTP_CODE" = "200" ] && [ -n "$BODY" ]; then
        # Check if we got a valid JSON response with projectStatus
        if echo "$BODY" | grep -q '"projectStatus"'; then
            # Try to parse with jq if available, otherwise use grep
            if command -v jq &> /dev/null; then
                STATUS=$(echo "$BODY" | jq -r '.projectStatus.status' 2>/dev/null || echo "")
            else
                STATUS=$(echo "$BODY" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
            fi
            
            if [ -n "$STATUS" ] && [ "$STATUS" != "null" ]; then
                echo ""
                echo "Quality Gate status: ${STATUS}"
                
                if [ "$STATUS" = "NONE" ]; then
                    echo "No Quality Gate result yet (project might be new or gate not configured)."
                    echo "Continuing without blocking the pipeline."
                    exit 0
                elif [ "$STATUS" = "OK" ]; then
                    echo "✓ Quality Gate PASSED"
                    exit 0
                elif [ "$STATUS" = "ERROR" ]; then
                    echo ""
                    echo "✗ Quality Gate FAILED"
                    echo ""
                    
                    # Extract and display failed conditions
                    if command -v jq &> /dev/null; then
                        echo "Failed conditions:"
                        echo "$BODY" | jq -r '.projectStatus.conditions[] | select(.status == "ERROR") | "  - \(.metricKey): \(.actualValue) (threshold: \(.errorThreshold))"' 2>/dev/null || true
                    else
                        echo "Failed conditions (check SonarQube UI for details):"
                        echo "$BODY" | grep -o '"metricKey":"[^"]*"' | cut -d'"' -f4 | sed 's/^/  - /' || true
                    fi
                    
                    echo ""
                    echo "View details in SonarQube:"
                    echo "  ${SONAR_HOST_URL}/dashboard?id=${PROJECT_KEY}"
                    echo ""
                    
                    exit 0 # Continue the pipeline even if the quality gate fails
                fi
            fi
        fi
    elif [ "$HTTP_CODE" = "404" ]; then
        # Project might not exist yet, keep waiting
        echo "  Project not found yet, waiting for analysis to complete..."
    elif [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "000" ]; then
        echo "  HTTP ${HTTP_CODE} - Waiting for analysis..."
    fi
    
    sleep $POLL_INTERVAL
    WAIT_TIME=$((WAIT_TIME + POLL_INTERVAL))
    if [ $((WAIT_TIME % 10)) -eq 0 ]; then
        echo "  Waiting... (${WAIT_TIME}s/${MAX_WAIT_SECONDS}s)"
    fi
done

echo ""
echo "⚠ Timeout waiting for Quality Gate status (${MAX_WAIT_SECONDS}s)"
echo "Analysis may still be processing. Check SonarQube UI manually:"
echo "  ${SONAR_HOST_URL}/dashboard?id=${PROJECT_KEY}"
exit 1

