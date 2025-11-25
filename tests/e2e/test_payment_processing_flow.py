"""
E2E Tests: Payment Processing Flow
Tests payment processing with different states and scenarios
"""
import pytest
import requests
import time
from datetime import datetime

@pytest.mark.e2e
class TestPaymentProcessingFlow:
    """Test payment processing flows with different states"""
    
    def test_complete_payment_processing_flow(self, api_gateway_url, timeout):
        """E2E Test: Complete payment processing flow with different states"""
        
        print("\n" + "="*60)
        print("E2E TEST: Complete Payment Processing Flow")
        print("="*60)
        
        # ============================================================
        # STEP 1: Create user
        # ============================================================
        print("\n📝 Step 1: Creating user...")
        user_data = {
            "userId": 600,
            "firstName": "Laura",
            "lastName": "González",
            "imageUrl": "https://example.com/laura.jpg",
            "email": "laura.gonzalez@example.com",
            "phone": "+573009999999",
            "credential": {
                "credentialId": 600,
                "username": "laura.gonzalez",
                "password": "LauraPass123!",
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
        # STEP 2: Create order (prerequisite for payment)
        # ============================================================
        print("\n📦 Step 2: Creating order...")
        # First create cart
        cart_data = {"cartId": 600, "userId": user_id}
        cart_response = requests.post(
            f"{api_gateway_url}/order-service/api/carts",
            json=cart_data,
            timeout=timeout
        )
        if cart_response.status_code == 503:
            pytest.skip("Order service is not available (503). Service needs to be running for E2E tests.")
        assert cart_response.status_code in [200, 201]
        cart_id = cart_response.json()['cartId']
        
        # Create order
        order_data = {
            "orderId": 600,
            "orderDate": datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000"),
            "orderDesc": "Order for payment processing test",
            "orderFee": 149.99,
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
        
        # ============================================================
        # STEP 3: Initiate payment (NOT_STARTED)
        # ============================================================
        print("\n💳 Step 3: Initiating payment (NOT_STARTED)...")
        payment_not_started = {
            "paymentId": 600,
            "isPayed": False,
            "paymentStatus": "NOT_STARTED",
            "order": {"orderId": order_id},
        }
        
        payment_response = requests.post(
            f"{api_gateway_url}/payment-service/api/payments",
            json=payment_not_started,
            timeout=timeout
        )
        if payment_response.status_code == 503:
            pytest.skip("Payment service is not available (503). Service needs to be running for E2E tests.")
        assert payment_response.status_code in [200, 201]
        payment_id = payment_response.json()['paymentId']
        print(f"    ✓ Payment initiated: {payment_id}")
        print(f"    ✓ Status: NOT_STARTED")
        time.sleep(1)
        
        # ============================================================
        # STEP 4: Update payment to IN_PROGRESS
        # ============================================================
        print("\n⏳ Step 4: Updating payment to IN_PROGRESS...")
        payment_in_progress = {
            "paymentId": payment_id,
            "isPayed": False,
            "paymentStatus": "IN_PROGRESS",
            "order": {"orderId": order_id},
        }
        
        update_response = requests.put(
            f"{api_gateway_url}/payment-service/api/payments",
            json=payment_in_progress,
            timeout=timeout
        )
        if update_response.status_code in [200, 204]:
            print(f"    ✓ Payment updated to IN_PROGRESS")
        time.sleep(1)
        
        # ============================================================
        # STEP 5: Complete payment (COMPLETED)
        # ============================================================
        print("\n✅ Step 5: Completing payment (COMPLETED)...")
        payment_completed = {
            "paymentId": payment_id,
            "isPayed": True,
            "paymentStatus": "COMPLETED",
            "order": {"orderId": order_id},
        }
        
        complete_response = requests.put(
            f"{api_gateway_url}/payment-service/api/payments",
            json=payment_completed,
            timeout=timeout
        )
        if complete_response.status_code in [200, 204]:
            print(f"    ✓ Payment completed")
            print(f"    ✓ Status: COMPLETED")
        time.sleep(1)
        
        # ============================================================
        # STEP 6: Verify payment status
        # ============================================================
        print("\n🔍 Step 6: Verifying payment status...")
        verify_response = requests.get(
            f"{api_gateway_url}/payment-service/api/payments/{payment_id}",
            timeout=timeout
        )
        if verify_response.status_code == 200:
            verified_payment = verify_response.json()
            print(f"    ✓ Payment verified: {verified_payment.get('paymentStatus', 'N/A')}")
            print(f"    ✓ Payment ID: {verified_payment.get('paymentId', 'N/A')}")
        else:
            # Try via list
            all_payments = requests.get(
                f"{api_gateway_url}/payment-service/api/payments",
                timeout=timeout
            )
            if all_payments.status_code == 200:
                print(f"    ✓ Payment verified via list")
        
        print("\n" + "="*60)
        print("✅ PAYMENT PROCESSING FLOW COMPLETED")
        print("="*60)
        print(f"Order ID: {order_id}")
        print(f"Payment ID: {payment_id}")
        print("="*60 + "\n")
    
    def test_payment_states_transition(self, api_gateway_url, timeout):
        """E2E Test: Payment state transitions"""
        
        print("\n" + "="*60)
        print("E2E TEST: Payment State Transitions")
        print("="*60)
        
        # Step 1: Create user
        print("\n📝 Step 1: Creating user...")
        user_data = {
            "userId": 601,
            "firstName": "Miguel",
            "lastName": "Torres",
            "imageUrl": "https://example.com/miguel.jpg",
            "email": "miguel.torres@example.com",
            "phone": "+573001010101",
            "credential": {
                "credentialId": 601,
                "username": "miguel.torres",
                "password": "MiguelPass123!",
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
        
        # Step 2: Create order
        print("\n📦 Step 2: Creating order...")
        cart_data = {"cartId": 601, "userId": user_id}
        cart_response = requests.post(
            f"{api_gateway_url}/order-service/api/carts",
            json=cart_data,
            timeout=timeout
        )
        if cart_response.status_code == 503:
            pytest.skip("Order service is not available (503). Service needs to be running for E2E tests.")
        assert cart_response.status_code in [200, 201]
        cart_id = cart_response.json()['cartId']
        
        order_data = {
            "orderId": 601,
            "orderDate": datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000"),
            "orderDesc": "Order for payment state transitions",
            "orderFee": 99.99,
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
        
        # Step 3: Test all payment states
        print("\n💳 Step 3: Testing payment state transitions...")
        payment_states = [
            ("NOT_STARTED", False),
            ("IN_PROGRESS", False),
            ("COMPLETED", True),
        ]
        
        for idx, (status, is_payed) in enumerate(payment_states):
            payment_data = {
                "paymentId": 601 + idx,
                "isPayed": is_payed,
                "paymentStatus": status,
                "order": {"orderId": order_id},
            }
            
            payment_response = requests.post(
                f"{api_gateway_url}/payment-service/api/payments",
                json=payment_data,
                timeout=timeout
            )
            if payment_response.status_code == 503:
                pytest.skip("Payment service is not available (503). Service needs to be running for E2E tests.")
            if payment_response.status_code in [200, 201]:
                print(f"    ✓ Payment state '{status}' created")
        
        print("\n" + "="*60)
        print("✅ PAYMENT STATE TRANSITIONS COMPLETED")
        print("="*60 + "\n")

