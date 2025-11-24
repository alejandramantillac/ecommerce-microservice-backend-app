"""
Endurance Tests using Locust
Tests the system's ability to handle sustained load over extended periods
"""
import time
import random
from datetime import datetime
from locust import HttpUser, task, between, events

class EnduranceEcommerceUser(HttpUser):
    """Simulates a user during endurance test - realistic, sustained behavior"""
    wait_time = between(2, 5)  # More realistic wait times for endurance test
    
    def on_start(self):
        """Called when a user starts"""
        self.user_id = None
        self.product_ids = []
        self.order_id = None
        self.cart_id = None
        self.payment_id = None
        
    @task(5)
    def view_products(self):
        """View product catalog - sustained frequency"""
        with self.client.get(
            "/product-service/api/products",
            catch_response=True,
            name="ENDURANCE: GET /products"
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
    
    @task(3)
    def view_product_details(self):
        """View specific product details"""
        if self.product_ids:
            product_id = random.choice(self.product_ids)
            self.client.get(
                f"/product-service/api/products/{product_id}",
                name="ENDURANCE: GET /products/[id]"
            )
        else:
            self.client.get("/product-service/api/products/1", name="ENDURANCE: GET /products/[id]")
    
    @task(2)
    def view_categories(self):
        """View product categories"""
        self.client.get("/product-service/api/categories", name="ENDURANCE: GET /categories")
    
    @task(2)
    def create_user(self):
        """Create a new user - sustained frequency"""
        user_id = random.randint(200000, 999999)
        user_data = {
            "userId": user_id,
            "firstName": f"EnduranceUser{user_id}",
            "lastName": "Test",
            "imageUrl": "https://example.com/user.jpg",
            "email": f"endurance{user_id}@example.com",
            "phone": f"+5730{user_id}",
            "credential": {
                "credentialId": user_id,
                "username": f"endurance{user_id}",
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
            name="ENDURANCE: POST /users"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    self.user_id = response.json().get('userId')
                    response.success()
                except:
                    pass
    
    @task(2)
    def view_users(self):
        """View all users"""
        self.client.get("/user-service/api/users", name="ENDURANCE: GET /users")
    
    @task(3)
    def create_cart(self):
        """Create a shopping cart - sustained frequency"""
        if not self.user_id:
            return
        
        cart_id = random.randint(600000, 999999)
        cart_data = {
            "cartId": cart_id,
            "userId": self.user_id,
        }
        
        with self.client.post(
            "/order-service/api/carts",
            json=cart_data,
            catch_response=True,
            name="ENDURANCE: POST /carts"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    self.cart_id = data.get('cartId')
                    response.success()
                except:
                    response.failure("Failed to parse cart response")
    
    @task(2)
    def view_carts(self):
        """View all carts"""
        self.client.get("/order-service/api/carts", name="ENDURANCE: GET /carts")
    
    @task(3)
    def create_order(self):
        """Create an order - sustained frequency"""
        if not self.cart_id:
            return
        
        order_id = random.randint(300000, 599999)
        order_date = datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000")
        order_data = {
            "orderId": order_id,
            "orderDate": order_date,
            "orderDesc": f"Endurance test order {order_id}",
            "orderFee": round(random.uniform(10.0, 500.0), 2),
            "cart": {"cartId": self.cart_id},
        }
        
        with self.client.post(
            "/order-service/api/orders",
            json=order_data,
            catch_response=True,
            name="ENDURANCE: POST /orders"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    self.order_id = data.get('orderId')
                    response.success()
                except:
                    response.failure("Failed to parse order response")
    
    @task(2)
    def view_orders(self):
        """View all orders"""
        self.client.get("/order-service/api/orders", name="ENDURANCE: GET /orders")
    
    @task(2)
    def create_payment(self):
        """Create a payment - sustained frequency"""
        if not self.order_id:
            return
        
        payment_id = random.randint(800000, 999999)
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
            name="ENDURANCE: POST /payments"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    self.payment_id = data.get('paymentId')
                    response.success()
                except:
                    response.failure("Failed to parse payment response")
    
    @task(2)
    def view_payments(self):
        """View all payments"""
        self.client.get("/payment-service/api/payments", name="ENDURANCE: GET /payments")
    
    @task(2)
    def create_order_item(self):
        """Create an order item - sustained frequency"""
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
            name="ENDURANCE: POST /shippings"
        ) as response:
            if response.status_code in [200, 201]:
                response.success()
            else:
                response.failure(f"Got status code {response.status_code}")
    
    @task(1)
    def complete_purchase_flow(self):
        """E2E: Complete purchase flow - sustained frequency"""
        if not self.user_id or not self.product_ids:
            return
        
        cart_id = random.randint(800000, 999999)
        cart_data = {"cartId": cart_id, "userId": self.user_id}
        
        cart_response = self.client.post(
            "/order-service/api/carts",
            json=cart_data,
            catch_response=True,
            name="ENDURANCE: E2E POST /carts"
        )
        
        if cart_response.status_code not in [200, 201]:
            return
        
        order_id = random.randint(400000, 599999)
        order_date = datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000")
        order_data = {
            "orderId": order_id,
            "orderDate": order_date,
            "orderDesc": f"Endurance E2E order {order_id}",
            "orderFee": round(random.uniform(50.0, 300.0), 2),
            "cart": {"cartId": cart_id},
        }
        
        order_response = self.client.post(
            "/order-service/api/orders",
            json=order_data,
            catch_response=True,
            name="ENDURANCE: E2E POST /orders"
        )
        
        if order_response.status_code not in [200, 201]:
            return
        
        payment_id = random.randint(900000, 999999)
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
            name="ENDURANCE: E2E POST /payments"
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
            name="ENDURANCE: E2E POST /shippings"
        )
        
        if shipping_response.status_code in [200, 201]:
            shipping_response.success()
    
    @task(1)
    def health_check(self):
        """Check API Gateway health - monitor during endurance"""
        self.client.get("/actuator/health", name="ENDURANCE: GET /health")


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when the endurance test starts"""
    print("=" * 60)
    print("⏱️  Starting ENDURANCE Tests (Sustained Load)")
    print(f"   Target: {environment.host}")
    print("   This test runs for extended periods to detect memory leaks")
    print("   and performance degradation over time")
    print("=" * 60)


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when the endurance test stops"""
    print("=" * 60)
    print("✅ Endurance Tests Completed")
    print("   Review results for memory leaks and performance degradation")
    print("=" * 60)

