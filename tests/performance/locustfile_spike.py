"""
Spike Tests using Locust
Tests the system's ability to handle sudden spikes in traffic
"""
import time
import random
from datetime import datetime
from locust import HttpUser, task, between, events

class SpikeEcommerceUser(HttpUser):
    """Simulates a user during a traffic spike - very aggressive behavior"""
    wait_time = between(0.1, 0.5)  # Very fast wait times for spike test
    
    def on_start(self):
        """Called when a user starts"""
        self.user_id = None
        self.product_ids = []
        self.order_id = None
        self.cart_id = None
        
    @task(15)
    def view_products(self):
        """View product catalog - very high frequency during spike"""
        with self.client.get(
            "/product-service/api/products",
            catch_response=True,
            name="SPIKE: GET /products"
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
    
    @task(12)
    def view_product_details(self):
        """View specific product details"""
        if self.product_ids:
            product_id = random.choice(self.product_ids)
            self.client.get(
                f"/product-service/api/products/{product_id}",
                name="SPIKE: GET /products/[id]"
            )
        else:
            self.client.get("/product-service/api/products/1", name="SPIKE: GET /products/[id]")
    
    @task(10)
    def create_user(self):
        """Create a new user - very high frequency"""
        user_id = random.randint(100000, 999999)
        user_data = {
            "userId": user_id,
            "firstName": f"SpikeUser{user_id}",
            "lastName": "Test",
            "imageUrl": "https://example.com/user.jpg",
            "email": f"spike{user_id}@example.com",
            "phone": f"+5730{user_id}",
            "credential": {
                "credentialId": user_id,
                "username": f"spike{user_id}",
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
            name="SPIKE: POST /users"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    self.user_id = response.json().get('userId')
                    response.success()
                except:
                    pass
    
    @task(10)
    def create_cart(self):
        """Create a shopping cart - very high frequency"""
        if not self.user_id:
            return
        
        cart_id = random.randint(500000, 999999)
        cart_data = {
            "cartId": cart_id,
            "userId": self.user_id,
        }
        
        with self.client.post(
            "/order-service/api/carts",
            json=cart_data,
            catch_response=True,
            name="SPIKE: POST /carts"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    self.cart_id = data.get('cartId')
                    response.success()
                except:
                    response.failure("Failed to parse cart response")
    
    @task(8)
    def create_order(self):
        """Create an order - very high frequency"""
        if not self.cart_id:
            return
        
        order_id = random.randint(200000, 499999)
        order_date = datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000")
        order_data = {
            "orderId": order_id,
            "orderDate": order_date,
            "orderDesc": f"Spike test order {order_id}",
            "orderFee": round(random.uniform(10.0, 500.0), 2),
            "cart": {"cartId": self.cart_id},
        }
        
        with self.client.post(
            "/order-service/api/orders",
            json=order_data,
            catch_response=True,
            name="SPIKE: POST /orders"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    self.order_id = data.get('orderId')
                    response.success()
                except:
                    response.failure("Failed to parse order response")
    
    @task(6)
    def create_payment(self):
        """Create a payment - very high frequency"""
        if not self.order_id:
            return
        
        payment_id = random.randint(700000, 999999)
        payment_data = {
            "paymentId": payment_id,
            "isPayed": True,
            "paymentStatus": "COMPLETED",
            "order": {"orderId": self.order_id},
        }
        
        with self.client.post(
            "/payment-service/api/payments",
            json=payment_data,
            catch_response=True,
            name="SPIKE: POST /payments"
        ) as response:
            if response.status_code in [200, 201]:
                response.success()
    
    @task(5)
    def health_check(self):
        """Check API Gateway health - monitor during spike"""
        self.client.get("/actuator/health", name="SPIKE: GET /health")


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when the spike test starts"""
    print("=" * 60)
    print("⚡ Starting SPIKE Tests (Sudden Traffic Surge)")
    print(f"   Target: {environment.host}")
    print("   Warning: This test simulates sudden traffic spikes")
    print("   Monitor system recovery and degradation")
    print("=" * 60)


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when the spike test stops"""
    print("=" * 60)
    print("✅ Spike Tests Completed")
    print("   Review results for system recovery and resilience")
    print("=" * 60)

