#!/usr/bin/env python3
"""
Generate a simple HTML dashboard from the security summary JSON.
Usage: security-generate-dashboard.py <summary-json> <output-html>
"""

import json
import sys
from datetime import datetime

if len(sys.argv) < 3:
    print("Usage: security-generate-dashboard.py <summary-json> <output-html>")
    sys.exit(1)

summary_path, output_path = sys.argv[1], sys.argv[2]

with open(summary_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

generated_at = data.get("generatedAt", datetime.utcnow().isoformat())
totals = data.get("totals", {})
services = data.get("services", {})

severity_order = ["critical", "high", "medium", "low", "unknown"]
severity_colors = {
    "critical": "#e01e5a",
    "high": "#ff8c00",
    "medium": "#f2c744",
    "low": "#2eb67d",
    "unknown": "#95a5a6",
}

def severity_badge(level, value):
    color = severity_colors.get(level, "#333333")
    return f"<span style='background:{color};color:#fff;padding:2px 6px;border-radius:4px;font-size:12px'>{value}</span>"

rows = []
for service, stats in sorted(services.items()):
    badges = " ".join(severity_badge(level, stats.get(level, 0)) for level in severity_order)
    images_html = "<ul>" + "".join(
        f"<li>{img['image']} (C:{img['critical']} H:{img['high']} M:{img['medium']} L:{img['low']} U:{img['unknown']})</li>"
        for img in stats.get("images", [])
    ) + "</ul>"
    rows.append(f"<tr><td>{service}</td><td>{badges}</td><td>{images_html}</td></tr>")

totals_badges = " ".join(
    severity_badge(level, totals.get(level, 0)) for level in severity_order
)

html = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Security Vulnerability Dashboard</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            margin: 20px;
            background: #0d1117;
            color: #e6edf3;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
        }}
        th, td {{
            border: 1px solid #30363d;
            padding: 10px;
            vertical-align: top;
        }}
        th {{
            background: #161b22;
        }}
        ul {{
            margin: 0;
            padding-left: 20px;
        }}
    </style>
</head>
<body>
    <h1>Security Vulnerability Dashboard</h1>
    <p>Generated at: {generated_at}</p>
    <h2>Totals</h2>
    <p>{totals_badges}</p>
    <table>
        <thead>
            <tr>
                <th>Service</th>
                <th>Severities</th>
                <th>Images</th>
            </tr>
        </thead>
        <tbody>
            {''.join(rows)}
        </tbody>
    </table>
</body>
</html>
""".strip()

with open(output_path, "w", encoding="utf-8") as fh:
    fh.write(html)

print(f"Dashboard written to {output_path}")

