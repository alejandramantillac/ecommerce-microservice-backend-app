"""
Integration Tests for Product Service
"""
import pytest
import requests

@pytest.mark.integration
class TestProductService:
    
    def test_create_product(self, api_gateway_url, product_data, timeout):
        """Test 1: Create a new product"""
        response = requests.post(
            f"{api_gateway_url}/product-service/api/products",
            json=product_data,
            timeout=timeout
        )
        
        assert response.status_code in [200, 201]
        data = response.json()
        assert data['productTitle'] == product_data['productTitle']
        print(f"✓ Product created successfully: {data['productId']}")
    
    def test_get_all_products(self, api_gateway_url, timeout):
        """Test 2: Retrieve all products"""
        response = requests.get(
            f"{api_gateway_url}/product-service/api/products",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert 'collection' in data
        assert len(data['collection']) > 0
        print(f"✓ Retrieved {len(data['collection'])} products")
    
    def test_get_product_by_id(self, api_gateway_url, timeout):
        """Test 3: Retrieve a specific product by ID"""
        product_id = 1
        response = requests.get(
            f"{api_gateway_url}/product-service/api/products/{product_id}",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data['productId'] == product_id
        print(f"✓ Product {product_id} retrieved successfully")
    
    def test_get_all_categories(self, api_gateway_url, timeout):
        """Test 4: Retrieve all categories"""
        response = requests.get(
            f"{api_gateway_url}/product-service/api/categories",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert 'collection' in data
        print(f"✓ Retrieved {len(data['collection'])} categories")
    
    def test_product_service_health(self, api_gateway_url, timeout):
        """Test 5: Verify product service health endpoint"""
        response = requests.get(
            f"{api_gateway_url}/product-service/actuator/health",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'UP'
        print("✓ Product service is healthy")
    
    def test_update_product(self, api_gateway_url, product_data, timeout):
        """Test 6: Update an existing product"""
        # First create the product
        requests.post(
            f"{api_gateway_url}/product-service/api/products",
            json=product_data,
            timeout=timeout
        )
        
        # Update the product
        product_data['productTitle'] = 'Updated Product'
        product_data['priceUnit'] = 149.99
        response = requests.put(
            f"{api_gateway_url}/product-service/api/products",
            json=product_data,
            timeout=timeout
        )
        
        assert response.status_code in [200, 204]
        print(f"✓ Product {product_data['productId']} updated successfully")

