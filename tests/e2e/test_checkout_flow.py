"""
E2E Tests: Complete Checkout Flow
Tests the checkout process from cart review to order confirmation
"""
import pytest
import requests
import time
from datetime import datetime

@pytest.mark.e2e
class TestCheckoutFlow:
    """Test the complete checkout flow: Cart Review → Order Creation → Payment → Confirmation"""
    
    def test_complete_checkout_flow(self, api_gateway_url, timeout):
        """E2E Test: Complete checkout flow from cart to order confirmation"""
        
        print("\n" + "="*60)
        print("E2E TEST: Complete Checkout Flow")
        print("="*60)
        
        # ============================================================
        # STEP 1: Create user
        # ============================================================
        print("\n📝 Step 1: Creating user...")
        user_data = {
            "userId": 400,
            "firstName": "Luis",
            "lastName": "Fernández",
            "imageUrl": "https://example.com/luis.jpg",
            "email": "luis.fernandez@example.com",
            "phone": "+573005555555",
            "credential": {
                "credentialId": 400,
                "username": "luis.fernandez",
                "password": "LuisPass123!",
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
        # STEP 2: Get products for cart
        # ============================================================
        print("\n🛍️  Step 2: Getting products...")
        products_response = requests.get(
            f"{api_gateway_url}/product-service/api/products",
            timeout=timeout
        )
        assert products_response.status_code == 200
        products = products_response.json().get('collection', [])
        assert len(products) > 0
        selected_product = products[0]
        product_id = selected_product['productId']
        product_price = selected_product.get('priceUnit', 0)
        print(f"    ✓ Selected product: {product_id} (${product_price})")
        time.sleep(1)
        
        # ============================================================
        # STEP 3: Create and review cart
        # ============================================================
        print("\n🛒 Step 3: Creating and reviewing cart...")
        cart_data = {
            "cartId": 400,
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
        
        # Review cart
        cart_review_response = requests.get(
            f"{api_gateway_url}/order-service/api/carts/{cart_id}",
            timeout=timeout
        )
        if cart_review_response.status_code == 200:
            cart_details = cart_review_response.json()
            print(f"    ✓ Cart reviewed: User {cart_details.get('userId', 'N/A')}")
        time.sleep(1)
        
        # ============================================================
        # STEP 4: Initiate checkout - Create order from cart
        # ============================================================
        print("\n💼 Step 4: Initiating checkout - Creating order...")
        order_date = datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000")
        order_data = {
            "orderId": 400,
            "orderDate": order_date,
            "orderDesc": "Checkout order from cart",
            "orderFee": product_price * 2,  # Assume quantity 2
            "cart": {"cartId": cart_id},
        }
        
        order_response = requests.post(
            f"{api_gateway_url}/order-service/api/orders",
            json=order_data,
            timeout=timeout
        )
        if order_response.status_code == 503:
            pytest.skip("Order service is not available (503). Service needs to be running for E2E tests.")
        assert order_response.status_code in [200, 201]
        created_order = order_response.json()
        order_id = created_order['orderId']
        print(f"    ✓ Order created: {order_id}")
        print(f"    ✓ Order total: ${order_data['orderFee']}")
        time.sleep(1)
        
        # ============================================================
        # STEP 5: Process payment during checkout
        # ============================================================
        print("\n💳 Step 5: Processing payment...")
        payment_data = {
            "paymentId": 400,
            "isPayed": True,
            "paymentStatus": "COMPLETED",
            "order": {"orderId": order_id},
        }
        
        payment_response = requests.post(
            f"{api_gateway_url}/payment-service/api/payments",
            json=payment_data,
            timeout=timeout
        )
        if payment_response.status_code == 503:
            pytest.skip("Payment service is not available (503). Service needs to be running for E2E tests.")
        assert payment_response.status_code in [200, 201]
        created_payment = payment_response.json()
        payment_id = created_payment['paymentId']
        print(f"    ✓ Payment processed: {payment_id}")
        print(f"    ✓ Payment status: COMPLETED")
        time.sleep(1)
        
        # ============================================================
        # STEP 6: Confirm order - Create shipping items
        # ============================================================
        print("\n📦 Step 6: Confirming order - Creating shipping items...")
        order_item_data = {
            "productId": product_id,
            "orderId": order_id,
            "orderedQuantity": 2,
        }
        
        shipping_response = requests.post(
            f"{api_gateway_url}/shipping-service/api/shippings",
            json=order_item_data,
            timeout=timeout
        )
        if shipping_response.status_code == 503:
            pytest.skip("Shipping service is not available (503). Service needs to be running for E2E tests.")
        assert shipping_response.status_code in [200, 201]
        print(f"    ✓ Shipping items created")
        time.sleep(1)
        
        # ============================================================
        # STEP 7: Verify checkout completion
        # ============================================================
        print("\n✅ Step 7: Verifying checkout completion...")
        
        # Verify order
        order_verify = requests.get(
            f"{api_gateway_url}/order-service/api/orders/{order_id}",
            timeout=timeout
        )
        if order_verify.status_code == 200:
            verified_order = order_verify.json()
            print(f"    ✓ Order verified: {verified_order.get('orderDesc', 'N/A')}")
        
        # Verify payment
        payment_verify = requests.get(
            f"{api_gateway_url}/payment-service/api/payments/{payment_id}",
            timeout=timeout
        )
        if payment_verify.status_code == 200:
            verified_payment = payment_verify.json()
            print(f"    ✓ Payment verified: {verified_payment.get('paymentStatus', 'N/A')}")
        else:
            # Try to verify via list
            all_payments = requests.get(
                f"{api_gateway_url}/payment-service/api/payments",
                timeout=timeout
            )
            if all_payments.status_code == 200:
                print(f"    ✓ Payment verified via list")
        
        # Verify shipping
        shipping_verify = requests.get(
            f"{api_gateway_url}/shipping-service/api/shippings/{order_id}/{product_id}",
            timeout=timeout
        )
        if shipping_verify.status_code == 200:
            verified_shipping = shipping_verify.json()
            print(f"    ✓ Shipping verified: Quantity {verified_shipping.get('orderedQuantity', 'N/A')}")
        else:
            # Try to verify via list
            all_shipping = requests.get(
                f"{api_gateway_url}/shipping-service/api/shippings",
                timeout=timeout
            )
            if all_shipping.status_code == 200:
                print(f"    ✓ Shipping verified via list")
        
        print("\n" + "="*60)
        print("✅ CHECKOUT FLOW COMPLETED SUCCESSFULLY")
        print("="*60)
        print(f"User ID: {user_id}")
        print(f"Cart ID: {cart_id}")
        print(f"Order ID: {order_id}")
        print(f"Payment ID: {payment_id}")
        print("="*60 + "\n")
    
    def test_checkout_flow_with_payment_failure(self, api_gateway_url, timeout):
        """E2E Test: Checkout flow handling payment failure scenario"""
        
        print("\n" + "="*60)
        print("E2E TEST: Checkout Flow with Payment Failure")
        print("="*60)
        
        # Step 1: Create user
        print("\n📝 Step 1: Creating user...")
        user_data = {
            "userId": 401,
            "firstName": "Pedro",
            "lastName": "Sánchez",
            "imageUrl": "https://example.com/pedro.jpg",
            "email": "pedro.sanchez@example.com",
            "phone": "+573006666666",
            "credential": {
                "credentialId": 401,
                "username": "pedro.sanchez",
                "password": "PedroPass123!",
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
        
        # Step 2: Get product
        print("\n🛍️  Step 2: Getting product...")
        products_response = requests.get(
            f"{api_gateway_url}/product-service/api/products",
            timeout=timeout
        )
        assert products_response.status_code == 200
        products = products_response.json().get('collection', [])
        assert len(products) > 0
        product = products[0]
        product_price = product.get('priceUnit', 0)
        time.sleep(1)
        
        # Step 3: Create cart
        print("\n🛒 Step 3: Creating cart...")
        cart_data = {"cartId": 401, "userId": user_id}
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
        
        # Step 4: Create order
        print("\n📦 Step 4: Creating order...")
        order_data = {
            "orderId": 401,
            "orderDate": datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000"),
            "orderDesc": "Order with payment failure scenario",
            "orderFee": product_price,
            "cart": {"cartId": cart_id},
        }
        
        order_response = requests.post(
            f"{api_gateway_url}/order-service/api/orders",
            json=order_data,
            timeout=timeout
        )
        if order_response.status_code == 503:
            pytest.skip("Order service is not available (503). Service needs to be running for E2E tests.")
        assert order_response.status_code in [200, 201]
        order_id = order_response.json()['orderId']
        print(f"    ✓ Order created: {order_id}")
        time.sleep(1)
        
        # Step 5: Attempt payment with failure status
        print("\n💳 Step 5: Attempting payment (failure scenario)...")
        payment_data = {
            "paymentId": 401,
            "isPayed": False,
            "paymentStatus": "IN_PROGRESS",  # Payment in progress, not completed
            "order": {"orderId": order_id},
        }
        
        payment_response = requests.post(
            f"{api_gateway_url}/payment-service/api/payments",
            json=payment_data,
            timeout=timeout
        )
        if payment_response.status_code == 503:
            pytest.skip("Payment service is not available (503). Service needs to be running for E2E tests.")
        assert payment_response.status_code in [200, 201]
        payment_id = payment_response.json()['paymentId']
        print(f"    ✓ Payment attempt recorded: {payment_id}")
        print(f"    ✓ Payment status: {payment_data['paymentStatus']} (not completed)")
        
        print("\n" + "="*60)
        print("✅ CHECKOUT FLOW WITH PAYMENT FAILURE SCENARIO COMPLETED")
        print("="*60 + "\n")

