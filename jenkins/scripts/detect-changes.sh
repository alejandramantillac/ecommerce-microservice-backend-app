#!/bin/bash
# Script to detect which services have changed

set -e

SERVICES="$1"
CHANGED_SERVICES=""

echo "Detecting changed services..." >&2

IFS=',' read -ra SERVICE_ARRAY <<< "$SERVICES"
for service in "${SERVICE_ARRAY[@]}"; do
    # Extract service path from service definition
    service_path=$(echo "$service" | cut -d':' -f1)
    
    if [ "$service_path" = "zipkin" ]; then
        # Zipkin only changes if its k8s config changes
        changes=$(git diff --name-only HEAD~1 HEAD | grep -E "^k8s/zipkin.yaml" || true)
    else
        # Regular services: check code changes
        changes=$(git diff --name-only HEAD~1 HEAD | grep -E "^${service_path}/|^pom\.xml$|^shared/" || true)
    fi
    
    if [ -n "$changes" ]; then
        echo "Changes detected in ${service_path}:" >&2
        echo "$changes" >&2
        if [ -z "$CHANGED_SERVICES" ]; then
            CHANGED_SERVICES="${service_path}"
        else
            CHANGED_SERVICES="${CHANGED_SERVICES},${service_path}"
        fi
    fi
done

# If no specific changes detected, build all services
if [ -z "$CHANGED_SERVICES" ]; then
    echo "No specific changes detected, will build all services" >&2
    CHANGED_SERVICES="$SERVICES"
fi

echo "Services to build: $CHANGED_SERVICES" >&2

# Output only the result to stdout (this is what Jenkins captures)
echo "$CHANGED_SERVICES"

