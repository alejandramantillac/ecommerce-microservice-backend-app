package com.selimhorri.app.feature;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Annotation to mark methods or endpoints that should be controlled by Feature Toggle.
 * When a feature is disabled, the method will throw FeatureDisabledException.
 * 
 * Usage:
 * <pre>
 * {@code
 * @FeatureToggle(name = "new-payment-method", defaultValue = true)
 * @PostMapping("/api/payments")
 * public ResponseEntity<PaymentDto> createPayment(@RequestBody PaymentDto payment) {
 *     // This endpoint is controlled by the "new-payment-method" feature toggle
 * }
 * }
 * </pre>
 */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface FeatureToggle {
	
	/**
	 * The name of the feature toggle.
	 * This name is used to look up the feature state in configuration.
	 * 
	 * @return feature name
	 */
	String name();
	
	/**
	 * Default value if the feature is not configured.
	 * If true, the feature is enabled by default.
	 * If false, the feature is disabled by default.
	 * 
	 * @return default enabled state
	 */
	boolean defaultValue() default true;
	
	/**
	 * Custom message to return when feature is disabled.
	 * If not specified, a default message will be used.
	 * 
	 * @return custom message
	 */
	String message() default "";
	
}


