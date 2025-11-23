package com.selimhorri.app.feature.aspect;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.Signature;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.selimhorri.app.feature.FeatureToggle;
import com.selimhorri.app.feature.exception.FeatureDisabledException;
import com.selimhorri.app.feature.service.FeatureToggleService;

@ExtendWith(MockitoExtension.class)
@DisplayName("FeatureToggleAspect Tests")
class FeatureToggleAspectTest {
	
	@Mock
	private FeatureToggleService featureToggleService;
	
	@Mock
	private ProceedingJoinPoint proceedingJoinPoint;
	
	@Mock
	private Signature signature;
	
	@Mock
	private FeatureToggle featureToggle;
	
	@InjectMocks
	private FeatureToggleAspect featureToggleAspect;
	
	@BeforeEach
	void setUp() {
		// Configurar mocks básicos
		when(featureToggle.name()).thenReturn("test-feature");
		when(featureToggle.defaultValue()).thenReturn(false);
		when(featureToggle.message()).thenReturn("");
		when(proceedingJoinPoint.getSignature()).thenReturn(signature);
		when(signature.toShortString()).thenReturn("testMethod()");
	}
	
	@Test
	@DisplayName("Debería permitir ejecución cuando feature está habilitado")
	void testCheckFeatureToggle_WhenEnabled_ShouldProceed() throws Throwable {
		// Arrange
		when(featureToggleService.isFeatureEnabled("test-feature", false)).thenReturn(true);
		Object expectedResult = new Object();
		when(proceedingJoinPoint.proceed()).thenReturn(expectedResult);
		
		// Act
		Object result = featureToggleAspect.checkFeatureToggle(proceedingJoinPoint, featureToggle);
		
		// Assert
		assertEquals(expectedResult, result);
		verify(proceedingJoinPoint, times(1)).proceed();
		verify(featureToggleService, times(1)).isFeatureEnabled("test-feature", false);
	}
	
	@Test
	@DisplayName("Debería lanzar excepción cuando feature está deshabilitado")
	void testCheckFeatureToggle_WhenDisabled_ShouldThrowException() {
		// Arrange
		when(featureToggleService.isFeatureEnabled("test-feature", false)).thenReturn(false);
		
		// Act & Assert
		Throwable thrown = assertThrows(
			Throwable.class,
			() -> {
				try {
					featureToggleAspect.checkFeatureToggle(proceedingJoinPoint, featureToggle);
				} catch (Throwable e) {
					throw e;
				}
			}
		);
		
		assertTrue(thrown instanceof FeatureDisabledException);
		FeatureDisabledException exception = (FeatureDisabledException) thrown;
		assertEquals("test-feature", exception.getFeatureName());
		assertTrue(exception.getMessage().contains("test-feature"));
	}
	
	@Test
	@DisplayName("Debería usar mensaje personalizado cuando feature está deshabilitado")
	void testCheckFeatureToggle_WhenDisabled_ShouldUseCustomMessage() {
		// Arrange
		when(featureToggleService.isFeatureEnabled("test-feature", false)).thenReturn(false);
		when(featureToggle.message()).thenReturn("Custom error message");
		
		// Act & Assert
		Throwable thrown = assertThrows(
			Throwable.class,
			() -> {
				try {
					featureToggleAspect.checkFeatureToggle(proceedingJoinPoint, featureToggle);
				} catch (Throwable e) {
					throw e;
				}
			}
		);
		
		assertTrue(thrown instanceof FeatureDisabledException);
		FeatureDisabledException exception = (FeatureDisabledException) thrown;
		assertEquals("Custom error message", exception.getMessage());
	}
	
	@Test
	@DisplayName("Debería usar valor por defecto de la anotación")
	void testCheckFeatureToggle_ShouldUseDefaultValue() throws Throwable {
		// Arrange
		when(featureToggle.defaultValue()).thenReturn(true);
		when(featureToggleService.isFeatureEnabled("test-feature", true)).thenReturn(true);
		Object expectedResult = new Object();
		when(proceedingJoinPoint.proceed()).thenReturn(expectedResult);
		
		// Act
		Object result = featureToggleAspect.checkFeatureToggle(proceedingJoinPoint, featureToggle);
		
		// Assert
		assertEquals(expectedResult, result);
		verify(featureToggleService, times(1)).isFeatureEnabled("test-feature", true);
	}
	
	@Test
	@DisplayName("Debería manejar diferentes nombres de features")
	void testCheckFeatureToggle_WithDifferentFeatureNames() {
		// Arrange
		String[] featureNames = {"new-payment-method", "advanced-search", "recommendation-engine"};
		
		for (String featureName : featureNames) {
			when(featureToggle.name()).thenReturn(featureName);
			when(featureToggleService.isFeatureEnabled(featureName, false)).thenReturn(false);
			
			// Act & Assert
			Throwable thrown = assertThrows(
				Throwable.class,
				() -> {
					try {
						featureToggleAspect.checkFeatureToggle(proceedingJoinPoint, featureToggle);
					} catch (Throwable e) {
						throw e;
					}
				}
			);
			
			assertTrue(thrown instanceof FeatureDisabledException);
		}
	}
	
}
