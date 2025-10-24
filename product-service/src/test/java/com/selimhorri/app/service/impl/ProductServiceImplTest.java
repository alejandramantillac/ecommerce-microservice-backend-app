package com.selimhorri.app.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.selimhorri.app.domain.Category;
import com.selimhorri.app.domain.Product;
import com.selimhorri.app.dto.CategoryDto;
import com.selimhorri.app.dto.ProductDto;
import com.selimhorri.app.exception.wrapper.ProductNotFoundException;
import com.selimhorri.app.repository.ProductRepository;

/**
 * Unit tests for ProductServiceImpl
 * Tests validate product service operations and business logic
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("Product Service Unit Tests")
class ProductServiceImplTest {

    @Mock
    private ProductRepository productRepository;

    @InjectMocks
    private ProductServiceImpl productService;

    private Product testProduct;
    private ProductDto testProductDto;
    private Category testCategory;

    @BeforeEach
    void setUp() {
        // Setup test category
        testCategory = Category.builder()
            .categoryId(1)
            .categoryTitle("Electronics")
            .imageUrl("http://example.com/category.jpg")
            .build();

        // Setup test product
        testProduct = Product.builder()
            .productId(1)
            .productTitle("Laptop")
            .imageUrl("http://example.com/laptop.jpg")
            .sku("LAP-001")
            .priceUnit(999.99)
            .quantity(10)
            .category(testCategory)
            .build();

        // Setup test product DTO
        testProductDto = ProductDto.builder()
            .productId(1)
            .productTitle("Laptop")
            .imageUrl("http://example.com/laptop.jpg")
            .sku("LAP-001")
            .priceUnit(999.99)
            .quantity(10)
            .categoryDto(CategoryDto.builder()
                .categoryId(1)
                .categoryTitle("Electronics")
                .imageUrl("http://example.com/category.jpg")
                .build())
            .build();
    }

    @Test
    @DisplayName("Test 1: Find all products should return list of ProductDto")
    void testFindAll_ShouldReturnListOfProducts() {
        // Given
        Product product2 = Product.builder()
            .productId(2)
            .productTitle("Mouse")
            .sku("MOU-001")
            .priceUnit(29.99)
            .quantity(50)
            .category(testCategory)
            .build();

        when(productRepository.findAll()).thenReturn(Arrays.asList(testProduct, product2));

        // When
        List<ProductDto> result = productService.findAll();

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals(2, result.size(), "Should return 2 products");
        verify(productRepository, times(1)).findAll();
    }

    @Test
    @DisplayName("Test 2: Find product by ID should return ProductDto when product exists")
    void testFindById_WhenProductExists_ShouldReturnProductDto() {
        // Given
        Integer productId = 1;
        when(productRepository.findById(productId)).thenReturn(Optional.of(testProduct));

        // When
        ProductDto result = productService.findById(productId);

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals(testProduct.getProductId(), result.getProductId(), "Product IDs should match");
        assertEquals(testProduct.getProductTitle(), result.getProductTitle(), "Product titles should match");
        assertEquals(testProduct.getSku(), result.getSku(), "SKUs should match");
        verify(productRepository, times(1)).findById(productId);
    }

    @Test
    @DisplayName("Test 3: Find product by ID should throw exception when product not found")
    void testFindById_WhenProductNotExists_ShouldThrowException() {
        // Given
        Integer productId = 999;
        when(productRepository.findById(productId)).thenReturn(Optional.empty());

        // When & Then
        ProductNotFoundException exception = assertThrows(
            ProductNotFoundException.class,
            () -> productService.findById(productId),
            "Should throw ProductNotFoundException"
        );

        assertTrue(exception.getMessage().contains("not found"), "Exception message should contain 'not found'");
        verify(productRepository, times(1)).findById(productId);
    }

    @Test
    @DisplayName("Test 4: Save product should persist and return ProductDto")
    void testSave_ShouldPersistAndReturnProductDto() {
        // Given
        when(productRepository.save(any(Product.class))).thenReturn(testProduct);

        // When
        ProductDto result = productService.save(testProductDto);

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals(testProductDto.getProductTitle(), result.getProductTitle(), "Product titles should match");
        assertEquals(testProductDto.getPriceUnit(), result.getPriceUnit(), "Prices should match");
        verify(productRepository, times(1)).save(any(Product.class));
    }

    @Test
    @DisplayName("Test 5: Update product should modify and return updated ProductDto")
    void testUpdate_ShouldModifyAndReturnProductDto() {
        // Given
        ProductDto updatedProductDto = ProductDto.builder()
            .productId(1)
            .productTitle("Laptop Pro")
            .sku("LAP-001")
            .priceUnit(1299.99)
            .quantity(5)
            .categoryDto(CategoryDto.builder()
                .categoryId(1)
                .categoryTitle("Electronics")
                .imageUrl("http://example.com/category.jpg")
                .build())
            .build();

        Product updatedProduct = Product.builder()
            .productId(1)
            .productTitle("Laptop Pro")
            .sku("LAP-001")
            .priceUnit(1299.99)
            .quantity(5)
            .category(testCategory)
            .build();

        when(productRepository.save(any(Product.class))).thenReturn(updatedProduct);

        // When
        ProductDto result = productService.update(updatedProductDto);

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals("Laptop Pro", result.getProductTitle(), "Product title should be updated");
        assertEquals(1299.99, result.getPriceUnit(), "Price should be updated");
        verify(productRepository, times(1)).save(any(Product.class));
    }

    @Test
    @DisplayName("Test 6: Delete product by ID should fetch and delete product")
    void testDeleteById_ShouldFetchAndDeleteProduct() {
        // Given
        Integer productId = 1;
        when(productRepository.findById(productId)).thenReturn(Optional.of(testProduct));
        doNothing().when(productRepository).delete(any(Product.class));

        // When
        productService.deleteById(productId);

        // Then
        verify(productRepository, times(1)).findById(productId);
        verify(productRepository, times(1)).delete(any(Product.class));
    }

    @Test
    @DisplayName("Test 7: Find all products with empty list should return empty result")
    void testFindAll_WhenNoProducts_ShouldReturnEmptyList() {
        // Given
        when(productRepository.findAll()).thenReturn(Arrays.asList());

        // When
        List<ProductDto> result = productService.findAll();

        // Then
        assertNotNull(result, "Result should not be null");
        assertTrue(result.isEmpty(), "Result should be empty");
        verify(productRepository, times(1)).findAll();
    }

    @Test
    @DisplayName("Test 8: Update product with productId should fetch and update product")
    void testUpdateWithProductId_ShouldFetchAndUpdateProduct() {
        // Given
        Integer productId = 1;
        when(productRepository.findById(productId)).thenReturn(Optional.of(testProduct));
        when(productRepository.save(any(Product.class))).thenReturn(testProduct);

        // When
        ProductDto result = productService.update(productId, testProductDto);

        // Then
        assertNotNull(result, "Result should not be null");
        verify(productRepository, times(1)).findById(productId);
        verify(productRepository, times(1)).save(any(Product.class));
    }

    @Test
    @DisplayName("Test 9: Save product with valid quantity should succeed")
    void testSave_WithValidQuantity_ShouldSucceed() {
        // Given
        ProductDto productWithStock = ProductDto.builder()
            .productId(2)
            .productTitle("Keyboard")
            .sku("KEY-001")
            .priceUnit(79.99)
            .quantity(100)
            .categoryDto(CategoryDto.builder()
                .categoryId(1)
                .categoryTitle("Electronics")
                .imageUrl("http://example.com/category.jpg")
                .build())
            .build();

        Product savedProduct = Product.builder()
            .productId(2)
            .productTitle("Keyboard")
            .sku("KEY-001")
            .priceUnit(79.99)
            .quantity(100)
            .category(testCategory)
            .build();

        when(productRepository.save(any(Product.class))).thenReturn(savedProduct);

        // When
        ProductDto result = productService.save(productWithStock);

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals(100, result.getQuantity(), "Quantity should match");
        verify(productRepository, times(1)).save(any(Product.class));
    }

    @Test
    @DisplayName("Test 10: Delete non-existing product should throw exception")
    void testDeleteById_WhenProductNotExists_ShouldThrowException() {
        // Given
        Integer productId = 999;
        when(productRepository.findById(productId)).thenReturn(Optional.empty());

        // When & Then
        assertThrows(
            ProductNotFoundException.class,
            () -> productService.deleteById(productId),
            "Should throw ProductNotFoundException"
        );

        verify(productRepository, times(1)).findById(productId);
        verify(productRepository, never()).delete(any(Product.class));
    }
}

