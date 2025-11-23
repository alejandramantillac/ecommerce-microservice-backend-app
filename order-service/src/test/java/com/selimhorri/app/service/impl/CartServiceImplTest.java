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
import org.springframework.web.client.RestTemplate;

import com.selimhorri.app.domain.Cart;
import com.selimhorri.app.dto.CartDto;
import com.selimhorri.app.dto.UserDto;
import com.selimhorri.app.exception.wrapper.CartNotFoundException;
import com.selimhorri.app.repository.CartRepository;

/**
 * Unit tests for CartServiceImpl
 * Tests validate individual component functionality without external dependencies
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("Cart Service Unit Tests")
class CartServiceImplTest {

    @Mock
    private CartRepository cartRepository;

    @Mock
    private RestTemplate restTemplate;

    @InjectMocks
    private CartServiceImpl cartService;

    private Cart testCart;
    private CartDto testCartDto;
    private UserDto testUserDto;

    @BeforeEach
    void setUp() {
        // Setup test data
        testCart = Cart.builder()
            .cartId(1)
            .userId(1)
            .build();

        testCartDto = CartDto.builder()
            .cartId(1)
            .userId(1)
            .userDto(UserDto.builder()
                .userId(1)
                .build())
            .build();

        testUserDto = UserDto.builder()
            .userId(1)
            .firstName("John")
            .lastName("Doe")
            .email("john.doe@example.com")
            .build();
    }

    @Test
    @DisplayName("Should return all carts when findAll is called")
    void testFindAll() {
        // Arrange
        List<Cart> carts = Arrays.asList(testCart);
        when(cartRepository.findAll()).thenReturn(carts);
        when(restTemplate.getForObject(anyString(), eq(UserDto.class))).thenReturn(testUserDto);

        // Act
        List<CartDto> result = cartService.findAll();

        // Assert
        assertNotNull(result);
        assertEquals(1, result.size());
        assertEquals(testCart.getCartId(), result.get(0).getCartId());
        verify(cartRepository, times(1)).findAll();
        verify(restTemplate, times(1)).getForObject(anyString(), eq(UserDto.class));
    }

    @Test
    @DisplayName("Should return empty list when no carts exist")
    void testFindAll_WhenNoCarts() {
        // Arrange
        when(cartRepository.findAll()).thenReturn(Arrays.asList());

        // Act
        List<CartDto> result = cartService.findAll();

        // Assert
        assertNotNull(result);
        assertTrue(result.isEmpty());
        verify(cartRepository, times(1)).findAll();
        verify(restTemplate, never()).getForObject(anyString(), eq(UserDto.class));
    }

    @Test
    @DisplayName("Should return cart when findById is called with valid id")
    void testFindById() {
        // Arrange
        when(cartRepository.findById(1)).thenReturn(Optional.of(testCart));
        when(restTemplate.getForObject(anyString(), eq(UserDto.class))).thenReturn(testUserDto);

        // Act
        CartDto result = cartService.findById(1);

        // Assert
        assertNotNull(result);
        assertEquals(testCart.getCartId(), result.getCartId());
        assertNotNull(result.getUserDto());
        verify(cartRepository, times(1)).findById(1);
        verify(restTemplate, times(1)).getForObject(anyString(), eq(UserDto.class));
    }

    @Test
    @DisplayName("Should throw CartNotFoundException when cart not found")
    void testFindById_WhenCartNotExists() {
        // Arrange
        when(cartRepository.findById(999)).thenReturn(Optional.empty());

        // Act & Assert
        CartNotFoundException exception = assertThrows(
            CartNotFoundException.class,
            () -> cartService.findById(999)
        );
        
        assertEquals("Cart with id: 999 not found", exception.getMessage());
        verify(cartRepository, times(1)).findById(999);
        verify(restTemplate, never()).getForObject(anyString(), eq(UserDto.class));
    }

    @Test
    @DisplayName("Should save cart when save is called")
    void testSave() {
        // Arrange
        when(cartRepository.save(any(Cart.class))).thenReturn(testCart);

        // Act
        CartDto result = cartService.save(testCartDto);

        // Assert
        assertNotNull(result);
        assertEquals(testCart.getCartId(), result.getCartId());
        verify(cartRepository, times(1)).save(any(Cart.class));
    }

    @Test
    @DisplayName("Should update cart when update is called")
    void testUpdate() {
        // Arrange
        testCartDto.setUserId(2);
        testCart.setUserId(2);
        when(cartRepository.save(any(Cart.class))).thenReturn(testCart);

        // Act
        CartDto result = cartService.update(testCartDto);

        // Assert
        assertNotNull(result);
        assertEquals(2, result.getUserId());
        verify(cartRepository, times(1)).save(any(Cart.class));
    }

    @Test
    @DisplayName("Should update cart by id when update with cartId is called")
    void testUpdate_WithCartId() {
        // Arrange
        when(cartRepository.findById(1)).thenReturn(Optional.of(testCart));
        when(restTemplate.getForObject(anyString(), eq(UserDto.class))).thenReturn(testUserDto);
        when(cartRepository.save(any(Cart.class))).thenReturn(testCart);

        // Act
        CartDto result = cartService.update(1, testCartDto);

        // Assert
        assertNotNull(result);
        assertEquals(testCart.getCartId(), result.getCartId());
        verify(cartRepository, times(1)).findById(1);
        verify(cartRepository, times(1)).save(any(Cart.class));
    }

    @Test
    @DisplayName("Should delete cart when deleteById is called")
    void testDeleteById() {
        // Arrange
        doNothing().when(cartRepository).deleteById(1);

        // Act
        cartService.deleteById(1);

        // Assert
        verify(cartRepository, times(1)).deleteById(1);
    }

}

