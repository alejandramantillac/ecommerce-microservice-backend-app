#!/usr/bin/env bash
set -euo pipefail

TFVARS_FILE="${1:-}"

if [[ -z "${TFVARS_FILE}" ]]; then
  echo "Usage: $0 <tfvars-file>" >&2
  exit 1
fi

if [[ -z "${ARM_SUBSCRIPTION_ID:-}" ]]; then
  echo "ARM_SUBSCRIPTION_ID must be set in the environment" >&2
  exit 1
fi

if ! command -v python >/dev/null 2>&1; then
  echo "python command is required to import NSG associations." >&2
  exit 1
fi

# Evaluate a Terraform expression and return the last line of output.
tf_eval() {
  local expr="$1"
  terraform console -var-file="$TFVARS_FILE" <<EOF | tail -n1
$expr
EOF
}

parse_json_list() {
  python -c 'import json, sys; data=json.load(sys.stdin); print(" ".join(str(item) for item in data))'
}

NAME_PREFIX=$(tf_eval 'jsonencode(local.name_prefix)' | tr -d '"')
RESOURCE_GROUP="${NAME_PREFIX}-rg"
VNET_NAME="${NAME_PREFIX}-vnet"
PUBLIC_NSG="${NAME_PREFIX}-public-nsg"
PRIVATE_NSG="${NAME_PREFIX}-private-nsg"

PUBLIC_KEYS=$(tf_eval 'jsonencode(keys(var.public_subnets))' | parse_json_list)
PRIVATE_KEYS=$(tf_eval 'jsonencode(keys(var.private_subnets))' | parse_json_list || true)

ensure_import() {
  local kind="$1"
  local key="$2"
  local suffix
  local nsg_name
  if [[ "$kind" == "public" ]]; then
    suffix="public"
    nsg_name="$PUBLIC_NSG"
  else
    suffix="private"
    nsg_name="$PRIVATE_NSG"
  fi
  local subnet_name="${NAME_PREFIX}-${key}-${suffix}"
  local subnet_id="/subscriptions/${ARM_SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${subnet_name}"
  local nsg_id="/subscriptions/${ARM_SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Network/networkSecurityGroups/${nsg_name}"
  local tf_address="module.networking.azurerm_subnet_network_security_group_association.${kind}[\"${key}\"]"

  if terraform state list | grep -F -- "$tf_address" >/dev/null 2>&1; then
    echo "[NSG Import] ${tf_address} already managed."
    return
  fi

  echo "[NSG Import] Importing ${tf_address}"
  terraform import "$tf_address" "${subnet_id}|${nsg_id}" >/dev/null
}

for key in $PUBLIC_KEYS; do
  ensure_import "public" "$key"
done

for key in $PRIVATE_KEYS; do
  [[ -z "$key" ]] && continue
  ensure_import "private" "$key"
done

