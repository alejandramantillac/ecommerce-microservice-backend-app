#!/bin/bash
# OWASP ZAP Full Scan - Comprehensive security scan for APIs
# Usage: zap-full-scan.sh <target-url> [report-dir] [timeout]

set -e

TARGET_URL="${1:-http://172.193.110.101:8080}"
REPORT_DIR="${2:-zap-reports}"
TIMEOUT="${3:-1800}"  # 30 minutes default

if [ -z "$TARGET_URL" ]; then
    echo "Usage: $0 <target-url> [report-dir] [timeout-seconds]"
    echo "Example: $0 http://172.193.110.101:8080 zap-reports 1800"
    exit 1
fi

echo "========================================="
echo "OWASP ZAP Full Security Scan"
echo "Target: ${TARGET_URL}"
echo "Report Directory: ${REPORT_DIR}"
echo "Timeout: ${TIMEOUT}s (~30 minutes)"
echo "========================================="

mkdir -p "${REPORT_DIR}"
chmod 777 "${REPORT_DIR}" 2>/dev/null || true

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
echo "Starting OWASP ZAP full scan..."
echo "This is a comprehensive scan that performs deep analysis (~10-30 minutes)"
echo ""

# Run ZAP full scan using Docker
echo "Running ZAP scan..."
echo "Pulling OWASP ZAP Docker image (this may take a few minutes on first run)..."
docker run --rm \
    -v "$(pwd)/${REPORT_DIR}:/zap/wrk/:rw" \
    -t ghcr.io/zaproxy/zaproxy:stable \
    zap-full-scan.py \
    -t "${TARGET_URL}" \
    -J zap-full-report.json \
    -r zap-full-report.html \
    -x zap-full-report.xml \
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
if [ -f "${REPORT_DIR}/zap-full-report.json" ]; then
    echo ""
    echo "========================================="
    echo "[OK] Full scan completed"
    echo "========================================="
    
    # Show report locations
    echo ""
    echo "Reportes generados:"
    echo "  HTML: $(pwd)/${REPORT_DIR}/zap-full-report.html"
    echo "  JSON: $(pwd)/${REPORT_DIR}/zap-full-report.json"
    echo "  XML:  $(pwd)/${REPORT_DIR}/zap-full-report.xml"
    echo ""
    
    # Parse and display summary
    if command -v python3 &> /dev/null; then
        python3 << EOF
import json
import sys

try:
    with open('${REPORT_DIR}/zap-full-report.json', 'r') as f:
        data = json.load(f)
    
    # Find the target site (usually the first non-CDN site)
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
    
    print(f"\n[INFO] Full Security Scan Summary:")
    print(f"   High Risk: {high}")
    print(f"   Medium Risk: {medium}")
    print(f"   Low Risk: {low}")
    print(f"   Informational: {informational}")
    print(f"   Total Alerts: {len(alerts)}")
    
    if high > 0:
        print(f"\n[WARNING] {high} high-risk vulnerabilities found!")
        print("\nTop High-Risk Issues:")
        high_alerts = [a for a in alerts if a.get('riskcode') == '3' or 'High' in a.get('riskdesc', '')][:5]
        for alert in high_alerts:
            desc = alert.get('desc', 'N/A')
            # Remove HTML tags
            import re
            desc = re.sub('<[^>]+>', '', desc)
            desc = desc[:80] + '...' if len(desc) > 80 else desc
            print(f"   - {alert.get('name', 'Unknown')}: {desc}")
        sys.exit(1)
    elif medium > 0:
        print(f"\n[WARNING] {medium} medium-risk vulnerabilities found!")
        print("\nTop Medium-Risk Issues:")
        medium_alerts = [a for a in alerts if a.get('riskcode') == '2' or ('Medium' in a.get('riskdesc', '') and 'Low' not in a.get('riskdesc', ''))][:5]
        for alert in medium_alerts:
            print(f"   - {alert.get('name', 'Unknown')}")
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
