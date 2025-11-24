#!/bin/bash
# Script to generate consolidated coverage report
# Usage: generate-coverage-report.sh <changed-services>

set -e

CHANGED_SERVICES="${1:-}"

echo "========================================="
echo "Generating Consolidated Coverage Report"
echo "========================================="

mkdir -p coverage-consolidated

# Start HTML file
cat > coverage-consolidated/index.html << 'HTML_HEAD'
<!DOCTYPE html>
<html>
<head>
    <title>Consolidated Coverage Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        .summary { background: #f9f9f9; padding: 15px; border-radius: 5px; margin: 20px 0; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #4CAF50; color: white; font-weight: bold; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        tr:hover { background-color: #f5f5f5; }
        .coverage-good { color: #28a745; font-weight: bold; }
        .coverage-warning { color: #ffc107; font-weight: bold; }
        .coverage-low { color: #dc3545; font-weight: bold; }
        .status-good { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-low { color: #dc3545; }
        a { color: #007bff; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Consolidated Test Coverage Report</h1>
        <div class="summary">
            <p><strong>Generated:</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>
            <p><strong>Services Analyzed:</strong> ${CHANGED_SERVICES:-All}</p>
        </div>
        <table>
            <tr>
                <th>Service/Test Type</th>
                <th>Coverage</th>
                <th>Status</th>
                <th>Report</th>
            </tr>
HTML_HEAD

# Process Java services
if [ -n "$CHANGED_SERVICES" ]; then
    IFS=',' read -ra services <<< "$CHANGED_SERVICES"
    for service in "${services[@]}"; do
        service=$(echo "$service" | xargs)
        coverage_xml="${service}/target/site/jacoco/jacoco.xml"
        
        if [ -f "$coverage_xml" ]; then
            python3 << PYEOF
import xml.etree.ElementTree as ET
import sys

try:
    tree = ET.parse('${coverage_xml}')
    root = tree.getroot()
    
    counter = root.find('.//counter[@type="LINE"]')
    if counter is not None:
        missed = int(counter.get('missed', 0))
        covered = int(counter.get('covered', 0))
        total = missed + covered
        coverage = (covered / total * 100) if total > 0 else 0
        
        if coverage >= 70:
            status = "✓ Good"
            color_class = "coverage-good"
            status_class = "status-good"
        elif coverage >= 50:
            status = "⚠ Warning"
            color_class = "coverage-warning"
            status_class = "status-warning"
        else:
            status = "✗ Low"
            color_class = "coverage-low"
            status_class = "status-low"
        
        print(f'            <tr>')
        print(f'                <td><strong>${service}</strong> (Java)</td>')
        print(f'                <td class="{color_class}">{coverage:.2f}%</td>')
        print(f'                <td class="{status_class}">{status}</td>')
        print(f'                <td><a href="${service}/target/site/jacoco/index.html" target="_blank">View Report</a></td>')
        print(f'            </tr>')
        sys.stdout.flush()
except Exception as e:
    print(f'            <tr><td>${service}</td><td>N/A</td><td>Error</td><td>-</td></tr>', file=sys.stderr)
PYEOF
        fi
    done >> coverage-consolidated/index.html
fi

# Process Python integration tests coverage
if [ -f "coverage-integration.json" ]; then
    python3 << PYEOF
import json
import sys

try:
    with open('coverage-integration.json', 'r') as f:
        data = json.load(f)
    totals = data.get('totals', {})
    coverage = totals.get('percent_covered', 0)
    
    if coverage >= 70:
        status = "✓ Good"
        color_class = "coverage-good"
        status_class = "status-good"
    elif coverage >= 50:
        status = "⚠ Warning"
        color_class = "coverage-warning"
        status_class = "status-warning"
    else:
        status = "✗ Low"
        color_class = "coverage-low"
        status_class = "status-low"
    
    print('            <tr>')
    print('                <td><strong>Integration Tests</strong> (Python)</td>')
    print(f'                <td class="{color_class}">{coverage:.2f}%</td>')
    print(f'                <td class="{status_class}">{status}</td>')
    print('                <td><a href="coverage-integration/index.html" target="_blank">View Report</a></td>')
    print('            </tr>')
    sys.stdout.flush()
except Exception as e:
    pass
PYEOF
fi >> coverage-consolidated/index.html

# Process Python E2E tests coverage
if [ -f "coverage-e2e.json" ]; then
    python3 << PYEOF
import json
import sys

try:
    with open('coverage-e2e.json', 'r') as f:
        data = json.load(f)
    totals = data.get('totals', {})
    coverage = totals.get('percent_covered', 0)
    
    if coverage >= 70:
        status = "✓ Good"
        color_class = "coverage-good"
        status_class = "status-good"
    elif coverage >= 50:
        status = "⚠ Warning"
        color_class = "coverage-warning"
        status_class = "status-warning"
    else:
        status = "✗ Low"
        color_class = "coverage-low"
        status_class = "status-low"
    
    print('            <tr>')
    print('                <td><strong>E2E Tests</strong> (Python)</td>')
    print(f'                <td class="{color_class}">{coverage:.2f}%</td>')
    print(f'                <td class="{status_class}">{status}</td>')
    print('                <td><a href="coverage-e2e/index.html" target="_blank">View Report</a></td>')
    print('            </tr>')
    sys.stdout.flush()
except Exception as e:
    pass
PYEOF
fi >> coverage-consolidated/index.html

# Close HTML
cat >> coverage-consolidated/index.html << 'HTML_FOOT'
        </table>
        <div class="summary" style="margin-top: 30px;">
            <h3>Coverage Thresholds</h3>
            <ul>
                <li><strong>✓ Good:</strong> Coverage ≥ 70%</li>
                <li><strong>⚠ Warning:</strong> Coverage 50-69%</li>
                <li><strong>✗ Low:</strong> Coverage < 50%</li>
            </ul>
        </div>
    </div>
</body>
</html>
HTML_FOOT

echo ""
echo "✓ Consolidated coverage report generated: coverage-consolidated/index.html"
echo ""

