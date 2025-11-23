package com.selimhorri.app.feature.service;

import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.cloud.context.config.annotation.RefreshScope;
import org.springframework.cloud.context.environment.EnvironmentChangeEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

import com.selimhorri.app.feature.config.FeatureToggleProperties;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Service to manage feature toggles.
 * Features can be enabled/disabled dynamically through Spring Cloud Config.
 * Uses @RefreshScope to allow dynamic updates without restart.
 * 
 * This service uses reflection to dynamically map feature names to properties,
 * making it scalable without hardcoded switch statements.
 */
@Service
@RefreshScope
@RequiredArgsConstructor
@Slf4j
public class FeatureToggleService {
	
	private final FeatureToggleProperties featureToggleProperties;
	
	// Cache for feature states (can be extended to use external service)
	private final Map<String, Boolean> featureCache = new ConcurrentHashMap<>();
	
	// Map to cache method lookups for performance
	private final Map<String, Method> methodCache = new ConcurrentHashMap<>();
	
	/**
	 * Convert feature name (kebab-case) to method name (camelCase).
	 * Example: "new-payment-method" -> "newPaymentMethod"
	 */
	private String toMethodName(String featureName) {
		String[] parts = featureName.split("-");
		StringBuilder methodName = new StringBuilder(parts[0]);
		for (int i = 1; i < parts.length; i++) {
			methodName.append(Character.toUpperCase(parts[i].charAt(0)))
					.append(parts[i].substring(1));
		}
		return "is" + Character.toUpperCase(methodName.charAt(0)) + methodName.substring(1);
	}
	
	/**
	 * Get the value of a feature from configuration properties using reflection.
	 * 
	 * @param featureName name of the feature (kebab-case)
	 * @return the boolean value from properties, or null if not found
	 */
	private Boolean getFeatureValueFromProperties(String featureName) {
		try {
			// Check method cache first
			Method method = methodCache.get(featureName);
			if (method == null) {
				String methodName = toMethodName(featureName);
				method = FeatureToggleProperties.class.getMethod(methodName);
				methodCache.put(featureName, method);
			}
			
			return (Boolean) method.invoke(featureToggleProperties);
		} catch (Exception e) {
			log.debug("Feature '{}' not found in properties: {}", featureName, e.getMessage());
			return null;
		}
	}
	
	/**
	 * Check if a feature is enabled.
	 * Priority: Cache > Configuration Properties > Default Value
	 * 
	 * @param featureName name of the feature
	 * @param defaultValue default value if feature is not configured
	 * @return true if feature is enabled, false otherwise
	 */
	public boolean isFeatureEnabled(String featureName, boolean defaultValue) {
		// First check cache (dynamically set features take precedence)
		if (featureCache.containsKey(featureName)) {
			return featureCache.get(featureName);
		}
		
		// Then check configuration properties using reflection
		Boolean enabled = getFeatureValueFromProperties(featureName);
		
		if (enabled == null) {
			log.warn("Feature '{}' not found in configuration, using default value: {}", featureName, defaultValue);
			enabled = defaultValue;
		}
		
		// Cache the result for performance
		featureCache.put(featureName, enabled);
		
		return enabled;
	}
	
	/**
	 * Enable a feature dynamically.
	 * This overrides the configuration property value until cache is cleared.
	 * 
	 * @param featureName name of the feature
	 */
	public void enableFeature(String featureName) {
		featureCache.put(featureName, true);
		log.info("Feature '{}' enabled dynamically", featureName);
	}
	
	/**
	 * Disable a feature dynamically.
	 * This overrides the configuration property value until cache is cleared.
	 * 
	 * @param featureName name of the feature
	 */
	public void disableFeature(String featureName) {
		featureCache.put(featureName, false);
		log.info("Feature '{}' disabled dynamically", featureName);
	}
	
	/**
	 * Get all feature states.
	 * Combines configured features from properties with dynamically cached features.
	 * 
	 * @return map of feature names to their enabled state
	 */
	public Map<String, Boolean> getAllFeatures() {
		Map<String, Boolean> allFeatures = new HashMap<>();
		
		// Get all configured features from properties using reflection
		Method[] methods = FeatureToggleProperties.class.getMethods();
		for (Method method : methods) {
			if (method.getName().startsWith("is") && 
				method.getReturnType() == boolean.class && 
				method.getParameterCount() == 0) {
				
				try {
					// Convert method name to feature name (kebab-case)
					String methodName = method.getName().substring(2); // Remove "is"
					String featureName = methodName.substring(0, 1).toLowerCase() + 
							methodName.substring(1).replaceAll("([A-Z])", "-$1").toLowerCase();
					
					boolean value = (Boolean) method.invoke(featureToggleProperties);
					allFeatures.put(featureName, value);
				} catch (Exception e) {
					log.warn("Error reading feature property: {}", method.getName(), e);
				}
			}
		}
		
		// Override with cached features (dynamically set features take precedence)
		allFeatures.putAll(featureCache);
		
		return allFeatures;
	}
	
	/**
	 * Clear the feature cache (useful for testing or forcing refresh).
	 * When cache is cleared, features will be reloaded from configuration properties.
	 */
	public void clearCache() {
		featureCache.clear();
		methodCache.clear(); // Also clear method cache for consistency
		log.info("Feature toggle cache cleared");
	}
	
	/**
	 * Listen to environment change events (e.g., from /actuator/refresh).
	 * Automatically clears cache when configuration is refreshed.
	 * 
	 * @param event the environment change event
	 */
	@EventListener
	public void handleEnvironmentChange(EnvironmentChangeEvent event) {
		// Check if any feature toggle properties were changed
		boolean featureToggleChanged = event.getKeys().stream()
				.anyMatch(key -> key.startsWith("feature.toggle."));
		
		if (featureToggleChanged) {
			log.info("Feature toggle configuration changed. Clearing cache to reload from properties.");
			clearCache();
		}
	}
	
}

