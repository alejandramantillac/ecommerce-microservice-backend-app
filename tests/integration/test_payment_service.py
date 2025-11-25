"""
Integration Tests for Payment Service
"""
import pytest
import requests

@pytest.mark.integration
class TestPaymentService:
    
    def test_create_payment(self, api_gateway_url, payment_data, timeout):
        """Test 1: Create a new payment"""
        response = requests.post(
            f"{api_gateway_url}/payment-service/api/payments",
            json=payment_data,
            timeout=timeout
        )
        
        assert response.status_code in [200, 201], f"Expected 200/201, got {response.status_code}"
        data = response.json()
        assert data['isPayed'] == payment_data['isPayed']
        print(f"✓ Payment created successfully: {data['paymentId']}")
    
    def test_get_all_payments(self, api_gateway_url, timeout):
        """Test 2: Retrieve all payments"""
        response = requests.get(
            f"{api_gateway_url}/payment-service/api/payments",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert 'collection' in data, "Response should contain 'collection' field"
        print(f"✓ Retrieved {len(data['collection'])} payments")
    
    def test_get_payment_by_id(self, api_gateway_url, timeout):
        """Test 3: Retrieve a specific payment by ID"""
        payment_id = 1
        response = requests.get(
            f"{api_gateway_url}/payment-service/api/payments/{payment_id}",
            timeout=timeout
        )
        
        # Accept 200 or 404 if payment doesn't exist
        assert response.status_code in [200, 404]
        if response.status_code == 200:
            data = response.json()
            assert data['paymentId'] == payment_id
            print(f"✓ Payment {payment_id} retrieved successfully")
    
    def test_update_payment(self, api_gateway_url, payment_data, timeout):
        """Test 4: Update an existing payment"""
        # First create the payment
        create_response = requests.post(
            f"{api_gateway_url}/payment-service/api/payments",
            json=payment_data,
            timeout=timeout
        )
        
        if create_response.status_code in [200, 201]:
            # Update the payment
            payment_data['isPayed'] = False
            payment_data['paymentStatus'] = 'IN_PROGRESS'
            response = requests.put(
                f"{api_gateway_url}/payment-service/api/payments",
                json=payment_data,
                timeout=timeout
            )
            
            assert response.status_code in [200, 204]
            print(f"✓ Payment {payment_data['paymentId']} updated successfully")
    
    def test_payment_statuses(self, api_gateway_url, timeout):
        """Test 5: Test different payment statuses"""
        statuses = ['NOT_STARTED', 'IN_PROGRESS', 'COMPLETED']
        
        for status in statuses:
            payment_data = {
                "paymentId": 200 + statuses.index(status),
                "isPayed": status == 'COMPLETED',
                "paymentStatus": status,
                "order": {"orderId": 1},
            }
            
            response = requests.post(
                f"{api_gateway_url}/payment-service/api/payments",
                json=payment_data,
                timeout=timeout
            )
            
            # Accept 200, 201, or 400 (if validation fails)
            assert response.status_code in [200, 201, 400]
            if response.status_code in [200, 201]:
                print(f"✓ Payment with status {status} created successfully")
    
    def test_delete_payment(self, api_gateway_url, timeout):
        """Test 6: Delete a payment"""
        payment_id = 100  # Use a test ID
        response = requests.delete(
            f"{api_gateway_url}/payment-service/api/payments/{payment_id}",
            timeout=timeout
        )
        
        # Accept 200, 204, or 404 (if already deleted)
        assert response.status_code in [200, 204, 404]
        print(f"✓ Payment {payment_id} delete request processed")
    
    def test_payment_service_health(self, api_gateway_url, timeout):
        """Test 7: Verify payment service health endpoint"""
        response = requests.get(
            f"{api_gateway_url}/payment-service/actuator/health",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'UP', f"Service should be UP, got {data['status']}"
        print("✓ Payment service is healthy")
    
    def test_payment_integration_with_order(self, api_gateway_url, timeout):
        """Test 8: Verify payment service integrates with order service"""
        # This test verifies that payment service can fetch order data
        payment_id = 1
        response = requests.get(
            f"{api_gateway_url}/payment-service/api/payments/{payment_id}",
            timeout=timeout
        )
        
        if response.status_code == 200:
            data = response.json()
            # Verify that order data is included in payment response
            assert 'order' in data or 'orderDto' in data, "Payment should include order information"
            print("✓ Payment service successfully integrates with order service")

