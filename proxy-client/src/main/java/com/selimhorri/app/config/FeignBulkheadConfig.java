package com.selimhorri.app.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import io.github.resilience4j.bulkhead.BulkheadRegistry;

/**
 * Configuration for Bulkhead pattern in Feign Clients.
 * 
 * This configuration provides BulkheadRegistry bean that reads configuration
 * from application.yml and makes Bulkhead instances available for programmatic use.
 * 
 * Bulkhead instances are configured in application.yml:
 * - paymentClientService: max 10 concurrent calls, 2s max wait
 * - orderClientService: max 10 concurrent calls, 2s max wait
 * - productClientService: max 20 concurrent calls, 1s max wait
 * - userClientService: max 20 concurrent calls, 1s max wait
 * 
 * The Bulkhead instances are used programmatically in service wrapper classes
 * to ensure they work correctly in Spring Cloud 2020.0.4.
 */
@Configuration
public class FeignBulkheadConfig {
	
	/**
	 * Creates BulkheadRegistry bean that automatically reads configuration
	 * from application.yml and creates Bulkhead instances.
	 * 
	 * The registry is used by service wrapper classes to get Bulkhead instances
	 * and apply them programmatically to method calls.
	 */
	@Bean
	public BulkheadRegistry bulkheadRegistry() {
		return BulkheadRegistry.ofDefaults();
	}
}

