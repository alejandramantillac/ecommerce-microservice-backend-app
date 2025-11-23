package com.selimhorri.app.business.user.service.fallback;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;

import com.selimhorri.app.business.user.model.UserDto;
import com.selimhorri.app.business.user.model.response.UserUserServiceCollectionDtoResponse;
import com.selimhorri.app.business.user.service.UserClientService;

import lombok.extern.slf4j.Slf4j;

/**
 * Fallback implementation for UserClientService.
 * Provides default responses when the USER-SERVICE is unavailable or circuit breaker is open.
 */
@Component
@Slf4j
public class UserClientServiceFallback implements UserClientService {
	
	@Override
	public ResponseEntity<UserUserServiceCollectionDtoResponse> findAll() {
		log.warn("Circuit breaker opened or USER-SERVICE unavailable. Returning empty list as fallback.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
				.body(new UserUserServiceCollectionDtoResponse());
	}
	
	@Override
	public ResponseEntity<UserDto> findById(String userId) {
		log.warn("Circuit breaker opened or USER-SERVICE unavailable. User ID: {}", userId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<UserDto> findByUsername(String username) {
		log.warn("Circuit breaker opened or USER-SERVICE unavailable. Username: {}", username);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<UserDto> save(UserDto userDto) {
		log.warn("Circuit breaker opened or USER-SERVICE unavailable. Cannot save user.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<UserDto> update(UserDto userDto) {
		log.warn("Circuit breaker opened or USER-SERVICE unavailable. Cannot update user.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<UserDto> update(String userId, UserDto userDto) {
		log.warn("Circuit breaker opened or USER-SERVICE unavailable. Cannot update user with ID: {}", userId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<Boolean> deleteById(String userId) {
		log.warn("Circuit breaker opened or USER-SERVICE unavailable. Cannot delete user with ID: {}", userId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(false);
	}
	
}

