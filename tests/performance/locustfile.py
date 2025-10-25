"""
Performance Tests using Locust
"""
import time
import random
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
            fav_data = {
                "favouriteId": fav_id,
                "likeDate": "2024-10-25",
                "user": {"userId": self.user_id},
                "product": {"productId": random.choice(self.product_ids)}
            }
            self.client.post(
                "/favourite-service/api/favourites",
                json=fav_data,
                name="POST /favourites"
            )
    
    @task(1)
    def health_check(self):
        """Check API Gateway health"""
        self.client.get("/actuator/health", name="GET /health")


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when the test starts"""
    print("=" * 60)
    print("🚀 Starting E-commerce Performance Tests")
    print(f"   Target: {environment.host}")
    print("=" * 60)


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when the test stops"""
    print("=" * 60)
    print("✅ Performance Tests Completed")
    print("=" * 60)

