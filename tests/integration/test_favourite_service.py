"""
Integration Tests for Favourite Service
"""
import pytest
import requests
from datetime import datetime

@pytest.mark.integration
class TestFavouriteService:
    
    def test_create_favourite(self, api_gateway_url, timeout):
        """Test 1: Create a favourite
        public class FavouriteDto implements Serializable {
	
	private static final long serialVersionUID = 1L;
	
	@NotNull(message = "Field must not be NULL")
	private Integer userId;
	
	@NotNull(message = "Field must not be NULL")
	private Integer productId;
	
	@NotNull(message = "Field must not be NULL")
	@JsonSerialize(using = LocalDateTimeSerializer.class)
	@JsonDeserialize(using = LocalDateTimeDeserializer.class)
	@JsonFormat(pattern = AppConstant.LOCAL_DATE_TIME_FORMAT, shape = Shape.STRING)
	@DateTimeFormat(pattern = AppConstant.LOCAL_DATE_TIME_FORMAT)
	private LocalDateTime likeDate;
	
	@JsonProperty("user")
	@JsonInclude(Include.NON_NULL)
	private UserDto userDto;
	
	@JsonProperty("product")
	@JsonInclude(Include.NON_NULL)
	private ProductDto productDto;
	
}

        """
        
        current_datetime = datetime.now().strftime("%d-%m-%Y__%H:%M:%S:000000")

        favourite_data = {
            "userId": 2,
            "productId": 1,
            "likeDate": current_datetime,
        }
        response = requests.post(
            f"{api_gateway_url}/favourite-service/api/favourites",
            json=favourite_data,
            timeout=timeout
        )
        
        assert response.status_code in [200, 201]
        data = response.json()
        print(f"✓ Favourite created successfully: {data}")
    
    def test_get_all_favourites(self, api_gateway_url, timeout):
        """Test 2: Retrieve all favourites"""
        response = requests.get(
            f"{api_gateway_url}/favourite-service/api/favourites",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert 'collection' in data
        print(f"✓ Retrieved {len(data['collection'])} favourites")
    
    def test_favourite_service_health(self, api_gateway_url, timeout):
        """Test 4: Verify favourite service health endpoint"""
        response = requests.get(
            f"{api_gateway_url}/favourite-service/actuator/health",
            timeout=timeout
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'UP'
        print("✓ Favourite service is healthy")
    
    def test_delete_favourite(self, api_gateway_url, timeout):
        """Test 5: Delete a favourite"""
        favourite_id = 100
        response = requests.delete(
            f"{api_gateway_url}/favourite-service/api/favourites/{favourite_id}",
            timeout=timeout
        )
        
        # Accept 200, 204, or 404 (if already deleted)
        assert response.status_code in [200, 204, 404]
        print(f"✓ Favourite {favourite_id} delete request processed")

