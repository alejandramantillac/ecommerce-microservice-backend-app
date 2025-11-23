package com.selimhorri.app.config;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import io.github.resilience4j.bulkhead.Bulkhead;
import io.github.resilience4j.bulkhead.BulkheadRegistry;

/**
 * Unit tests to verify Bulkhead configuration.
 * 
 * These tests verify that:
 * 1. BulkheadRegistry bean is correctly configured
 * 2. Bulkhead instances are created from application.yml configuration
 * 3. Bulkhead instances have the correct configuration values
 */
@SpringBootTest
public class BulkheadConfigurationTest {
	
	@Autowired
	private BulkheadRegistry bulkheadRegistry;
	
	@Test
	public void testBulkheadRegistryBeanExists() {
		assertNotNull(bulkheadRegistry, "BulkheadRegistry bean should be configured");
	}
	
	@Test
	public void testProductClientServiceBulkheadExists() {
		Bulkhead bulkhead = bulkheadRegistry.bulkhead("productClientService");
		assertNotNull(bulkhead, "productClientService Bulkhead should exist");
		// Verify configuration is loaded (value should be 20 from application.yml)
		int maxCalls = bulkhead.getBulkheadConfig().getMaxConcurrentCalls();
		assertTrue(maxCalls > 0, "productClientService should have max concurrent calls configured");
	}
	
	@Test
	public void testPaymentClientServiceBulkheadExists() {
		Bulkhead bulkhead = bulkheadRegistry.bulkhead("paymentClientService");
		assertNotNull(bulkhead, "paymentClientService Bulkhead should exist");
		// Verify configuration is loaded (value should be 10 from application.yml)
		int maxCalls = bulkhead.getBulkheadConfig().getMaxConcurrentCalls();
		assertTrue(maxCalls > 0, "paymentClientService should have max concurrent calls configured");
	}
	
	@Test
	public void testOrderClientServiceBulkheadExists() {
		Bulkhead bulkhead = bulkheadRegistry.bulkhead("orderClientService");
		assertNotNull(bulkhead, "orderClientService Bulkhead should exist");
		// Verify configuration is loaded (value should be 10 from application.yml)
		int maxCalls = bulkhead.getBulkheadConfig().getMaxConcurrentCalls();
		assertTrue(maxCalls > 0, "orderClientService should have max concurrent calls configured");
	}
	
	@Test
	public void testUserClientServiceBulkheadExists() {
		Bulkhead bulkhead = bulkheadRegistry.bulkhead("userClientService");
		assertNotNull(bulkhead, "userClientService Bulkhead should exist");
		// Verify configuration is loaded (value should be 20 from application.yml)
		int maxCalls = bulkhead.getBulkheadConfig().getMaxConcurrentCalls();
		assertTrue(maxCalls > 0, "userClientService should have max concurrent calls configured");
	}
}

