"""
Pytest configuration and shared fixtures
"""

import os
import pytest


@pytest.fixture(scope="session")
def api_gateway_url():
    """Get API Gateway URL from environment or use default"""
    return os.getenv("API_GATEWAY_URL", "http://4.246.235.167:8080")


@pytest.fixture(scope="session")
def timeout():
    """Default timeout for requests"""
    return 10


@pytest.fixture
def user_data():
    """Sample user data for tests"""
    return {
        "userId": 100,
        "firstName": "Test",
        "lastName": "User",
        "imageUrl": "https://example.com/test.jpg",
        "email": "test.user@example.com",
        "phone": "+573001234567",
        "credential": {
            "credentialId": 100,
            "username": "test.user",
            "password": "TestPass123!",
            "roleBasedAuthority": "ROLE_USER",
            "isEnabled": True,
            "isAccountNonExpired": True,
            "isAccountNonLocked": True,
            "isCredentialsNonExpired": True
        },
    }


@pytest.fixture
def product_data():
    """Sample product data for tests"""
    return {
        "productId": 100,
        "productTitle": "Test Product",
        "imageUrl": "https://example.com/product.jpg",
        "sku": "TEST-100",
        "priceUnit": 99.99,
        "quantity": 10,
        "category": {"categoryId": 3, "categoryTitle": "Game", "imageUrl": None},
    }


@pytest.fixture
def order_data():
    """Sample order data for tests"""
    return {
        "orderId": 100,
        "orderDesc": "Test Order",
        "orderFee": 99.99,
        "cart": {"cartId": 100},
    }
