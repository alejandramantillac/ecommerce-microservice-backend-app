"""
Integration Tests for API Gateway
"""
import pytest
import requests

@pytest.mark.integration
class TestAPIGateway:
    
    def test_gateway_health(self, api_gateway_url, timeout):
        """Test 1: Verify API Gateway health"""
        response = requests.get(
            f"{api_gateway_url}/actuator/health",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'UP'
        print("✓ API Gateway is healthy")
    
    def test_gateway_routes_user_service(self, api_gateway_url, timeout):
        """Test 2: Verify routing to user service"""
        response = requests.get(
            f"{api_gateway_url}/user-service/api/users",
            timeout=timeout
        )
        
        assert response.status_code == 200
        print("✓ Gateway routes to user-service correctly")
    
    def test_gateway_routes_product_service(self, api_gateway_url, timeout):
        """Test 3: Verify routing to product service"""
        response = requests.get(
            f"{api_gateway_url}/product-service/api/products",
            timeout=timeout
        )
        
        assert response.status_code == 200
        print("✓ Gateway routes to product-service correctly")
    
    def test_gateway_routes_favourite_service(self, api_gateway_url, timeout):
        """Test 5: Verify routing to favourite service"""
        response = requests.get(
            f"{api_gateway_url}/favourite-service/api/favourites",
            timeout=timeout
        )
        
        assert response.status_code == 200
        print("✓ Gateway routes to favourite-service correctly")
    
    @pytest.mark.smoke
    def test_all_services_reachable(self, api_gateway_url, timeout):
        """Test 6: Smoke test - verify all services are reachable through gateway"""
        services = [
            'user-service',
            'product-service',
            'favourite-service'
        ]
        
        reachable = 0
        for service in services:
            try:
                response = requests.get(
                    f"{api_gateway_url}/{service}/actuator/health",
                    timeout=timeout
                )
                if response.status_code == 200:
                    reachable += 1
                    print(f"  ✓ {service} is reachable")
            except Exception as e:
                print(f"  ✗ {service} is not reachable: {e}")
        
        assert reachable >= len(services), f"Expected at least {len(services)} services reachable, got {reachable}"
        print(f"✓ {reachable}/{len(services)} services are reachable")

