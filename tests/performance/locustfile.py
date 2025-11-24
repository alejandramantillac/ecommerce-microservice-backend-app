"""
Performance Tests using Locust
"""
import time
import random
from datetime import datetime
from locust import HttpUser, task, between, events

class EcommerceUser(HttpUser):
    """Simulates a user interacting with the e-commerce platform"""
    wait_time = between(1, 3)
    
    def on_start(self):
        """Called when a user starts"""
        self.user_id = None
        self.product_ids = []
        self.order_id = None
        self.cart_id = None
        self.payment_id = None
        self.order_item_ids = []
        
    @task(5)
    def view_products(self):
        """View product catalog (most common action)"""
        with self.client.get(
            "/product-service/api/products",
            catch_response=True,
            name="GET /products"
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
                name="GET /products/[id]"
            )
        else:
            # Fallback to product ID 1
            self.client.get("/product-service/api/products/1", name="GET /products/[id]")
    
    @task(2)
    def view_categories(self):
        """View product categories"""
        self.client.get("/product-service/api/categories", name="GET /categories")
    
    @task(2)
    def create_user(self):
        """Create a new user (registration)"""
        user_id = random.randint(1000, 9999)
        user_data = {
            "userId": user_id,
            "firstName": f"User{user_id}",
            "lastName": "Test",
            "imageUrl": "https://example.com/user.jpg",
            "email": f"user{user_id}@example.com",
            "phone": f"+5730099{user_id}",
            "credential": {
                "credentialId": user_id,
                "username": f"user{user_id}",
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
            name="POST /users (register)"
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
        self.client.get("/user-service/api/users", name="GET /users")
    
    @task(1)
    def view_user_profile(self):
        """View specific user profile"""
        if self.user_id:
            self.client.get(
                f"/user-service/api/users/{self.user_id}",
                name="GET /users/[id]"
            )
    
    @task(1)
    def view_favourites(self):
        """View all favourites"""
        self.client.get("/favourite-service/api/favourites", name="GET /favourites")
    
    @task(1)
    def add_to_favourites(self):
        """Add product to favourites"""
        if self.user_id and self.product_ids:
            fav_id = random.randint(6000, 9999)
            current_datetime = datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000")
            fav_data = {
                "userId": self.user_id,
                "productId": random.choice(self.product_ids),
                "likeDate": current_datetime,
                "user": {"userId": self.user_id},
                "product": {"productId": random.choice(self.product_ids)}
            }
            self.client.post(
                "/favourite-service/api/favourites",
                json=fav_data,
                name="POST /favourites"
            )
    
    # ============================================================
    # ORDER SERVICE TASKS
    # ============================================================
    
    @task(3)
    def create_cart(self):
        """Create a shopping cart"""
        if not self.user_id:
            return  # Need user first
        
        cart_id = random.randint(5000, 9999)
        cart_data = {
            "cartId": cart_id,
            "userId": self.user_id,
        }
        
        with self.client.post(
            "/order-service/api/carts",
            json=cart_data,
            catch_response=True,
            name="POST /carts"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    self.cart_id = data.get('cartId')
                    response.success()
                except:
                    response.failure("Failed to parse cart response")
            else:
                response.failure(f"Got status code {response.status_code}")
    
    @task(2)
    def view_carts(self):
        """View all carts"""
        self.client.get("/order-service/api/carts", name="GET /carts")
    
    @task(2)
    def view_cart_by_id(self):
        """View specific cart"""
        if self.cart_id:
            self.client.get(
                f"/order-service/api/carts/{self.cart_id}",
                name="GET /carts/[id]"
            )
    
    @task(3)
    def create_order(self):
        """Create an order from cart"""
        if not self.cart_id:
            return  # Need cart first
        
        order_id = random.randint(2000, 4999)
        order_date = datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000")
        order_data = {
            "orderId": order_id,
            "orderDate": order_date,
            "orderDesc": f"Performance test order {order_id}",
            "orderFee": round(random.uniform(10.0, 500.0), 2),
            "cart": {"cartId": self.cart_id},
        }
        
        with self.client.post(
            "/order-service/api/orders",
            json=order_data,
            catch_response=True,
            name="POST /orders"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    self.order_id = data.get('orderId')
                    response.success()
                except:
                    response.failure("Failed to parse order response")
            else:
                response.failure(f"Got status code {response.status_code}")
    
    @task(2)
    def view_orders(self):
        """View all orders"""
        self.client.get("/order-service/api/orders", name="GET /orders")
    
    @task(1)
    def view_order_by_id(self):
        """View specific order"""
        if self.order_id:
            self.client.get(
                f"/order-service/api/orders/{self.order_id}",
                name="GET /orders/[id]"
            )
    
    # ============================================================
    # PAYMENT SERVICE TASKS
    # ============================================================
    
    @task(3)
    def create_payment(self):
        """Create a payment for an order"""
        if not self.order_id:
            return  # Need order first
        
        payment_id = random.randint(7000, 9999)
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
            name="POST /payments"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    self.payment_id = data.get('paymentId')
                    response.success()
                except:
                    response.failure("Failed to parse payment response")
            else:
                response.failure(f"Got status code {response.status_code}")
    
    @task(2)
    def view_payments(self):
        """View all payments"""
        self.client.get("/payment-service/api/payments", name="GET /payments")
    
    @task(1)
    def view_payment_by_id(self):
        """View specific payment"""
        if self.payment_id:
            self.client.get(
                f"/payment-service/api/payments/{self.payment_id}",
                name="GET /payments/[id]"
            )
    
    # ============================================================
    # SHIPPING SERVICE TASKS
    # ============================================================
    
    @task(2)
    def create_order_item(self):
        """Create an order item (shipping)"""
        if not self.order_id or not self.product_ids:
            return  # Need order and products first
        
        order_item_data = {
            "productId": random.choice(self.product_ids),
            "orderId": self.order_id,
            "orderedQuantity": random.randint(1, 5),
        }
        
        with self.client.post(
            "/shipping-service/api/shippings",
            json=order_item_data,
            catch_response=True,
            name="POST /shippings"
        ) as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    item_key = f"{data.get('orderId')}_{data.get('productId')}"
                    if item_key not in self.order_item_ids:
                        self.order_item_ids.append(item_key)
                    response.success()
                except:
                    response.failure("Failed to parse order item response")
            else:
                response.failure(f"Got status code {response.status_code}")
    
    @task(2)
    def view_order_items(self):
        """View all order items"""
        self.client.get("/shipping-service/api/shippings", name="GET /shippings")
    
    @task(1)
    def view_order_item_by_id(self):
        """View specific order item"""
        if self.order_id and self.product_ids:
            product_id = random.choice(self.product_ids)
            self.client.get(
                f"/shipping-service/api/shippings/{self.order_id}/{product_id}",
                name="GET /shippings/[orderId]/[productId]"
            )
    
    # ============================================================
    # E2E FLOW TASKS (Complete Business Flows Under Load)
    # ============================================================
    
    @task(2)
    def complete_purchase_flow(self):
        """E2E: Complete purchase flow (Product → Cart → Order → Payment → Shipping)"""
        if not self.user_id or not self.product_ids:
            return  # Need user and products first
        
        # Step 1: Create cart
        cart_id = random.randint(8000, 9999)
        cart_data = {"cartId": cart_id, "userId": self.user_id}
        
        cart_response = self.client.post(
            "/order-service/api/carts",
            json=cart_data,
            catch_response=True,
            name="E2E: POST /carts (purchase flow)"
        )
        
        if cart_response.status_code not in [200, 201]:
            cart_response.failure(f"Cart creation failed: {cart_response.status_code}")
            return
        
        try:
            cart_data_resp = cart_response.json()
            created_cart_id = cart_data_resp.get('cartId')
        except:
            cart_response.failure("Failed to parse cart response")
            return
        
        cart_response.success()
        
        # Step 2: Create order
        order_id = random.randint(3000, 4999)
        order_date = datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000")
        selected_product_id = random.choice(self.product_ids)
        order_data = {
            "orderId": order_id,
            "orderDate": order_date,
            "orderDesc": f"E2E purchase flow order {order_id}",
            "orderFee": round(random.uniform(50.0, 300.0), 2),
            "cart": {"cartId": created_cart_id},
        }
        
        order_response = self.client.post(
            "/order-service/api/orders",
            json=order_data,
            catch_response=True,
            name="E2E: POST /orders (purchase flow)"
        )
        
        if order_response.status_code not in [200, 201]:
            order_response.failure(f"Order creation failed: {order_response.status_code}")
            return
        
        order_response.success()
        
        # Step 3: Process payment
        payment_id = random.randint(8000, 9999)
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
            name="E2E: POST /payments (purchase flow)"
        )
        
        if payment_response.status_code not in [200, 201]:
            payment_response.failure(f"Payment failed: {payment_response.status_code}")
            return
        
        payment_response.success()
        
        # Step 4: Create shipping/order item
        order_item_data = {
            "productId": selected_product_id,
            "orderId": order_id,
            "orderedQuantity": random.randint(1, 3),
        }
        
        shipping_response = self.client.post(
            "/shipping-service/api/shippings",
            json=order_item_data,
            catch_response=True,
            name="E2E: POST /shippings (purchase flow)"
        )
        
        if shipping_response.status_code not in [200, 201]:
            shipping_response.failure(f"Shipping failed: {shipping_response.status_code}")
            return
        
        shipping_response.success()
    
    @task(1)
    def checkout_flow(self):
        """E2E: Checkout flow (Cart Review → Order → Payment → Confirmation)"""
        if not self.user_id or not self.product_ids:
            return
        
        # Step 1: Review cart (if exists) or create new
        if not self.cart_id:
            cart_id = random.randint(8000, 9999)
            cart_data = {"cartId": cart_id, "userId": self.user_id}
            cart_response = self.client.post(
                "/order-service/api/carts",
                json=cart_data,
                catch_response=True,
                name="E2E: POST /carts (checkout flow)"
            )
            if cart_response.status_code in [200, 201]:
                try:
                    self.cart_id = cart_response.json().get('cartId')
                    cart_response.success()
                except:
                    cart_response.failure("Failed to parse cart")
                    return
            else:
                cart_response.failure(f"Cart creation failed: {cart_response.status_code}")
                return
        
        # Step 2: Create order (checkout)
        order_id = random.randint(4000, 4999)
        order_date = datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000")
        order_data = {
            "orderId": order_id,
            "orderDate": order_date,
            "orderDesc": f"Checkout flow order {order_id}",
            "orderFee": round(random.uniform(100.0, 400.0), 2),
            "cart": {"cartId": self.cart_id},
        }
        
        order_response = self.client.post(
            "/order-service/api/orders",
            json=order_data,
            catch_response=True,
            name="E2E: POST /orders (checkout flow)"
        )
        
        if order_response.status_code not in [200, 201]:
            order_response.failure(f"Order creation failed: {order_response.status_code}")
            return
        
        order_response.success()
        
        # Step 3: Process payment
        payment_id = random.randint(8000, 9999)
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
            name="E2E: POST /payments (checkout flow)"
        )
        
        if payment_response.status_code not in [200, 201]:
            payment_response.failure(f"Payment failed: {payment_response.status_code}")
            return
        
        payment_response.success()
    
    @task(1)
    def health_check(self):
        """Check API Gateway health"""
        self.client.get("/actuator/health", name="GET /health")


# SLA Thresholds (in milliseconds)
SLA_THRESHOLDS = {
    "GET /products": {"p95": 500, "p99": 1000},
    "GET /products/[id]": {"p95": 400, "p99": 800},
    "GET /categories": {"p95": 400, "p99": 800},
    "POST /users (register)": {"p95": 600, "p99": 1200},
    "GET /users": {"p95": 500, "p99": 1000},
    "POST /carts": {"p95": 600, "p99": 1200},
    "GET /carts": {"p95": 500, "p99": 1000},
    "POST /orders": {"p95": 700, "p99": 1500},
    "GET /orders": {"p95": 500, "p99": 1000},
    "POST /payments": {"p95": 800, "p99": 2000},
    "GET /payments": {"p95": 500, "p99": 1000},
    "POST /shippings": {"p95": 700, "p99": 1500},
    "GET /shippings": {"p95": 500, "p99": 1000},
    "GET /health": {"p95": 200, "p99": 400},
    "E2E: POST /carts (purchase flow)": {"p95": 1000, "p99": 2000},
    "E2E: POST /orders (purchase flow)": {"p95": 1000, "p99": 2000},
    "E2E: POST /payments (purchase flow)": {"p95": 1200, "p99": 2500},
    "E2E: POST /shippings (purchase flow)": {"p95": 1000, "p99": 2000},
}


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when the test starts"""
    print("=" * 60)
    print("🚀 Starting E-commerce Performance Tests")
    print(f"   Target: {environment.host}")
    print("   Services: product, user, favourite, order, payment, shipping")
    print("   E2E Flows: Complete Purchase, Checkout")
    print("=" * 60)


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when the test stops"""
    print("=" * 60)
    print("✅ Performance Tests Completed")
    print("=" * 60)
    
    # Validate SLA thresholds
    stats = environment.stats
    sla_violations = []
    
    for name, entry in stats.entries.items():
        if name in SLA_THRESHOLDS:
            thresholds = SLA_THRESHOLDS[name]
            p95_ms = entry.get_response_time_percentile(0.95)
            p99_ms = entry.get_response_time_percentile(0.99)
            
            if p95_ms > thresholds["p95"]:
                sla_violations.append(f"{name}: P95 {p95_ms:.0f}ms > {thresholds['p95']}ms")
            if p99_ms > thresholds["p99"]:
                sla_violations.append(f"{name}: P99 {p99_ms:.0f}ms > {thresholds['p99']}ms")
    
    if sla_violations:
        print("\n⚠️  SLA VIOLATIONS DETECTED:")
        for violation in sla_violations:
            print(f"   - {violation}")
        print("=" * 60)
    else:
        print("\n✅ All SLA thresholds met")
        print("=" * 60)

