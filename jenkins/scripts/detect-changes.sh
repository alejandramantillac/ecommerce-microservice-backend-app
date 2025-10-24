#!/bin/bash
# Script to detect which services have changed

set -e

SERVICES="$1"
CHANGED_SERVICES=""

echo "Detecting changed services..."

IFS=',' read -ra SERVICE_ARRAY <<< "$SERVICES"
for service in "${SERVICE_ARRAY[@]}"; do
    # Extract service path from service definition
    service_path=$(echo "$service" | cut -d':' -f1)
    
    # Check if service directory or related files changed
    changes=$(git diff --name-only HEAD~1 HEAD | grep -E "^${service_path}/|^pom\.xml$|^shared/" || true)
    
    if [ -n "$changes" ]; then
        echo "Changes detected in ${service_path}:"
        echo "$changes"
        if [ -z "$CHANGED_SERVICES" ]; then
            CHANGED_SERVICES="${service_path}"
        else
            CHANGED_SERVICES="${CHANGED_SERVICES},${service_path}"
        fi
    fi
done

# If no specific changes detected, build all services
if [ -z "$CHANGED_SERVICES" ]; then
    echo "No specific changes detected, will build all services"
    CHANGED_SERVICES="$SERVICES"
fi

echo "Services to build: $CHANGED_SERVICES"
echo "$CHANGED_SERVICES"

