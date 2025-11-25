"""
Stress Tests using Locust
Tests the system under extreme load conditions to find breaking points
"""
import time
import random
from datetime import datetime
from locust import HttpUser, task, between, events

class StressEcommerceUser(HttpUser):
    """Simulates a user under stress test conditions - more aggressive behavior"""
    wait_time = between(0.5, 1.5)  # Faster wait times for stress test
    
    def on_start(self):
        """Called when a user starts"""
        self.user_id = None
        self.product_ids = []
        self.order_id = None
        self.cart_id = None
        self.payment_id = None
        
    @task(10)
    def view_products(self):
        """View product catalog - high frequency in stress test"""
        with self.client.get(
            "/product-service/api/products",
            catch_response=True,
            name="STRESS: GET /products"
        ) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if 'collection' in data and data['collection']:
                        self.product_ids = [p['productId'] for p in data['collection'][:5]]
                        response.success()
                    else:
                        response.failure("No products in collection")
                except Exception as e:
                    response.failure(f"Failed to parse products: {e}")
            else:
                response.failure(f"Got status code {response.status_code}")
    
    @task(8)
    def view_product_details(self):
        """View specific product details"""
        if self.product_ids:
            product_id = random.choice(self.product_ids)
            self.client.get(
                f"/product-service/api/products/{product_id}",
                name="STRESS: GET /products/[id]"
            )
        else:
            self.client.get("/product-service/api/products/1", name="STRESS: GET /products/[id]")
    
    @task(6)
    def create_user(self):
        """Create a new user - high frequency for stress test"""
        user_id = random.randint(10000, 99999)
        user_data = {
            "userId": user_id,
            "firstName": f"StressUser{user_id}",
            "lastName": "Test",
            "imageUrl": "https://example.com/user.jpg",
            "email": f"stress{user_id}@example.com",
            "phone": f"+57300{user_id}",
            "credential": {
                "credentialId": user_id,
                "username": f"stress{user_id}",
                "password": "TestPass123!",
                "roleBasedAuthority": "ROLE_USER",
                "isEnabled": True,
                "isAccountNonExpired": True,
                "isAccountNonLocked": True,
                "isCredentialsNonExpired": True
            }
        }
        
        with self.client.post(
            "/user-service/api/users",
            json=user_data,
            catch_response=True,
            name="STRESS: POST /users"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    self.user_id = response.json().get('userId')
                    response.success()
                except:
                    pass
    
    @task(7)
    def create_cart(self):
        """Create a shopping cart - high frequency"""
        if not self.user_id:
            return
        
        cart_id = random.randint(50000, 99999)
        cart_data = {
            "cartId": cart_id,
            "userId": self.user_id,
        }
        
        with self.client.post(
            "/order-service/api/carts",
            json=cart_data,
            catch_response=True,
            name="STRESS: POST /carts"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    self.cart_id = data.get('cartId')
                    response.success()
                except:
                    response.failure("Failed to parse cart response")
    
    @task(6)
    def create_order(self):
        """Create an order - high frequency"""
        if not self.cart_id:
            return
        
        order_id = random.randint(20000, 49999)
        order_date = datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000")
        order_data = {
            "orderId": order_id,
            "orderDate": order_date,
            "orderDesc": f"Stress test order {order_id}",
            "orderFee": round(random.uniform(10.0, 500.0), 2),
            "cart": {"cartId": self.cart_id},
        }
        
        with self.client.post(
            "/order-service/api/orders",
            json=order_data,
            catch_response=True,
            name="STRESS: POST /orders"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    self.order_id = data.get('orderId')
                    response.success()
                except:
                    response.failure("Failed to parse order response")
    
    @task(5)
    def create_payment(self):
        """Create a payment - high frequency"""
        if not self.order_id:
            return
        
        payment_id = random.randint(70000, 99999)
        payment_data = {
            "paymentId": payment_id,
            "isPayed": random.choice([True, False]),
            "paymentStatus": random.choice(["COMPLETED", "IN_PROGRESS", "PENDING"]),
            "order": {"orderId": self.order_id},
        }
        
        with self.client.post(
            "/payment-service/api/payments",
            json=payment_data,
            catch_response=True,
            name="STRESS: POST /payments"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    self.payment_id = data.get('paymentId')
                    response.success()
                except:
                    response.failure("Failed to parse payment response")
    
    @task(4)
    def create_order_item(self):
        """Create an order item - high frequency"""
        if not self.order_id or not self.product_ids:
            return
        
        order_item_data = {
            "productId": random.choice(self.product_ids),
            "orderId": self.order_id,
            "orderedQuantity": random.randint(1, 5),
        }
        
        with self.client.post(
            "/shipping-service/api/shippings",
            json=order_item_data,
            catch_response=True,
            name="STRESS: POST /shippings"
        ) as response:
            if response.status_code in [200, 201]:
                response.success()
            else:
                response.failure(f"Got status code {response.status_code}")
    
    @task(3)
    def complete_purchase_flow(self):
        """E2E: Complete purchase flow under stress"""
        if not self.user_id or not self.product_ids:
            return
        
        # Rapid fire through the flow
        cart_id = random.randint(80000, 99999)
        cart_data = {"cartId": cart_id, "userId": self.user_id}
        
        cart_response = self.client.post(
            "/order-service/api/carts",
            json=cart_data,
            catch_response=True,
            name="STRESS: E2E POST /carts"
        )
        
        if cart_response.status_code not in [200, 201]:
            return
        
        order_id = random.randint(30000, 49999)
        order_date = datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000")
        order_data = {
            "orderId": order_id,
            "orderDate": order_date,
            "orderDesc": f"Stress E2E order {order_id}",
            "orderFee": round(random.uniform(50.0, 300.0), 2),
            "cart": {"cartId": cart_id},
        }
        
        order_response = self.client.post(
            "/order-service/api/orders",
            json=order_data,
            catch_response=True,
            name="STRESS: E2E POST /orders"
        )
        
        if order_response.status_code not in [200, 201]:
            return
        
        payment_id = random.randint(80000, 99999)
        payment_data = {
            "paymentId": payment_id,
            "isPayed": True,
            "paymentStatus": "COMPLETED",
            "order": {"orderId": order_id},
        }
        
        payment_response = self.client.post(
            "/payment-service/api/payments",
            json=payment_data,
            catch_response=True,
            name="STRESS: E2E POST /payments"
        )
        
        if payment_response.status_code not in [200, 201]:
            return
        
        order_item_data = {
            "productId": random.choice(self.product_ids),
            "orderId": order_id,
            "orderedQuantity": random.randint(1, 3),
        }
        
        shipping_response = self.client.post(
            "/shipping-service/api/shippings",
            json=order_item_data,
            catch_response=True,
            name="STRESS: E2E POST /shippings"
        )
        
        if shipping_response.status_code in [200, 201]:
            shipping_response.success()


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when the stress test starts"""
    print("=" * 60)
    print("🔥 Starting STRESS Tests (Extreme Load)")
    print(f"   Target: {environment.host}")
    print("   Warning: This test applies extreme load to find breaking points")
    print("=" * 60)


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when the stress test stops"""
    print("=" * 60)
    print("✅ Stress Tests Completed")
    print("   Review results for system breaking points and degradation")
    print("=" * 60)

