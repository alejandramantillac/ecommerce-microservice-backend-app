"""
Integration Tests for User Service
"""
import pytest
import requests

@pytest.mark.integration
class TestUserService:
    
    def test_create_user(self, api_gateway_url, user_data, timeout):
        """Test 1: Create a new user"""
        response = requests.post(
            f"{api_gateway_url}/user-service/api/users",
            json=user_data,
            timeout=timeout
        )
        
        assert response.status_code in [200, 201], f"Expected 200/201, got {response.status_code}"
        data = response.json()
        assert data['email'] == user_data['email']
        assert data['firstName'] == user_data['firstName']
        print(f"✓ User created successfully: {data['userId']}")
    
    def test_get_all_users(self, api_gateway_url, timeout):
        """Test 2: Retrieve all users"""
        response = requests.get(
            f"{api_gateway_url}/user-service/api/users",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert 'collection' in data, "Response should contain 'collection' field"
        assert len(data['collection']) > 0, "Should have at least one user"
        print(f"✓ Retrieved {len(data['collection'])} users")
    
    def test_get_user_by_id(self, api_gateway_url, timeout):
        """Test 3: Retrieve a specific user by ID"""
        user_id = 1
        response = requests.get(
            f"{api_gateway_url}/user-service/api/users/{user_id}",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data['userId'] == user_id
        print(f"✓ User {user_id} retrieved successfully")
    
    def test_update_user(self, api_gateway_url, user_data, timeout):
        """Test 4: Update an existing user"""
        # First create the user
        requests.post(
            f"{api_gateway_url}/user-service/api/users",
            json=user_data,
            timeout=timeout
        )
        
        # Update the user
        user_data['firstName'] = 'Updated'
        response = requests.put(
            f"{api_gateway_url}/user-service/api/users",
            json=user_data,
            timeout=timeout
        )
        
        assert response.status_code in [200, 204]
        print(f"✓ User {user_data['userId']} updated successfully")
    
    def test_user_service_health(self, api_gateway_url, timeout):
        """Test 5: Verify user service health endpoint"""
        response = requests.get(
            f"{api_gateway_url}/user-service/actuator/health",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'UP', f"Service should be UP, got {data['status']}"
        print("✓ User service is healthy")
