package com.selimhorri.app.business.favourite.service.fallback;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;

import com.selimhorri.app.business.favourite.model.FavouriteDto;
import com.selimhorri.app.business.favourite.model.FavouriteId;
import com.selimhorri.app.business.favourite.model.response.FavouriteFavouriteServiceCollectionDtoResponse;
import com.selimhorri.app.business.favourite.service.FavouriteClientService;

import lombok.extern.slf4j.Slf4j;

/**
 * Fallback implementation for FavouriteClientService.
 * Provides default responses when the FAVOURITE-SERVICE is unavailable or circuit breaker is open.
 */
@Component
@Slf4j
public class FavouriteClientServiceFallback implements FavouriteClientService {
	
	@Override
	public ResponseEntity<FavouriteFavouriteServiceCollectionDtoResponse> findAll() {
		log.warn("Circuit breaker opened or FAVOURITE-SERVICE unavailable. Returning empty list as fallback.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
				.body(new FavouriteFavouriteServiceCollectionDtoResponse());
	}
	
	@Override
	public ResponseEntity<FavouriteDto> findById(String userId, String productId, String likeDate) {
		log.warn("Circuit breaker opened or FAVOURITE-SERVICE unavailable. User ID: {}, Product ID: {}", userId, productId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<FavouriteDto> findById(FavouriteId favouriteId) {
		log.warn("Circuit breaker opened or FAVOURITE-SERVICE unavailable. Favourite ID: {}", favouriteId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<FavouriteDto> save(FavouriteDto favouriteDto) {
		log.warn("Circuit breaker opened or FAVOURITE-SERVICE unavailable. Cannot save favourite.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<FavouriteDto> update(FavouriteDto favouriteDto) {
		log.warn("Circuit breaker opened or FAVOURITE-SERVICE unavailable. Cannot update favourite.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<Boolean> deleteById(String userId, String productId, String likeDate) {
		log.warn("Circuit breaker opened or FAVOURITE-SERVICE unavailable. Cannot delete favourite. User ID: {}, Product ID: {}", userId, productId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(false);
	}
	
	@Override
	public ResponseEntity<Boolean> deleteById(FavouriteId favouriteId) {
		log.warn("Circuit breaker opened or FAVOURITE-SERVICE unavailable. Cannot delete favourite.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(false);
	}
	
}

