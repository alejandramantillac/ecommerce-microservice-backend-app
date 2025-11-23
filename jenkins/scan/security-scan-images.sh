#!/bin/bash
# Script to perform scheduled Trivy scans over a list of container images
# Usage: security-scan-images.sh <image-list-file> <report-dir> <summary-csv> <summary-json> [severity]

set -euo pipefail

IMAGE_LIST_FILE="${1:-}"
REPORT_DIR="${2:-security-reports}"
SUMMARY_CSV="${3:-${REPORT_DIR}/summary.csv}"
SUMMARY_JSON="${4:-${REPORT_DIR}/summary.json}"
TRIVY_SEVERITY="${5:-CRITICAL,HIGH,MEDIUM,LOW}"

if [[ -z "$IMAGE_LIST_FILE" || ! -f "$IMAGE_LIST_FILE" ]]; then
    echo "Image list file not found: ${IMAGE_LIST_FILE}" >&2
    exit 1
fi

mkdir -p "${REPORT_DIR}"
REPORT_DIR_ABS="$(cd "${REPORT_DIR}" && pwd)"
echo "service,image,critical,high,medium,low,unknown" > "${SUMMARY_CSV}"

run_trivy() {
    local image="$1"
    local output="$2"
    local filename
    filename="$(basename "${output}")"
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "${REPORT_DIR_ABS}:/reports" \
        aquasec/trivy:latest image \
        --severity "${TRIVY_SEVERITY}" \
        --format json \
        --output "/reports/${filename}" \
        --exit-code 0 \
        "${image}" >/dev/null
}

while IFS= read -r image || [[ -n "$image" ]]; do
    image="$(echo "$image" | xargs)"
    if [[ -z "$image" ]]; then
        continue
    fi

    service="$(echo "$image" | awk -F'/' '{print $NF}' | cut -d':' -f1)"
    safe_name="$(echo "$image" | sed 's|[/:]|-|g')"
    report_path="${REPORT_DIR}/${safe_name}.json"

    echo "Scanning image: ${image}"
    set +e
    run_trivy "${image}" "${report_path}"
    scan_status=$?
    set -e

    if [[ $scan_status -ne 0 ]]; then
        echo "Warning: Trivy exited with status ${scan_status} for ${image}" >&2
    fi

    read -r critical high medium low unknown <<EOF
$(python3 - <<'PY' "${report_path}"
import json, sys
from collections import Counter
path = sys.argv[1]
counts = Counter()
try:
    with open(path) as fh:
        data = json.load(fh)
    for result in data.get("Results", []):
        for vuln in result.get("Vulnerabilities") or []:
            severity = (vuln.get("Severity") or "UNKNOWN").upper()
            counts[severity] += 1
except FileNotFoundError:
    pass

print(
    counts.get("CRITICAL", 0),
    counts.get("HIGH", 0),
    counts.get("MEDIUM", 0),
    counts.get("LOW", 0),
    counts.get("UNKNOWN", 0),
)
PY
)
EOF

    echo "${service},${image},${critical},${high},${medium},${low},${unknown}" >> "${SUMMARY_CSV}"
done < "${IMAGE_LIST_FILE}"

python3 - <<'PY' "${SUMMARY_CSV}" "${SUMMARY_JSON}"
import csv
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone

csv_path, json_path = sys.argv[1], sys.argv[2]
totals = defaultdict(int)
services = {}

with open(csv_path) as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        service = row["service"] or "unknown"
        image = row["image"]
        stats = {
            "critical": int(row["critical"] or 0),
            "high": int(row["high"] or 0),
            "medium": int(row["medium"] or 0),
            "low": int(row["low"] or 0),
            "unknown": int(row["unknown"] or 0),
        }

        if service not in services:
            services[service] = {
                "critical": 0,
                "high": 0,
                "medium": 0,
                "low": 0,
                "unknown": 0,
                "images": []
            }

        for key, value in stats.items():
            services[service][key] += value
            totals[key] += value

        services[service]["images"].append({"image": image, **stats})

report = {
    "generatedAt": datetime.now(timezone.utc).isoformat(),
    "totals": totals,
    "services": services
}

with open(json_path, "w") as fh:
    json.dump(report, fh, indent=2)
PY

echo "Security scan completed. Summary written to ${SUMMARY_JSON}"

