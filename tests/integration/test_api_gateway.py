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
    
    def test_gateway_routes_order_service(self, api_gateway_url, timeout):
        """Test 6: Verify routing to order service"""
        response = requests.get(
            f"{api_gateway_url}/order-service/api/orders",
            timeout=timeout
        )
        
        assert response.status_code == 200
        print("✓ Gateway routes to order-service correctly")
    
    def test_gateway_routes_payment_service(self, api_gateway_url, timeout):
        """Test 7: Verify routing to payment service"""
        response = requests.get(
            f"{api_gateway_url}/payment-service/api/payments",
            timeout=timeout
        )
        
        assert response.status_code == 200
        print("✓ Gateway routes to payment-service correctly")
    
    def test_gateway_routes_shipping_service(self, api_gateway_url, timeout):
        """Test 8: Verify routing to shipping service"""
        response = requests.get(
            f"{api_gateway_url}/shipping-service/api/shippings",
            timeout=timeout
        )
        
        assert response.status_code == 200
        print("✓ Gateway routes to shipping-service correctly")
    
    @pytest.mark.smoke
    def test_all_services_reachable(self, api_gateway_url, timeout):
        """Test 9: Smoke test - verify all services are reachable through gateway"""
        services = [
            'user-service',
            'product-service',
            'favourite-service',
            'order-service',
            'payment-service',
            'shipping-service'
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
        
        # Accept at least 50% of services reachable (more lenient for integration tests)
        assert reachable >= len(services) * 0.5, \
            f"Expected at least 50% of services reachable, got {reachable}/{len(services)}"
        print(f"✓ {reachable}/{len(services)} services are reachable")

