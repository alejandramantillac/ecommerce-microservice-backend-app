package com.selimhorri.app.feature.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.selimhorri.app.feature.config.FeatureToggleProperties;

@ExtendWith(MockitoExtension.class)
@DisplayName("FeatureToggleService Tests")
class FeatureToggleServiceTest {
	
	@Mock
	private FeatureToggleProperties featureToggleProperties;
	
	@InjectMocks
	private FeatureToggleService featureToggleService;
	
	@BeforeEach
	void setUp() {
		// Limpiar cache antes de cada test
		featureToggleService.clearCache();
	}
	
	@Test
	@DisplayName("Debería retornar true cuando feature está habilitado en configuración")
	void testIsFeatureEnabled_WhenEnabledInConfig_ShouldReturnTrue() {
		// Arrange
		when(featureToggleProperties.isNewPaymentMethod()).thenReturn(true);
		
		// Act
		boolean result = featureToggleService.isFeatureEnabled("new-payment-method", false);
		
		// Assert
		assertTrue(result);
		verify(featureToggleProperties, times(1)).isNewPaymentMethod();
	}
	
	@Test
	@DisplayName("Debería retornar false cuando feature está deshabilitado en configuración")
	void testIsFeatureEnabled_WhenDisabledInConfig_ShouldReturnFalse() {
		// Arrange
		when(featureToggleProperties.isAdvancedSearch()).thenReturn(false);
		
		// Act
		boolean result = featureToggleService.isFeatureEnabled("advanced-search", true);
		
		// Assert
		assertFalse(result);
		verify(featureToggleProperties, times(1)).isAdvancedSearch();
	}
	
	@Test
	@DisplayName("Debería usar valor por defecto cuando feature no está en configuración")
	void testIsFeatureEnabled_WhenNotInConfig_ShouldUseDefaultValue() {
		// Arrange - No necesitamos mock porque el feature no existe en properties
		
		// Act
		boolean result = featureToggleService.isFeatureEnabled("unknown-feature", true);
		
		// Assert
		assertTrue(result); // Usa el valor por defecto
	}
	
	@Test
	@DisplayName("Debería habilitar feature dinámicamente")
	void testEnableFeature_ShouldUpdateCache() {
		// Arrange
		String featureName = "test-feature";
		
		// Act
		featureToggleService.enableFeature(featureName);
		boolean result = featureToggleService.isFeatureEnabled(featureName, false);
		
		// Assert
		assertTrue(result);
	}
	
	@Test
	@DisplayName("Debería deshabilitar feature dinámicamente")
	void testDisableFeature_ShouldUpdateCache() {
		// Arrange
		String featureName = "test-feature";
		
		// Act
		featureToggleService.disableFeature(featureName);
		boolean result = featureToggleService.isFeatureEnabled(featureName, true);
		
		// Assert
		assertFalse(result);
	}
	
	@Test
	@DisplayName("Cache debería tener prioridad sobre configuración")
	void testCachePriority_ShouldOverrideConfig() {
		// Arrange
		String featureName = "new-payment-method";
		when(featureToggleProperties.isNewPaymentMethod()).thenReturn(true);
		
		// Act - Primero se carga desde config
		boolean fromConfig = featureToggleService.isFeatureEnabled(featureName, false);
		// Luego se deshabilita dinámicamente
		featureToggleService.disableFeature(featureName);
		boolean fromCache = featureToggleService.isFeatureEnabled(featureName, true);
		
		// Assert
		assertTrue(fromConfig);
		assertFalse(fromCache); // Cache tiene prioridad
	}
	
	@Test
	@DisplayName("Debería retornar todos los features")
	void testGetAllFeatures_ShouldReturnAllFeatures() {
		// Arrange
		when(featureToggleProperties.isNewPaymentMethod()).thenReturn(true);
		when(featureToggleProperties.isAdvancedSearch()).thenReturn(false);
		when(featureToggleProperties.isRecommendationEngine()).thenReturn(false);
		when(featureToggleProperties.isBulkOperations()).thenReturn(true);
		
		// Act
		Map<String, Boolean> allFeatures = featureToggleService.getAllFeatures();
		
		// Assert
		assertNotNull(allFeatures);
		assertTrue(allFeatures.containsKey("new-payment-method"));
		assertTrue(allFeatures.containsKey("advanced-search"));
	}
	
	@Test
	@DisplayName("Debería limpiar cache correctamente")
	void testClearCache_ShouldRemoveAllCachedFeatures() {
		// Arrange
		String featureName = "test-feature";
		featureToggleService.enableFeature(featureName);
		
		// Act
		featureToggleService.clearCache();
		boolean result = featureToggleService.isFeatureEnabled(featureName, false);
		
		// Assert
		assertFalse(result); // Vuelve al valor por defecto
	}
	
	@Test
	@DisplayName("Debería convertir kebab-case a camelCase correctamente")
	void testToMethodName_ShouldConvertKebabCaseToCamelCase() {
		// Arrange & Act
		when(featureToggleProperties.isNewPaymentMethod()).thenReturn(true);
		boolean result = featureToggleService.isFeatureEnabled("new-payment-method", false);
		
		// Assert
		assertTrue(result);
		verify(featureToggleProperties, times(1)).isNewPaymentMethod();
	}
	
}

