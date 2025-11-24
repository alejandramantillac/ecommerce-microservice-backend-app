#!/bin/bash
# OWASP ZAP API Scan - Targeted scan for specific API endpoints
# Usage: zap-api-scan.sh <target-url> <api-path> [report-dir] [timeout]

set -e

TARGET_URL="${1:-http://172.193.110.101:8080}"
API_PATH="${2:-/api}"
REPORT_DIR="${3:-zap-reports}"
TIMEOUT="${4:-600}"  # 10 minutes default

if [ -z "$TARGET_URL" ] || [ -z "$API_PATH" ]; then
    echo "Usage: $0 <target-url> <api-path> [report-dir] [timeout-seconds]"
    echo "Example: $0 http://172.193.110.101:8080 /api/products zap-reports 600"
    exit 1
fi

echo "========================================="
echo "OWASP ZAP API Security Scan"
echo "Target: ${TARGET_URL}${API_PATH}"
echo "Report Directory: ${REPORT_DIR}"
echo "Timeout: ${TIMEOUT}s"
echo "========================================="

mkdir -p "${REPORT_DIR}"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "[ERROR] Docker is required to run OWASP ZAP"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "[ERROR] Docker Desktop is not running!"
    echo ""
    echo "Please:"
    echo "  1. Start Docker Desktop application"
    echo "  2. Wait for it to fully start"
    echo "  3. Run this script again"
    exit 1
fi

echo ""
echo "Starting OWASP ZAP API scan..."
echo "This scan targets specific API endpoints (~5-10 minutes)"
echo ""

# Run ZAP API scan using Docker
echo "Running ZAP scan..."
echo "Pulling OWASP ZAP Docker image (this may take a few minutes on first run)..."
docker run --rm \
    -v "$(pwd)/${REPORT_DIR}:/zap/wrk/:rw" \
    -t ghcr.io/zaproxy/zaproxy:stable \
    zap-api-scan.py \
    -t "${TARGET_URL}${API_PATH}" \
    -f openapi \
    -J zap-api-report.json \
    -r zap-api-report.html \
    -x zap-api-report.xml \
    -I \
    -j \
    -m "${TIMEOUT}" \
    || SCAN_EXIT_CODE=$?

# Check if scan failed due to Docker connection
if [ ${SCAN_EXIT_CODE:-0} -ne 0 ]; then
    if ! docker ps &> /dev/null; then
        echo ""
        echo "[ERROR] Docker connection failed!"
        echo "Please ensure Docker Desktop is running and try again."
        exit 1
    fi
fi

# Check if scan completed
if [ -f "${REPORT_DIR}/zap-api-report.json" ]; then
    echo ""
    echo "========================================="
    echo "[OK] API scan completed"
    echo "========================================="
    
    # Show report locations
    echo ""
    echo "Reportes generados:"
    echo "  HTML: $(pwd)/${REPORT_DIR}/zap-api-report.html"
    echo "  JSON: $(pwd)/${REPORT_DIR}/zap-api-report.json"
    echo "  XML:  $(pwd)/${REPORT_DIR}/zap-api-report.xml"
    echo ""
    
    # Parse and display summary
    if command -v python3 &> /dev/null; then
        python3 << EOF
import json
import sys

try:
    with open('${REPORT_DIR}/zap-api-report.json', 'r') as f:
        data = json.load(f)
    
    # Find the target site
    target_site = None
    for site in data.get('site', []):
        host = site.get('@host', '')
        if 'cdn' not in host.lower() and 'mozilla' not in host.lower():
            target_site = site
            break
    
    if not target_site:
        target_site = data.get('site', [{}])[0]
    
    alerts = target_site.get('alerts', [])
    
    # Map risk codes: 0=Informational, 1=Low, 2=Medium, 3=High
    high = sum(1 for a in alerts if a.get('riskcode') == '3' or 'High' in a.get('riskdesc', ''))
    medium = sum(1 for a in alerts if a.get('riskcode') == '2' or ('Medium' in a.get('riskdesc', '') and 'Low' not in a.get('riskdesc', '')))
    low = sum(1 for a in alerts if a.get('riskcode') == '1' or 'Low' in a.get('riskdesc', ''))
    informational = sum(1 for a in alerts if a.get('riskcode') == '0' or 'Informational' in a.get('riskdesc', ''))
    
    print(f"\n[INFO] API Security Scan Summary:")
    print(f"   High Risk: {high}")
    print(f"   Medium Risk: {medium}")
    print(f"   Low Risk: {low}")
    print(f"   Informational: {informational}")
    print(f"   Total Alerts: {len(alerts)}")
    
    if high > 0:
        print(f"\n[WARNING] {high} high-risk vulnerabilities found!")
        sys.exit(1)
    elif medium > 0:
        print(f"\n[WARNING] {medium} medium-risk vulnerabilities found!")
        sys.exit(0)
    else:
        if low > 0:
            print(f"\n[INFO] Found {low} low-risk issues (review recommended)")
        print(f"\n[OK] No high or medium risk vulnerabilities found")
        sys.exit(0)
except Exception as e:
    print(f"Error parsing report: {e}")
    sys.exit(1)
EOF
        EXIT_CODE=$?
    else
        echo "[WARNING] Python3 not available, skipping report parsing"
        EXIT_CODE=${SCAN_EXIT_CODE:-0}
    fi
else
    echo ""
    echo "[ERROR] Scan report not generated"
    exit 1
fi

exit ${EXIT_CODE:-0}
