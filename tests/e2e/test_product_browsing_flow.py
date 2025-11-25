"""
E2E Tests: Product Browsing and Navigation Flow
Tests product search, browsing, category navigation, and product details
"""
import pytest
import requests
import time

@pytest.mark.e2e
class TestProductBrowsingFlow:
    """Test product browsing, search, and navigation flows"""
    
    def test_complete_product_browsing_flow(self, api_gateway_url, timeout):
        """E2E Test: Complete product browsing and navigation flow"""
        
        print("\n" + "="*60)
        print("E2E TEST: Complete Product Browsing Flow")
        print("="*60)
        
        # ============================================================
        # STEP 1: Browse all products
        # ============================================================
        print("\n🛍️  Step 1: Browsing all products...")
        products_response = requests.get(
            f"{api_gateway_url}/product-service/api/products",
            timeout=timeout
        )
        assert products_response.status_code == 200
        products_data = products_response.json()
        products = products_data.get('collection', [])
        assert len(products) > 0, "No products available"
        print(f"    ✓ Found {len(products)} products")
        time.sleep(1)
        
        # ============================================================
        # STEP 2: Get product details
        # ============================================================
        print("\n🔍 Step 2: Getting product details...")
        if len(products) > 0:
            first_product = products[0]
            product_id = first_product['productId']
            
            product_detail_response = requests.get(
                f"{api_gateway_url}/product-service/api/products/{product_id}",
                timeout=timeout
            )
            assert product_detail_response.status_code == 200
            product_details = product_detail_response.json()
            print(f"    ✓ Product details retrieved: {product_details.get('productTitle', 'N/A')}")
            print(f"    ✓ Product ID: {product_id}")
            print(f"    ✓ Price: ${product_details.get('priceUnit', 0)}")
        time.sleep(1)
        
        # ============================================================
        # STEP 3: Browse categories
        # ============================================================
        print("\n📂 Step 3: Browsing product categories...")
        categories_response = requests.get(
            f"{api_gateway_url}/product-service/api/categories",
            timeout=timeout
        )
        assert categories_response.status_code == 200
        categories_data = categories_response.json()
        categories = categories_data.get('collection', [])
        print(f"    ✓ Found {len(categories)} categories")
        
        if len(categories) > 0:
            for idx, category in enumerate(categories[:3]):  # Show first 3
                print(f"    ✓ Category {idx + 1}: {category.get('categoryTitle', 'N/A')}")
        time.sleep(1)
        
        # ============================================================
        # STEP 4: Browse multiple products (simulate navigation)
        # ============================================================
        print("\n📖 Step 4: Browsing multiple products (navigation)...")
        if len(products) >= 3:
            for idx, product in enumerate(products[:3]):
                product_id = product['productId']
                product_response = requests.get(
                    f"{api_gateway_url}/product-service/api/products/{product_id}",
                    timeout=timeout
                )
                if product_response.status_code == 200:
                    product_info = product_response.json()
                    print(f"    ✓ Product {idx + 1}: {product_info.get('productTitle', 'N/A')}")
        time.sleep(1)
        
        print("\n" + "="*60)
        print("✅ PRODUCT BROWSING FLOW COMPLETED")
        print("="*60)
        print(f"Products browsed: {len(products)}")
        print(f"Categories found: {len(categories)}")
        print("="*60 + "\n")
    
    def test_product_search_and_filter_flow(self, api_gateway_url, timeout):
        """E2E Test: Product search and filtering flow"""
        
        print("\n" + "="*60)
        print("E2E TEST: Product Search and Filter Flow")
        print("="*60)
        
        # Step 1: Get all products (simulate search)
        print("\n🔍 Step 1: Searching products (get all)...")
        products_response = requests.get(
            f"{api_gateway_url}/product-service/api/products",
            timeout=timeout
        )
        assert products_response.status_code == 200
        products = products_response.json().get('collection', [])
        print(f"    ✓ Search returned {len(products)} products")
        time.sleep(1)
        
        # Step 2: Filter by specific product (get by ID)
        print("\n🎯 Step 2: Filtering by specific product...")
        if len(products) > 0:
            target_product = products[0]
            product_id = target_product['productId']
            
            filtered_response = requests.get(
                f"{api_gateway_url}/product-service/api/products/{product_id}",
                timeout=timeout
            )
            assert filtered_response.status_code == 200
            filtered_product = filtered_response.json()
            print(f"    ✓ Filtered product: {filtered_product.get('productTitle', 'N/A')}")
        time.sleep(1)
        
        # Step 3: Browse categories (filter by category)
        print("\n📂 Step 3: Filtering by category...")
        categories_response = requests.get(
            f"{api_gateway_url}/product-service/api/categories",
            timeout=timeout
        )
        assert categories_response.status_code == 200
        categories = categories_response.json().get('collection', [])
        print(f"    ✓ Found {len(categories)} categories for filtering")
        
        print("\n" + "="*60)
        print("✅ PRODUCT SEARCH AND FILTER FLOW COMPLETED")
        print("="*60 + "\n")
    
    def test_product_details_navigation_flow(self, api_gateway_url, timeout):
        """E2E Test: Navigate through product details"""
        
        print("\n" + "="*60)
        print("E2E TEST: Product Details Navigation Flow")
        print("="*60)
        
        # Step 1: Get product list
        print("\n📋 Step 1: Getting product list...")
        products_response = requests.get(
            f"{api_gateway_url}/product-service/api/products",
            timeout=timeout
        )
        assert products_response.status_code == 200
        products = products_response.json().get('collection', [])
        assert len(products) >= 2, "Need at least 2 products"
        print(f"    ✓ Product list retrieved: {len(products)} products")
        time.sleep(1)
        
        # Step 2: Navigate through product details
        print("\n🔍 Step 2: Navigating through product details...")
        for idx, product in enumerate(products[:3]):  # Navigate first 3
            product_id = product['productId']
            detail_response = requests.get(
                f"{api_gateway_url}/product-service/api/products/{product_id}",
                timeout=timeout
            )
            if detail_response.status_code == 200:
                details = detail_response.json()
                print(f"    ✓ Product {idx + 1}: {details.get('productTitle', 'N/A')}")
                print(f"      - SKU: {details.get('sku', 'N/A')}")
                print(f"      - Price: ${details.get('priceUnit', 0)}")
                print(f"      - Quantity: {details.get('quantity', 0)}")
        time.sleep(1)
        
        print("\n" + "="*60)
        print("✅ PRODUCT DETAILS NAVIGATION FLOW COMPLETED")
        print("="*60 + "\n")

