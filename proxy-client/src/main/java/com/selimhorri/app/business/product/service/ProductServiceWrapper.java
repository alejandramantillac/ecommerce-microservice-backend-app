package com.selimhorri.app.business.product.service;

import javax.validation.Valid;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;

import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import com.selimhorri.app.business.product.model.ProductDto;
import com.selimhorri.app.business.product.model.response.ProductProductServiceCollectionDtoResponse;

import io.github.resilience4j.bulkhead.Bulkhead;
import io.github.resilience4j.bulkhead.BulkheadRegistry;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Service wrapper that applies Bulkhead pattern programmatically to ProductClientService calls.
 * 
 * This wrapper ensures Bulkhead works correctly in Spring Cloud 2020.0.4 by applying
 * the pattern programmatically using Bulkhead.decorateSupplier().
 * 
 * The Bulkhead instance "productClientService" is configured in application.yml with:
 * - max-concurrent-calls: 20
 * - max-wait-duration: 1s
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProductServiceWrapper {
	
	private final ProductClientService productClientService;
	private final BulkheadRegistry bulkheadRegistry;
	
	private Bulkhead getBulkhead() {
		return this.bulkheadRegistry.bulkhead("productClientService");
	}
	
	public ResponseEntity<ProductProductServiceCollectionDtoResponse> findAll() {
		return Bulkhead.decorateSupplier(this.getBulkhead(), () -> {
			log.debug("Calling ProductClientService.findAll() with Bulkhead protection");
			return this.productClientService.findAll();
		}).get();
	}
	
	public ResponseEntity<ProductDto> findById(@NotBlank(message = "Input must not be blank!") @Valid final String productId) {
		return Bulkhead.decorateSupplier(this.getBulkhead(), () -> {
			log.debug("Calling ProductClientService.findById({}) with Bulkhead protection", productId);
			return this.productClientService.findById(productId);
		}).get();
	}
	
	public ResponseEntity<ProductDto> save(@NotNull(message = "Input must not be NULL!") @Valid final ProductDto productDto) {
		return Bulkhead.decorateSupplier(this.getBulkhead(), () -> {
			log.debug("Calling ProductClientService.save() with Bulkhead protection");
			return this.productClientService.save(productDto);
		}).get();
	}
	
	public ResponseEntity<ProductDto> update(@NotNull(message = "Input must not be NULL!") @Valid final ProductDto productDto) {
		return Bulkhead.decorateSupplier(this.getBulkhead(), () -> {
			log.debug("Calling ProductClientService.update() with Bulkhead protection");
			return this.productClientService.update(productDto);
		}).get();
	}
	
	public ResponseEntity<ProductDto> update(
			@NotBlank(message = "Input must not be blank!") @Valid final String productId,
			@NotNull(message = "Input must not be NULL!") @Valid final ProductDto productDto) {
		return Bulkhead.decorateSupplier(this.getBulkhead(), () -> {
			log.debug("Calling ProductClientService.update({}) with Bulkhead protection", productId);
			return this.productClientService.update(productId, productDto);
		}).get();
	}
	
	public ResponseEntity<Boolean> deleteById(final String productId) {
		return Bulkhead.decorateSupplier(this.getBulkhead(), () -> {
			log.debug("Calling ProductClientService.deleteById({}) with Bulkhead protection", productId);
			return this.productClientService.deleteById(productId);
		}).get();
	}
	
}

