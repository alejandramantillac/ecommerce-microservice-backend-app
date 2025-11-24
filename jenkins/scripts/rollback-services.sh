#!/usr/bin/env bash
# Roll back one or more Kubernetes deployments using rollout undo.
# Usage:
#   rollback-services.sh --kubeconfig <path> --namespace <ns> --services "svc1,svc2"

set -euo pipefail

KUBECONFIG_PATH=""
NAMESPACE=""
SERVICES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kubeconfig)
            KUBECONFIG_PATH="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --services)
            SERVICES="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$KUBECONFIG_PATH" || -z "$NAMESPACE" || -z "$SERVICES" ]]; then
    echo "Usage: $0 --kubeconfig <path> --namespace <ns> --services \"svc1,svc2\"" >&2
    exit 1
fi

IFS=',' read -r -a SERVICE_ARRAY <<< "$SERVICES"

echo "========================================="
echo "Rolling back services in namespace: ${NAMESPACE}"
echo "Kubeconfig: ${KUBECONFIG_PATH}"
echo "Targets: ${SERVICES}"
echo "========================================="

for svc in "${SERVICE_ARRAY[@]}"; do
    svc="$(echo "$svc" | xargs)"
    [[ -z "$svc" ]] && continue

    echo "↩️  Rolling back deployment/${svc}..."
    if kubectl --kubeconfig="${KUBECONFIG_PATH}" -n "${NAMESPACE}" rollout undo deployment/"${svc}"; then
        kubectl --kubeconfig="${KUBECONFIG_PATH}" -n "${NAMESPACE}" rollout status deployment/"${svc}" --timeout=120s
        echo "✓ ${svc} successfully rolled back."
    else
        echo "⚠️  Failed to rollback ${svc}. Check kubectl output above." >&2
    fi
done

echo "Rollback routine finished."

