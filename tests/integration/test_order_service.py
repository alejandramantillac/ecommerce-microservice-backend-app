"""
Integration Tests for Order Service
"""
import pytest
import requests
from datetime import datetime

@pytest.mark.integration
class TestOrderService:
    
    def test_create_order(self, api_gateway_url, order_data, timeout):
        """Test 1: Create a new order"""
        response = requests.post(
            f"{api_gateway_url}/order-service/api/orders",
            json=order_data,
            timeout=timeout
        )
        
        assert response.status_code in [200, 201], f"Expected 200/201, got {response.status_code}"
        data = response.json()
        assert data['orderDesc'] == order_data['orderDesc']
        print(f"✓ Order created successfully: {data['orderId']}")
    
    def test_get_all_orders(self, api_gateway_url, timeout):
        """Test 2: Retrieve all orders"""
        response = requests.get(
            f"{api_gateway_url}/order-service/api/orders",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert 'collection' in data, "Response should contain 'collection' field"
        print(f"✓ Retrieved {len(data['collection'])} orders")
    
    def test_get_order_by_id(self, api_gateway_url, timeout):
        """Test 3: Retrieve a specific order by ID"""
        order_id = 1
        response = requests.get(
            f"{api_gateway_url}/order-service/api/orders/{order_id}",
            timeout=timeout
        )
        
        assert response.status_code in [200, 404]
        if response.status_code == 200:
            data = response.json()
            assert data['orderId'] == order_id
            print(f"✓ Order {order_id} retrieved successfully")
    
    def test_update_order(self, api_gateway_url, order_data, timeout):
        """Test 4: Update an existing order"""
        # First create the order
        create_response = requests.post(
            f"{api_gateway_url}/order-service/api/orders",
            json=order_data,
            timeout=timeout
        )
        
        if create_response.status_code in [200, 201]:
            # Update the order
            order_data['orderDesc'] = 'Updated Order Description'
            order_data['orderFee'] = 149.99
            response = requests.put(
                f"{api_gateway_url}/order-service/api/orders",
                json=order_data,
                timeout=timeout
            )
            
            assert response.status_code in [200, 204]
            print(f"✓ Order {order_data['orderId']} updated successfully")
    
    def test_update_order_by_id(self, api_gateway_url, order_data, timeout):
        """Test 5: Update an existing order by ID"""
        order_id = 1
        order_data['orderId'] = order_id
        order_data['orderDesc'] = 'Updated via ID'
        
        response = requests.put(
            f"{api_gateway_url}/order-service/api/orders/{order_id}",
            json=order_data,
            timeout=timeout
        )
        
        # Accept 200 or 404 if order doesn't exist
        assert response.status_code in [200, 404]
        print(f"✓ Order {order_id} update request processed")
    
    def test_delete_order(self, api_gateway_url, timeout):
        """Test 6: Delete an order"""
        order_id = 100  # Use a test ID that may or may not exist
        response = requests.delete(
            f"{api_gateway_url}/order-service/api/orders/{order_id}",
            timeout=timeout
        )
        
        # Accept 200, 204, or 404 (if already deleted)
        assert response.status_code in [200, 204, 404]
        print(f"✓ Order {order_id} delete request processed")
    
    def test_order_service_health(self, api_gateway_url, timeout):
        """Test 7: Verify order service health endpoint"""
        response = requests.get(
            f"{api_gateway_url}/order-service/actuator/health",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'UP', f"Service should be UP, got {data['status']}"
        print("✓ Order service is healthy")


@pytest.mark.integration
class TestCartService:
    """Integration tests for Cart Service (part of order-service)"""
    
    def test_create_cart(self, api_gateway_url, cart_data, timeout):
        """Test 1: Create a new cart"""
        response = requests.post(
            f"{api_gateway_url}/order-service/api/carts",
            json=cart_data,
            timeout=timeout
        )
        
        assert response.status_code in [200, 201]
        data = response.json()
        assert data['userId'] == cart_data['userId']
        print(f"✓ Cart created successfully: {data['cartId']}")
    
    def test_get_all_carts(self, api_gateway_url, timeout):
        """Test 2: Retrieve all carts"""
        response = requests.get(
            f"{api_gateway_url}/order-service/api/carts",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert 'collection' in data
        print(f"✓ Retrieved {len(data['collection'])} carts")
    
    def test_get_cart_by_id(self, api_gateway_url, timeout):
        """Test 3: Retrieve a specific cart by ID"""
        cart_id = 1
        response = requests.get(
            f"{api_gateway_url}/order-service/api/carts/{cart_id}",
            timeout=timeout
        )
        
        # Accept 200 or 404 if cart doesn't exist
        assert response.status_code in [200, 404]
        if response.status_code == 200:
            data = response.json()
            assert data['cartId'] == cart_id
            print(f"✓ Cart {cart_id} retrieved successfully")
    
    def test_update_cart(self, api_gateway_url, cart_data, timeout):
        """Test 4: Update an existing cart"""
        # First create the cart
        create_response = requests.post(
            f"{api_gateway_url}/order-service/api/carts",
            json=cart_data,
            timeout=timeout
        )
        
        if create_response.status_code in [200, 201]:
            # Update the cart
            cart_data['userId'] = 2
            response = requests.put(
                f"{api_gateway_url}/order-service/api/carts",
                json=cart_data,
                timeout=timeout
            )
            
            assert response.status_code in [200, 204]
            print(f"✓ Cart {cart_data['cartId']} updated successfully")
    
    def test_update_cart_by_id(self, api_gateway_url, cart_data, timeout):
        """Test 5: Update an existing cart by ID"""
        cart_id = 1
        cart_data['cartId'] = cart_id
        cart_data['userId'] = 3
        
        response = requests.put(
            f"{api_gateway_url}/order-service/api/carts/{cart_id}",
            json=cart_data,
            timeout=timeout
        )
        
        # Accept 200 or 404 if cart doesn't exist
        assert response.status_code in [200, 404]
        print(f"✓ Cart {cart_id} update request processed")
    
    def test_delete_cart(self, api_gateway_url, timeout):
        """Test 6: Delete a cart"""
        cart_id = 100  # Use a test ID
        response = requests.delete(
            f"{api_gateway_url}/order-service/api/carts/{cart_id}",
            timeout=timeout
        )
        
        # Accept 200, 204, or 404 (if already deleted)
        assert response.status_code in [200, 204, 404]
        print(f"✓ Cart {cart_id} delete request processed")

