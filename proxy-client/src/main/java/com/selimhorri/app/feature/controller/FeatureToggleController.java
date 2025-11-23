package com.selimhorri.app.feature.controller;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.selimhorri.app.feature.service.FeatureToggleService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * REST Controller for managing feature toggles.
 * Provides endpoints to view and modify feature states dynamically.
 * 
 * Note: In production, these endpoints should be secured with admin role.
 */
@RestController
@RequestMapping("/api/admin/features")
@RequiredArgsConstructor
@Slf4j
public class FeatureToggleController {
	
	private final FeatureToggleService featureToggleService;
	
	/**
	 * Get all feature toggles and their current state.
	 * 
	 * @return map of feature names to enabled state
	 */
	@GetMapping
	public ResponseEntity<Map<String, Boolean>> getAllFeatures() {
		log.info("Retrieving all feature toggles");
		Map<String, Boolean> features = featureToggleService.getAllFeatures();
		return ResponseEntity.ok(features);
	}
	
	/**
	 * Get the state of a specific feature.
	 * 
	 * @param featureName name of the feature
	 * @return true if enabled, false if disabled
	 */
	@GetMapping("/{featureName}")
	public ResponseEntity<Boolean> getFeatureState(@PathVariable String featureName) {
		log.info("Checking state of feature: {}", featureName);
		boolean enabled = featureToggleService.isFeatureEnabled(featureName, false);
		return ResponseEntity.ok(enabled);
	}
	
	/**
	 * Enable a feature dynamically.
	 * 
	 * @param featureName name of the feature to enable
	 * @return success message
	 */
	@PostMapping("/{featureName}/enable")
	public ResponseEntity<String> enableFeature(@PathVariable String featureName) {
		log.info("Enabling feature: {}", featureName);
		featureToggleService.enableFeature(featureName);
		return ResponseEntity.ok(String.format("Feature '%s' has been enabled", featureName));
	}
	
	/**
	 * Disable a feature dynamically.
	 * 
	 * @param featureName name of the feature to disable
	 * @return success message
	 */
	@PostMapping("/{featureName}/disable")
	public ResponseEntity<String> disableFeature(@PathVariable String featureName) {
		log.info("Disabling feature: {}", featureName);
		featureToggleService.disableFeature(featureName);
		return ResponseEntity.ok(String.format("Feature '%s' has been disabled", featureName));
	}
	
	/**
	 * Clear the feature toggle cache.
	 * Useful for forcing a refresh from configuration.
	 * 
	 * @return success message
	 */
	@PostMapping("/cache/clear")
	public ResponseEntity<String> clearCache() {
		log.info("Clearing feature toggle cache");
		featureToggleService.clearCache();
		return ResponseEntity.ok("Feature toggle cache cleared");
	}
	
}

