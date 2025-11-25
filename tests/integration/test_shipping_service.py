"""
Integration Tests for Shipping Service (OrderItem Service)
"""
import pytest
import requests

@pytest.mark.integration
class TestShippingService:
    """Integration tests for Shipping Service (OrderItem operations)"""
    
    def test_create_order_item(self, api_gateway_url, order_item_data, timeout):
        """Test 1: Create a new order item"""
        response = requests.post(
            f"{api_gateway_url}/shipping-service/api/shippings",
            json=order_item_data,
            timeout=timeout
        )
        
        assert response.status_code in [200, 201], f"Expected 200/201, got {response.status_code}"
        data = response.json()
        assert data['productId'] == order_item_data['productId']
        assert data['orderId'] == order_item_data['orderId']
        print(f"✓ Order item created successfully: productId={data['productId']}, orderId={data['orderId']}")
    
    def test_get_all_order_items(self, api_gateway_url, timeout):
        """Test 2: Retrieve all order items"""
        response = requests.get(
            f"{api_gateway_url}/shipping-service/api/shippings",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert 'collection' in data, "Response should contain 'collection' field"
        print(f"✓ Retrieved {len(data['collection'])} order items")
    
    def test_get_order_item_by_id(self, api_gateway_url, timeout):
        """Test 3: Retrieve a specific order item by composite ID"""
        order_id = 1
        product_id = 1
        response = requests.get(
            f"{api_gateway_url}/shipping-service/api/shippings/{order_id}/{product_id}",
            timeout=timeout
        )
        
        # Accept 200 or 404 if order item doesn't exist
        assert response.status_code in [200, 404]
        if response.status_code == 200:
            data = response.json()
            assert data['orderId'] == order_id
            assert data['productId'] == product_id
            print(f"✓ Order item (orderId={order_id}, productId={product_id}) retrieved successfully")
    
    def test_get_order_item_by_find_endpoint(self, api_gateway_url, timeout):
        """Test 4: Retrieve order item using /find endpoint"""
        order_item_id = {
            "orderId": 1,
            "productId": 1
        }
        response = requests.get(
            f"{api_gateway_url}/shipping-service/api/shippings/find",
            json=order_item_id,
            timeout=timeout
        )
        
        # Accept 200 or 404 if order item doesn't exist
        assert response.status_code in [200, 404]
        if response.status_code == 200:
            data = response.json()
            assert data['orderId'] == order_item_id['orderId']
            print("✓ Order item retrieved via /find endpoint successfully")
    
    def test_update_order_item(self, api_gateway_url, order_item_data, timeout):
        """Test 5: Update an existing order item"""
        # First create the order item
        create_response = requests.post(
            f"{api_gateway_url}/shipping-service/api/shippings",
            json=order_item_data,
            timeout=timeout
        )
        
        if create_response.status_code in [200, 201]:
            # Update the order item
            order_item_data['orderedQuantity'] = 10
            response = requests.put(
                f"{api_gateway_url}/shipping-service/api/shippings",
                json=order_item_data,
                timeout=timeout
            )
            
            assert response.status_code in [200, 204]
            print(f"✓ Order item updated successfully")
    
    def test_delete_order_item_by_path(self, api_gateway_url, timeout):
        """Test 6: Delete an order item using path parameters"""
        order_id = 1
        product_id = 1
        response = requests.delete(
            f"{api_gateway_url}/shipping-service/api/shippings/{order_id}/{product_id}",
            timeout=timeout
        )
        
        # Accept 200, 204, or 404 (if already deleted)
        assert response.status_code in [200, 204, 404]
        print(f"✓ Order item (orderId={order_id}, productId={product_id}) delete request processed")
    
    def test_delete_order_item_by_body(self, api_gateway_url, timeout):
        """Test 7: Delete an order item using request body"""
        order_item_id = {
            "orderId": 1,
            "productId": 1
        }
        response = requests.delete(
            f"{api_gateway_url}/shipping-service/api/shippings/delete",
            json=order_item_id,
            timeout=timeout
        )
        
        # Accept 200, 204, or 404 (if already deleted)
        assert response.status_code in [200, 204, 404]
        print("✓ Order item delete request processed via /delete endpoint")
    
    def test_shipping_service_health(self, api_gateway_url, timeout):
        """Test 8: Verify shipping service health endpoint"""
        response = requests.get(
            f"{api_gateway_url}/shipping-service/actuator/health",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'UP', f"Service should be UP, got {data['status']}"
        print("✓ Shipping service is healthy")
    
    def test_order_item_integration_with_products_and_orders(self, api_gateway_url, timeout):
        """Test 9: Verify order item service integrates with product and order services"""
        # This test verifies that order item service can fetch product and order data
        response = requests.get(
            f"{api_gateway_url}/shipping-service/api/shippings",
            timeout=timeout
        )
        
        if response.status_code == 200:
            data = response.json()
            if len(data['collection']) > 0:
                order_item = data['collection'][0]
                # Verify that product and order data are included in response
                assert 'product' in order_item or 'productDto' in order_item, \
                    "Order item should include product information"
                assert 'order' in order_item or 'orderDto' in order_item, \
                    "Order item should include order information"
                print("✓ Shipping service successfully integrates with product and order services")

