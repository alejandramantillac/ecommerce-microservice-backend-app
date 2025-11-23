package com.selimhorri.app.feature.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.cloud.context.config.annotation.RefreshScope;
import org.springframework.stereotype.Component;

import lombok.Data;

/**
 * Configuration properties for Feature Toggles.
 * Maps properties from application.yml with prefix "feature.toggle".
 * 
 * Example in application.yml:
 * feature:
 *   toggle:
 *     new-payment-method: true
 *     advanced-search: false
 */
@Component
@ConfigurationProperties(prefix = "feature.toggle")
@RefreshScope
@Data
public class FeatureToggleProperties {
	
	/**
	 * Enable/disable new payment method feature.
	 * Default: true
	 */
	private boolean newPaymentMethod = true;
	
	/**
	 * Enable/disable advanced search feature.
	 * Default: false
	 */
	private boolean advancedSearch = false;
	
	/**
	 * Enable/disable recommendation engine feature.
	 * Default: false
	 */
	private boolean recommendationEngine = false;
	
	/**
	 * Enable/disable bulk operations feature.
	 * Default: true
	 */
	private boolean bulkOperations = true;
	
}


