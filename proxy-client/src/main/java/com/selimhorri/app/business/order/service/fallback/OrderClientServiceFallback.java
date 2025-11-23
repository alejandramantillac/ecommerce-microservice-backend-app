package com.selimhorri.app.business.order.service.fallback;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;

import com.selimhorri.app.business.order.model.OrderDto;
import com.selimhorri.app.business.order.model.response.OrderOrderServiceDtoCollectionResponse;
import com.selimhorri.app.business.order.service.OrderClientService;

import lombok.extern.slf4j.Slf4j;

/**
 * Fallback implementation for OrderClientService.
 * Provides default responses when the ORDER-SERVICE is unavailable or circuit breaker is open.
 */
@Component
@Slf4j
public class OrderClientServiceFallback implements OrderClientService {
	
	@Override
	public ResponseEntity<OrderOrderServiceDtoCollectionResponse> findAll() {
		log.warn("Circuit breaker opened or ORDER-SERVICE unavailable. Returning empty list as fallback.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
				.body(new OrderOrderServiceDtoCollectionResponse());
	}
	
	@Override
	public ResponseEntity<OrderDto> findById(String orderId) {
		log.warn("Circuit breaker opened or ORDER-SERVICE unavailable. Order ID: {}", orderId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<OrderDto> save(OrderDto orderDto) {
		log.warn("Circuit breaker opened or ORDER-SERVICE unavailable. Cannot save order.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<OrderDto> update(OrderDto orderDto) {
		log.warn("Circuit breaker opened or ORDER-SERVICE unavailable. Cannot update order.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<OrderDto> update(String orderId, OrderDto orderDto) {
		log.warn("Circuit breaker opened or ORDER-SERVICE unavailable. Cannot update order with ID: {}", orderId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<Boolean> deleteById(String orderId) {
		log.warn("Circuit breaker opened or ORDER-SERVICE unavailable. Cannot delete order with ID: {}", orderId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(false);
	}
	
}

