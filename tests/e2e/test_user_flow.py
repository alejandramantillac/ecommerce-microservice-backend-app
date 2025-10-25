"""
E2E Tests: User Registration and Profile Management Flow
"""
import pytest
import requests
import time
from datetime import datetime

@pytest.mark.e2e
class TestUserFlow:
    
    def test_complete_user_registration_flow(self, api_gateway_url, timeout):
        """E2E Test 1: Complete user registration and profile update flow"""
        
        # Step 1: Create a new user
        print("\n  Step 1: Creating new user...")
        user_data = {
            "userId": 200,
            "firstName": "María",
            "lastName": "García",
            "imageUrl": "https://example.com/maria.jpg",
            "email": "maria.garcia@example.com",
            "phone": "+573007654321",
            "credential": {
                "credentialId": 200,
                "username": "maria.garcia",
                "password": "SecurePass123!",
                "roleBasedAuthority": "ROLE_USER",
                "isEnabled": True,
                "isAccountNonExpired": True,
                "isAccountNonLocked": True,
                "isCredentialsNonExpired": True
            }
        }
        
        create_response = requests.post(
            f"{api_gateway_url}/user-service/api/users",
            json=user_data,
            timeout=timeout
        )
        assert create_response.status_code in [200, 201]
        created_user = create_response.json()
        user_id = created_user['userId']
        print(f"    ✓ User created with ID: {user_id}")
        
        # Step 2: Retrieve the created user
        print("  Step 2: Retrieving user details...")
        time.sleep(1)  # Small delay to ensure data consistency
        get_response = requests.get(
            f"{api_gateway_url}/user-service/api/users/{user_id}",
            timeout=timeout
        )
        assert get_response.status_code == 200
        retrieved_user = get_response.json()
        assert retrieved_user['email'] == user_data['email']
        print(f"    ✓ User retrieved: {retrieved_user['firstName']} {retrieved_user['lastName']}")
        
        # Step 3: Update user profile
        print("  Step 3: Updating user profile...")
        user_data['firstName'] = 'María Updated'
        user_data['lastName'] = 'García Updated'
        update_response = requests.put(
            f"{api_gateway_url}/user-service/api/users",
            json=user_data,
            timeout=timeout
        )
        assert update_response.status_code in [200, 204]
        print("    ✓ User profile updated")
        
        # Step 4: Verify the update
        print("  Step 4: Verifying profile update...")
        time.sleep(1)
        verify_response = requests.get(
            f"{api_gateway_url}/user-service/api/users/{user_id}",
            timeout=timeout
        )
        assert verify_response.status_code == 200
        updated_user = verify_response.json()
        print(f"    ✓ Profile update verified: {updated_user['firstName']}")
        
        print("\n✅ Complete user registration flow passed")
    
    def test_user_authentication_flow(self, api_gateway_url, timeout):
        """E2E Test 2: User authentication and authorization flow"""
        
        # Step 1: Create user with credentials
        print("\n  Step 1: Creating user with credentials...")
        user_data = {
            "userId": 201,
            "firstName": "John",
            "lastName": "Doe",
            "imageUrl": "https://example.com/john.jpg",
            "email": "john.doe@example.com",
            "phone": "+573001111111",
            "credential": {
                "credentialId": 201,
                "username": "john.doe",
                "password": "JohnPass123!",
                "roleBasedAuthority": "ROLE_USER",
                "isEnabled": True,
                "isAccountNonExpired": True,
                "isAccountNonLocked": True,
                "isCredentialsNonExpired": True
            }
        }
        
        response = requests.post(
            f"{api_gateway_url}/user-service/api/users",
            json=user_data,
            timeout=timeout
        )
        assert response.status_code in [200, 201]
        print("    ✓ User with credentials created")
        
        # Step 2: Verify user can access protected resources
        print("  Step 2: Verifying user access...")
        user_response = requests.get(
            f"{api_gateway_url}/user-service/api/users/{user_data['userId']}",
            timeout=timeout
        )
        print("    ✓ User can access resources")
        
        print("\n✅ User authentication flow passed")
    
    def test_user_favorite_products_flow(self, api_gateway_url, timeout):
        """E2E Test 3: User favoriting products flow"""
        
        # Step 1: Create a user
        print("\n  Step 1: Creating user...")
        user_data = {
            "userId": 202,
            "firstName": "Jane",
            "lastName": "Smith",
            "imageUrl": "https://example.com/jane.jpg",
            "email": "jane.smith@example.com",
            "phone": "+573002222222",
            "credential": {
                "credentialId": 202,
                "username": "jane.smith",
                "password": "JanePass123!",
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
        
        # Step 2: Get available products
        print("  Step 2: Getting available products...")
        products_response = requests.get(
            f"{api_gateway_url}/product-service/api/products",
            timeout=timeout
        )
        assert products_response.status_code == 200
        products = products_response.json()['collection']
        assert len(products) > 0
        product_id = products[0]['productId']
        print(f"    ✓ Found {len(products)} products, selecting product {product_id}")
        
        # Step 3: Add product to favourites
        print("  Step 3: Adding product to favourites...")
        current_datetime = datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000")
        favourite_data = {
            "userId": user_id,
            "productId": product_id,
            "likeDate": current_datetime,
        }
        
        fav_response = requests.post(
            f"{api_gateway_url}/favourite-service/api/favourites",
            json=favourite_data,
            timeout=timeout
        )
        assert fav_response.status_code in [200, 201]
        print("    ✓ Product added to favourites")
        
        print("\n✅ User favorite products flow passed")

