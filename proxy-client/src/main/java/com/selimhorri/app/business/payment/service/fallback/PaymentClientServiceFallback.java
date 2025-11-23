package com.selimhorri.app.business.payment.service.fallback;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;

import com.selimhorri.app.business.payment.model.PaymentDto;
import com.selimhorri.app.business.payment.model.response.PaymentPaymentServiceDtoCollectionResponse;
import com.selimhorri.app.business.payment.service.PaymentClientService;

import lombok.extern.slf4j.Slf4j;

/**
 * Fallback implementation for PaymentClientService.
 * Provides default responses when the PAYMENT-SERVICE is unavailable or circuit breaker is open.
 */
@Component
@Slf4j
public class PaymentClientServiceFallback implements PaymentClientService {
	
	@Override
	public ResponseEntity<PaymentPaymentServiceDtoCollectionResponse> findAll() {
		log.warn("Circuit breaker opened or PAYMENT-SERVICE unavailable. Returning empty list as fallback.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
				.body(new PaymentPaymentServiceDtoCollectionResponse());
	}
	
	@Override
	public ResponseEntity<PaymentDto> findById(String paymentId) {
		log.warn("Circuit breaker opened or PAYMENT-SERVICE unavailable. Payment ID: {}", paymentId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<PaymentDto> save(PaymentDto paymentDto) {
		log.warn("Circuit breaker opened or PAYMENT-SERVICE unavailable. Cannot save payment.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<PaymentDto> update(PaymentDto paymentDto) {
		log.warn("Circuit breaker opened or PAYMENT-SERVICE unavailable. Cannot update payment.");
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
	}
	
	@Override
	public ResponseEntity<Boolean> deleteById(String paymentId) {
		log.warn("Circuit breaker opened or PAYMENT-SERVICE unavailable. Cannot delete payment with ID: {}", paymentId);
		return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(false);
	}
	
}

