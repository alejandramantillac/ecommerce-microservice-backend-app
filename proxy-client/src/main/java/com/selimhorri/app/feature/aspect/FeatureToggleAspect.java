package com.selimhorri.app.feature.aspect;

import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.stereotype.Component;

import com.selimhorri.app.feature.FeatureToggle;
import com.selimhorri.app.feature.exception.FeatureDisabledException;
import com.selimhorri.app.feature.service.FeatureToggleService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Aspect to intercept methods annotated with @FeatureToggle.
 * Checks if the feature is enabled before allowing method execution.
 * If disabled, throws FeatureDisabledException.
 */
@Aspect
@Component
@RequiredArgsConstructor
@Slf4j
public class FeatureToggleAspect {
	
	private final FeatureToggleService featureToggleService;
	
	/**
	 * Intercept methods annotated with @FeatureToggle.
	 * 
	 * @param joinPoint the method being intercepted
	 * @param featureToggle the annotation
	 * @return the method result or error response
	 * @throws Throwable if feature is disabled or method throws exception
	 */
	@Around("@annotation(featureToggle)")
	public Object checkFeatureToggle(ProceedingJoinPoint joinPoint, FeatureToggle featureToggle) throws Throwable {
		String featureName = featureToggle.name();
		boolean defaultValue = featureToggle.defaultValue();
		String customMessage = featureToggle.message();
		
		log.debug("Checking feature toggle '{}' for method: {}", featureName, joinPoint.getSignature().toShortString());
		
		// Check if feature is enabled
		boolean isEnabled = featureToggleService.isFeatureEnabled(featureName, defaultValue);
		
		if (!isEnabled) {
			log.warn("Feature '{}' is disabled. Blocking access to method: {}", 
					featureName, joinPoint.getSignature().toShortString());
			
			// Throw exception with custom message if provided
			String message = customMessage != null && !customMessage.isEmpty() 
					? customMessage 
					: String.format("Feature '%s' is currently disabled", featureName);
			
			throw new FeatureDisabledException(featureName, message);
		}
		
		// Feature is enabled, proceed with method execution
		log.debug("Feature '{}' is enabled. Proceeding with method execution.", featureName);
		return joinPoint.proceed();
	}
	
	/**
	 * Intercept classes annotated with @FeatureToggle.
	 * 
	 * @param joinPoint the method being intercepted
	 * @param featureToggle the annotation on the class
	 * @return the method result or error response
	 * @throws Throwable if feature is disabled or method throws exception
	 */
	@Around("@within(featureToggle) && execution(public * *(..))")
	public Object checkFeatureToggleOnClass(ProceedingJoinPoint joinPoint, FeatureToggle featureToggle) throws Throwable {
		return checkFeatureToggle(joinPoint, featureToggle);
	}
	
}

