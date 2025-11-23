package com.selimhorri.app.feature.exception;

/**
 * Exception thrown when a feature toggle is disabled.
 * This exception is thrown by the FeatureToggleAspect when a disabled feature is accessed.
 */
public class FeatureDisabledException extends RuntimeException {
	
	private static final long serialVersionUID = 1L;
	
	private final String featureName;
	
	public FeatureDisabledException(String featureName) {
		super(String.format("Feature '%s' is currently disabled", featureName));
		this.featureName = featureName;
	}
	
	public FeatureDisabledException(String featureName, String message) {
		super(message != null && !message.isEmpty() ? message : String.format("Feature '%s' is currently disabled", featureName));
		this.featureName = featureName;
	}
	
	public String getFeatureName() {
		return featureName;
	}
	
}


