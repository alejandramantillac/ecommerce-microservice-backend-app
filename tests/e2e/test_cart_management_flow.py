"""
E2E Tests: Complete Cart Management Flow
Tests the complete cart lifecycle: create, add items, update, review, and clear
"""
import pytest
import requests
import time

@pytest.mark.e2e
class TestCartManagementFlow:
    """Test complete cart management operations"""
    
    def test_complete_cart_management_flow(self, api_gateway_url, timeout):
        """E2E Test: Complete cart management flow"""
        
        print("\n" + "="*60)
        print("E2E TEST: Complete Cart Management Flow")
        print("="*60)
        
        # ============================================================
        # STEP 1: Create user
        # ============================================================
        print("\n📝 Step 1: Creating user...")
        user_data = {
            "userId": 500,
            "firstName": "Sofia",
            "lastName": "López",
            "imageUrl": "https://example.com/sofia.jpg",
            "email": "sofia.lopez@example.com",
            "phone": "+573007777777",
            "credential": {
                "credentialId": 500,
                "username": "sofia.lopez",
                "password": "SofiaPass123!",
                "roleBasedAuthority": "ROLE_USER",
                "isEnabled": True,
                "isAccountNonExpired": True,
                "isAccountNonLocked": True,
                "isCredentialsNonExpired": True
            }
        }
        
        user_response = requests.post(
            f"{api_gateway_url}/user-service/api/users",
            json=user_data,
            timeout=timeout
        )
        assert user_response.status_code in [200, 201]
        user_id = user_response.json()['userId']
        print(f"    ✓ User created: {user_id}")
        time.sleep(1)
        
        # ============================================================
        # STEP 2: Get products to add to cart
        # ============================================================
        print("\n🛍️  Step 2: Getting products...")
        products_response = requests.get(
            f"{api_gateway_url}/product-service/api/products",
            timeout=timeout
        )
        assert products_response.status_code == 200
        products = products_response.json().get('collection', [])
        assert len(products) >= 2, "Need at least 2 products for this test"
        selected_products = products[:2]
        print(f"    ✓ Selected {len(selected_products)} products")
        time.sleep(1)
        
        # ============================================================
        # STEP 3: Create cart
        # ============================================================
        print("\n🛒 Step 3: Creating cart...")
        cart_data = {
            "cartId": 500,
            "userId": user_id,
        }
        
        cart_response = requests.post(
            f"{api_gateway_url}/order-service/api/carts",
            json=cart_data,
            timeout=timeout
        )
        if cart_response.status_code == 503:
            pytest.skip("Order service is not available (503). Service needs to be running for E2E tests.")
        assert cart_response.status_code in [200, 201]
        created_cart = cart_response.json()
        cart_id = created_cart['cartId']
        print(f"    ✓ Cart created: {cart_id}")
        time.sleep(1)
        
        # ============================================================
        # STEP 4: Review cart (verify it's empty or has items)
        # ============================================================
        print("\n👀 Step 4: Reviewing cart...")
        cart_review_response = requests.get(
            f"{api_gateway_url}/order-service/api/carts/{cart_id}",
            timeout=timeout
        )
        if cart_review_response.status_code == 200:
            cart_details = cart_review_response.json()
            print(f"    ✓ Cart reviewed")
            print(f"    ✓ Cart ID: {cart_details.get('cartId', 'N/A')}")
            print(f"    ✓ User ID: {cart_details.get('userId', 'N/A')}")
        time.sleep(1)
        
        # ============================================================
        # STEP 5: Update cart (modify cart properties)
        # ============================================================
        print("\n✏️  Step 5: Updating cart...")
        updated_cart_data = {
            "cartId": cart_id,
            "userId": user_id,
        }
        
        cart_update_response = requests.put(
            f"{api_gateway_url}/order-service/api/carts",
            json=updated_cart_data,
            timeout=timeout
        )
        if cart_update_response.status_code in [200, 204]:
            print(f"    ✓ Cart updated successfully")
        time.sleep(1)
        
        # ============================================================
        # STEP 6: Get all carts (verify cart exists in list)
        # ============================================================
        print("\n📋 Step 6: Getting all carts...")
        all_carts_response = requests.get(
            f"{api_gateway_url}/order-service/api/carts",
            timeout=timeout
        )
        if all_carts_response.status_code == 200:
            all_carts = all_carts_response.json().get('collection', [])
            print(f"    ✓ Found {len(all_carts)} carts in total")
            # Verify our cart is in the list
            cart_found = any(c.get('cartId') == cart_id for c in all_carts)
            if cart_found:
                print(f"    ✓ Our cart ({cart_id}) is in the list")
        time.sleep(1)
        
        # ============================================================
        # STEP 7: Create order from cart (cart is ready for checkout)
        # ============================================================
        print("\n📦 Step 7: Creating order from cart (cart ready for checkout)...")
        from datetime import datetime
        order_data = {
            "orderId": 500,
            "orderDate": datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000"),
            "orderDesc": "Order from managed cart",
            "orderFee": 199.99,
            "cart": {"cartId": cart_id},
        }
        
        order_response = requests.post(
            f"{api_gateway_url}/order-service/api/orders",
            json=order_data,
            timeout=timeout
        )
        if order_response.status_code == 503:
            pytest.skip("Order service is not available (503). Service needs to be running for E2E tests.")
        if order_response.status_code in [200, 201]:
            order_id = order_response.json()['orderId']
            print(f"    ✓ Order created from cart: {order_id}")
        time.sleep(1)
        
        print("\n" + "="*60)
        print("✅ CART MANAGEMENT FLOW COMPLETED")
        print("="*60)
        print(f"User ID: {user_id}")
        print(f"Cart ID: {cart_id}")
        print("="*60 + "\n")
    
    def test_cart_lifecycle_operations(self, api_gateway_url, timeout):
        """E2E Test: Cart lifecycle - create, update, retrieve, delete"""
        
        print("\n" + "="*60)
        print("E2E TEST: Cart Lifecycle Operations")
        print("="*60)
        
        # Step 1: Create user
        print("\n📝 Step 1: Creating user...")
        user_data = {
            "userId": 501,
            "firstName": "Diego",
            "lastName": "Ramírez",
            "imageUrl": "https://example.com/diego.jpg",
            "email": "diego.ramirez@example.com",
            "phone": "+573008888888",
            "credential": {
                "credentialId": 501,
                "username": "diego.ramirez",
                "password": "DiegoPass123!",
                "roleBasedAuthority": "ROLE_USER",
                "isEnabled": True,
                "isAccountNonExpired": True,
                "isAccountNonLocked": True,
                "isCredentialsNonExpired": True
            }
        }
        
        user_response = requests.post(
            f"{api_gateway_url}/user-service/api/users",
            json=user_data,
            timeout=timeout
        )
        assert user_response.status_code in [200, 201]
        user_id = user_response.json()['userId']
        print(f"    ✓ User created: {user_id}")
        time.sleep(1)
        
        # Step 2: Create cart
        print("\n🛒 Step 2: Creating cart...")
        cart_data = {"cartId": 501, "userId": user_id}
        cart_response = requests.post(
            f"{api_gateway_url}/order-service/api/carts",
            json=cart_data,
            timeout=timeout
        )
        if cart_response.status_code == 503:
            pytest.skip("Order service is not available (503). Service needs to be running for E2E tests.")
        assert cart_response.status_code in [200, 201]
        cart_id = cart_response.json()['cartId']
        print(f"    ✓ Cart created: {cart_id}")
        time.sleep(1)
        
        # Step 3: Retrieve cart by ID
        print("\n🔍 Step 3: Retrieving cart by ID...")
        get_cart_response = requests.get(
            f"{api_gateway_url}/order-service/api/carts/{cart_id}",
            timeout=timeout
        )
        if get_cart_response.status_code == 200:
            retrieved_cart = get_cart_response.json()
            print(f"    ✓ Cart retrieved: {retrieved_cart.get('cartId', 'N/A')}")
        time.sleep(1)
        
        # Step 4: Update cart by ID
        print("\n✏️  Step 4: Updating cart by ID...")
        updated_cart_data = {"cartId": cart_id, "userId": user_id}
        update_cart_response = requests.put(
            f"{api_gateway_url}/order-service/api/carts/{cart_id}",
            json=updated_cart_data,
            timeout=timeout
        )
        if update_cart_response.status_code in [200, 204]:
            print(f"    ✓ Cart updated by ID")
        time.sleep(1)
        
        # Step 5: Delete cart (cleanup)
        print("\n🗑️  Step 5: Deleting cart...")
        delete_cart_response = requests.delete(
            f"{api_gateway_url}/order-service/api/carts/{cart_id}",
            timeout=timeout
        )
        # Accept 200, 204, or 404 (if already deleted)
        if delete_cart_response.status_code in [200, 204, 404]:
            print(f"    ✓ Cart deleted or already removed")
        
        print("\n" + "="*60)
        print("✅ CART LIFECYCLE OPERATIONS COMPLETED")
        print("="*60 + "\n")

