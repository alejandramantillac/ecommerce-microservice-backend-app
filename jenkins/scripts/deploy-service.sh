#!/bin/bash
# jenkins/scripts/deploy-service.sh
# Script to deploy a single service to Kubernetes

set -e

SERVICE_NAME="$1"
NAMESPACE="$2"
REGISTRY="$3"
IMAGE_TAG="$4"
ENVIRONMENT="$5"  # dev, staging, prod
SERVICE_CONFIG="$6"  # JSON string con la configuración del servicio

if [ -z "$SERVICE_NAME" ] || [ -z "$NAMESPACE" ] || [ -z "$REGISTRY" ] || [ -z "$IMAGE_TAG" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <service-name> <namespace> <registry> <image-tag> <environment> <service-config-json>"
    exit 1
fi

echo "========================================="
echo "Deploying ${SERVICE_NAME}"
echo "Namespace: ${NAMESPACE}"
echo "Environment: ${ENVIRONMENT}"
echo "Image: ${REGISTRY}/${SERVICE_NAME}:${IMAGE_TAG}"
echo "========================================="

# Parse service config from JSON
SERVICE_PORT=$(echo "$SERVICE_CONFIG" | jq -r '.port')
MEMORY_REQUEST=$(echo "$SERVICE_CONFIG" | jq -r '.resources.memRequest')
MEMORY_LIMIT=$(echo "$SERVICE_CONFIG" | jq -r '.resources.memLimit')
CPU_REQUEST=$(echo "$SERVICE_CONFIG" | jq -r '.resources.cpuRequest')
CPU_LIMIT=$(echo "$SERVICE_CONFIG" | jq -r '.resources.cpuLimit')
HEALTH_PATH=$(echo "$SERVICE_CONFIG" | jq -r '.healthPath')
REPLICAS=$(echo "$SERVICE_CONFIG" | jq -r ".replicas.${ENVIRONMENT}")

# Extract exposure configuration for the current environment
SERVICE_TYPE=$(echo "$SERVICE_CONFIG" | jq -r ".exposure.${ENVIRONMENT}.type // \"ClusterIP\"")
NODE_PORT=$(echo "$SERVICE_CONFIG" | jq -r ".exposure.${ENVIRONMENT}.nodePort // empty")
EXTERNAL_PORT=$(echo "$SERVICE_CONFIG" | jq -r ".exposure.${ENVIRONMENT}.externalPort // empty")

# For LoadBalancer, use external port if specified
if [ "$SERVICE_TYPE" = "LoadBalancer" ] && [ -n "$EXTERNAL_PORT" ] && [ "$EXTERNAL_PORT" != "null" ]; then
    echo "LoadBalancer will expose port ${EXTERNAL_PORT} (maps to ${SERVICE_PORT})"
fi

echo "Configuration:"
echo "  Port: ${SERVICE_PORT}"
echo "  Type: ${SERVICE_TYPE}"
echo "  Replicas: ${REPLICAS}"
echo "  Resources: ${MEMORY_REQUEST}/${MEMORY_LIMIT} (mem), ${CPU_REQUEST}/${CPU_LIMIT} (cpu)"
if [ -n "$NODE_PORT" ] && [ "$NODE_PORT" != "null" ]; then
    echo "  NodePort: ${NODE_PORT}"
fi
if [ -n "$EXTERNAL_PORT" ] && [ "$EXTERNAL_PORT" != "null" ]; then
    echo "  External Port: ${EXTERNAL_PORT}"
fi
echo ""

# Apply Kubernetes manifests using the generic template
export SERVICE_NAME NAMESPACE REGISTRY IMAGE_TAG SERVICE_PORT SERVICE_TYPE NODE_PORT
export MEMORY_REQUEST MEMORY_LIMIT CPU_REQUEST CPU_LIMIT REPLICAS HEALTH_PATH

if [ -f "k8s/${SERVICE_NAME}.yaml" ]; then
    echo "Using specific configuration: k8s/${SERVICE_NAME}.yaml"

    # Apply with variable substitution
    sed -e "s|\${SERVICE_NAME}|${SERVICE_NAME}|g" \
        -e "s|\${NAMESPACE}|${NAMESPACE}|g" \
        -e "s|\${NODE_PORT}|${NODE_PORT}|g" \
        "k8s/${SERVICE_NAME}.yaml" | kubectl --kubeconfig="$KCFG" apply -f -

else
    echo "Using generic template: k8s/service-template.yaml"

    # Build the manifest
    if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
        # LoadBalancer service
        sed -e "s|\${SERVICE_NAME}|${SERVICE_NAME}|g" \
            -e "s|\${NAMESPACE}|${NAMESPACE}|g" \
            -e "s|\${REGISTRY}|${REGISTRY}|g" \
            -e "s|\${IMAGE_TAG}|${IMAGE_TAG}|g" \
            -e "s|\${SERVICE_PORT}|${SERVICE_PORT}|g" \
            -e "s|\${SERVICE_TYPE}|LoadBalancer|g" \
            -e "s|\${MEMORY_REQUEST}|${MEMORY_REQUEST}|g" \
            -e "s|\${MEMORY_LIMIT}|${MEMORY_LIMIT}|g" \
            -e "s|\${CPU_REQUEST}|${CPU_REQUEST}|g" \
            -e "s|\${CPU_LIMIT}|${CPU_LIMIT}|g" \
            -e "s|\${REPLICAS}|${REPLICAS}|g" \
            -e "s|\${HEALTH_PATH}|${HEALTH_PATH}|g" \
            -e "/\${NODE_PORT:+nodePort: \${NODE_PORT}}/d" \
            "k8s/service-template.yaml" | kubectl --kubeconfig="$KCFG" apply -f -

    elif [ "$SERVICE_TYPE" = "NodePort" ] && [ -n "$NODE_PORT" ] && [ "$NODE_PORT" != "null" ]; then
        # NodePort service
        sed -e "s|\${SERVICE_NAME}|${SERVICE_NAME}|g" \
            -e "s|\${NAMESPACE}|${NAMESPACE}|g" \
            -e "s|\${REGISTRY}|${REGISTRY}|g" \
            -e "s|\${IMAGE_TAG}|${IMAGE_TAG}|g" \
            -e "s|\${SERVICE_PORT}|${SERVICE_PORT}|g" \
            -e "s|\${SERVICE_TYPE}|NodePort|g" \
            -e "s|\${MEMORY_REQUEST}|${MEMORY_REQUEST}|g" \
            -e "s|\${MEMORY_LIMIT}|${MEMORY_LIMIT}|g" \
            -e "s|\${CPU_REQUEST}|${CPU_REQUEST}|g" \
            -e "s|\${CPU_LIMIT}|${CPU_LIMIT}|g" \
            -e "s|\${REPLICAS}|${REPLICAS}|g" \
            -e "s|\${HEALTH_PATH}|${HEALTH_PATH}|g" \
            -e "s|    \${NODE_PORT:+nodePort: \${NODE_PORT}}|    nodePort: ${NODE_PORT}|g" \
            "k8s/service-template.yaml" | kubectl --kubeconfig="$KCFG" apply -f -

    else
        # ClusterIP service (default)
        sed -e "s|\${SERVICE_NAME}|${SERVICE_NAME}|g" \
            -e "s|\${NAMESPACE}|${NAMESPACE}|g" \
            -e "s|\${REGISTRY}|${REGISTRY}|g" \
            -e "s|\${IMAGE_TAG}|${IMAGE_TAG}|g" \
            -e "s|\${SERVICE_PORT}|${SERVICE_PORT}|g" \
            -e "s|\${SERVICE_TYPE}|ClusterIP|g" \
            -e "s|\${MEMORY_REQUEST}|${MEMORY_REQUEST}|g" \
            -e "s|\${MEMORY_LIMIT}|${MEMORY_LIMIT}|g" \
            -e "s|\${CPU_REQUEST}|${CPU_REQUEST}|g" \
            -e "s|\${CPU_LIMIT}|${CPU_LIMIT}|g" \
            -e "s|\${REPLICAS}|${REPLICAS}|g" \
            -e "s|\${HEALTH_PATH}|${HEALTH_PATH}|g" \
            -e "/\${NODE_PORT:+nodePort: \${NODE_PORT}}/d" \
            "k8s/service-template.yaml" | kubectl --kubeconfig="$KCFG" apply -f -
    fi
fi

# Wait for the service to be ready
echo "Waiting for ${SERVICE_NAME} to be ready..."
kubectl --kubeconfig="$KCFG" rollout status deployment/${SERVICE_NAME} -n ${NAMESPACE} --timeout=600s

echo "✓ Successfully deployed ${SERVICE_NAME} to ${NAMESPACE}"
echo ""

