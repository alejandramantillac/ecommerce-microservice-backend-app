package com.selimhorri.app.business.product.service.fallback;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;

import com.selimhorri.app.business.product.model.ProductDto;
import com.selimhorri.app.business.product.model.response.ProductProductServiceCollectionDtoResponse;
import com.selimhorri.app.business.product.service.ProductClientService;

import lombok.extern.slf4j.Slf4j;

/**
 * Fallback implementation for ProductClientService.
 * Provides default responses when the PRODUCT-SERVICE is unavailable or circuit breaker is open.
 */
@Component
@Slf4j
public class ProductClientServiceFallback implements ProductClientService {
	
	@Override
	public ResponseEntity<ProductProductServiceCollectionDtoResponse> findAll() {
		log.warn("Circuit breaker opened or PRODUCT-SERVICE unavailable. Returning empty list as fallback.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
				.body(new ProductProductServiceCollectionDtoResponse());
	}
	
	@Override
	public ResponseEntity<ProductDto> findById(String productId) {
		log.warn("Circuit breaker opened or PRODUCT-SERVICE unavailable. Product ID: {}", productId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<ProductDto> save(ProductDto productDto) {
		log.warn("Circuit breaker opened or PRODUCT-SERVICE unavailable. Cannot save product.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<ProductDto> update(ProductDto productDto) {
		log.warn("Circuit breaker opened or PRODUCT-SERVICE unavailable. Cannot update product.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<ProductDto> update(String productId, ProductDto productDto) {
		log.warn("Circuit breaker opened or PRODUCT-SERVICE unavailable. Cannot update product with ID: {}", productId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<Boolean> deleteById(String productId) {
		log.warn("Circuit breaker opened or PRODUCT-SERVICE unavailable. Cannot delete product with ID: {}", productId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(false);
	}
	
}

