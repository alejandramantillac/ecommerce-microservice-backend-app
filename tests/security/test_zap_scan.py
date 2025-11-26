"""
OWASP ZAP Security Scan Tests
Scans API Gateway for common web application vulnerabilities
"""
import os
import time
import pytest
from zapv2 import ZAPv2


@pytest.fixture(scope="session")
def zap():
    """Initialize ZAP proxy connection"""
    zap_proxy = ZAPv2(proxies={'http': 'http://127.0.0.1:8080', 'https': 'http://127.0.0.1:8080'})
    
    # Wait for ZAP to be ready
    print("Waiting for ZAP to be ready...")
    timeout = 60
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            zap_proxy.core.version()
            print("ZAP is ready")
            break
        except Exception:
            time.sleep(2)
    else:
        pytest.fail("ZAP proxy is not responding")
    
    return zap_proxy


@pytest.fixture(scope="session")
def api_gateway_url():
    """Get API Gateway URL from environment"""
    url = os.getenv("API_GATEWAY_URL", "http://172.193.110.101:8080")
    if not url.startswith("http"):
        url = f"http://{url}"
    return url


@pytest.mark.security
def test_zap_spider_scan(api_gateway_url, zap):
    """Run ZAP spider scan to discover URLs"""
    print(f"Starting ZAP spider scan on {api_gateway_url}")
    
    try:
        scan_id = zap.spider.scan(api_gateway_url)
        
        # Wait for spider to complete
        while int(zap.spider.status(scan_id)) < 100:
            progress = zap.spider.status(scan_id)
            print(f"Spider scan progress: {progress}%")
            time.sleep(2)
        
        print("Spider scan completed")
        
        # Get discovered URLs
        urls = zap.spider.results(scan_id)
        print(f"Discovered {len(urls)} URLs")
        
    except Exception as e:
        pytest.fail(f"Spider scan failed: {str(e)}")


@pytest.mark.security
def test_zap_active_scan(api_gateway_url, zap):
    """Run ZAP active scan to find vulnerabilities"""
    print(f"Starting ZAP active scan on {api_gateway_url}")
    
    try:
        # Run active scan
        scan_id = zap.ascan.scan(api_gateway_url)
        
        # Wait for active scan to complete
        while int(zap.ascan.status(scan_id)) < 100:
            progress = zap.ascan.status(scan_id)
            print(f"Active scan progress: {progress}%")
            time.sleep(5)
        
        print("Active scan completed")
        
        # Get alerts
        alerts = zap.core.alerts(baseurl=api_gateway_url)
        
        # Categorize alerts by risk
        critical_alerts = [a for a in alerts if a.get('risk') == 'Critical']
        high_alerts = [a for a in alerts if a.get('risk') == 'High']
        medium_alerts = [a for a in alerts if a.get('risk') == 'Medium']
        low_alerts = [a for a in alerts if a.get('risk') == 'Low']
        info_alerts = [a for a in alerts if a.get('risk') == 'Informational']
        
        print(f"\n=== ZAP Scan Results ===")
        print(f"Critical: {len(critical_alerts)}")
        print(f"High: {len(high_alerts)}")
        print(f"Medium: {len(medium_alerts)}")
        print(f"Low: {len(low_alerts)}")
        print(f"Informational: {len(info_alerts)}")
        
        # Print high and critical alerts
        if critical_alerts or high_alerts:
            print("\n=== High/Critical Vulnerabilities ===")
            for alert in critical_alerts + high_alerts:
                print(f"[{alert.get('risk')}] {alert.get('name')}: {alert.get('alert')}")
        
        # Fail test if critical or high vulnerabilities found
        if critical_alerts:
            pytest.fail(f"Found {len(critical_alerts)} Critical vulnerabilities")
        
        if high_alerts:
            pytest.fail(f"Found {len(high_alerts)} High risk vulnerabilities")
            
    except Exception as e:
        pytest.fail(f"Active scan failed: {str(e)}")


@pytest.mark.security
def test_zap_alerts_summary(api_gateway_url, zap):
    """Get summary of all alerts"""
    try:
        alerts = zap.core.alerts(baseurl=api_gateway_url)
        
        # Group by alert name
        alert_summary = {}
        for alert in alerts:
            name = alert.get('name', 'Unknown')
            risk = alert.get('risk', 'Unknown')
            if name not in alert_summary:
                alert_summary[name] = {'count': 0, 'risk': risk}
            alert_summary[name]['count'] += 1
        
        print("\n=== Alert Summary ===")
        for name, info in sorted(alert_summary.items()):
            print(f"[{info['risk']}] {name}: {info['count']} occurrences")
            
    except Exception as e:
        print(f"Warning: Could not get alert summary: {str(e)}")

