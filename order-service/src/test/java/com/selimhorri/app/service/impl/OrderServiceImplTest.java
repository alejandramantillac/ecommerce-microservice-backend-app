package com.selimhorri.app.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.time.LocalDateTime;
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

import com.selimhorri.app.domain.Cart;
import com.selimhorri.app.domain.Order;
import com.selimhorri.app.dto.CartDto;
import com.selimhorri.app.dto.OrderDto;
import com.selimhorri.app.exception.wrapper.OrderNotFoundException;
import com.selimhorri.app.repository.OrderRepository;

/**
 * Unit tests for OrderServiceImpl
 * Tests validate individual component functionality without external dependencies
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("Order Service Unit Tests")
class OrderServiceImplTest {

    @Mock
    private OrderRepository orderRepository;

    @InjectMocks
    private OrderServiceImpl orderService;

    private Order testOrder;
    private OrderDto testOrderDto;
    private Cart testCart;

    @BeforeEach
    void setUp() {
        // Setup test data
        testCart = Cart.builder()
            .cartId(1)
            .userId(1)
            .build();

        testOrder = Order.builder()
            .orderId(1)
            .orderDate(LocalDateTime.now())
            .orderDesc("Test Order")
            .orderFee(99.99)
            .cart(testCart)
            .build();

        testOrderDto = OrderDto.builder()
            .orderId(1)
            .orderDate(LocalDateTime.now())
            .orderDesc("Test Order")
            .orderFee(99.99)
            .cartDto(CartDto.builder()
                .cartId(1)
                .build())
            .build();
    }

    @Test
    @DisplayName("Should return all orders when findAll is called")
    void testFindAll() {
        // Arrange
        List<Order> orders = Arrays.asList(testOrder);
        when(orderRepository.findAll()).thenReturn(orders);

        // Act
        List<OrderDto> result = orderService.findAll();

        // Assert
        assertNotNull(result);
        assertEquals(1, result.size());
        assertEquals(testOrder.getOrderId(), result.get(0).getOrderId());
        verify(orderRepository, times(1)).findAll();
    }

    @Test
    @DisplayName("Should return empty list when no orders exist")
    void testFindAll_WhenNoOrders() {
        // Arrange
        when(orderRepository.findAll()).thenReturn(Arrays.asList());

        // Act
        List<OrderDto> result = orderService.findAll();

        // Assert
        assertNotNull(result);
        assertTrue(result.isEmpty());
        verify(orderRepository, times(1)).findAll();
    }

    @Test
    @DisplayName("Should return order when findById is called with valid id")
    void testFindById() {
        // Arrange
        when(orderRepository.findById(1)).thenReturn(Optional.of(testOrder));

        // Act
        OrderDto result = orderService.findById(1);

        // Assert
        assertNotNull(result);
        assertEquals(testOrder.getOrderId(), result.getOrderId());
        assertEquals(testOrder.getOrderDesc(), result.getOrderDesc());
        verify(orderRepository, times(1)).findById(1);
    }

    @Test
    @DisplayName("Should throw OrderNotFoundException when order not found")
    void testFindById_WhenOrderNotExists() {
        // Arrange
        when(orderRepository.findById(999)).thenReturn(Optional.empty());

        // Act & Assert
        OrderNotFoundException exception = assertThrows(
            OrderNotFoundException.class,
            () -> orderService.findById(999)
        );
        
        assertEquals("Order with id: 999 not found", exception.getMessage());
        verify(orderRepository, times(1)).findById(999);
    }

    @Test
    @DisplayName("Should save order when save is called")
    void testSave() {
        // Arrange
        when(orderRepository.save(any(Order.class))).thenReturn(testOrder);

        // Act
        OrderDto result = orderService.save(testOrderDto);

        // Assert
        assertNotNull(result);
        assertEquals(testOrder.getOrderId(), result.getOrderId());
        verify(orderRepository, times(1)).save(any(Order.class));
    }

    @Test
    @DisplayName("Should update order when update is called")
    void testUpdate() {
        // Arrange
        testOrderDto.setOrderDesc("Updated Order");
        testOrder.setOrderDesc("Updated Order");
        when(orderRepository.save(any(Order.class))).thenReturn(testOrder);

        // Act
        OrderDto result = orderService.update(testOrderDto);

        // Assert
        assertNotNull(result);
        assertEquals("Updated Order", result.getOrderDesc());
        verify(orderRepository, times(1)).save(any(Order.class));
    }

    @Test
    @DisplayName("Should update order by id when update with orderId is called")
    void testUpdate_WithOrderId() {
        // Arrange
        when(orderRepository.findById(1)).thenReturn(Optional.of(testOrder));
        when(orderRepository.save(any(Order.class))).thenReturn(testOrder);

        // Act
        OrderDto result = orderService.update(1, testOrderDto);

        // Assert
        assertNotNull(result);
        assertEquals(testOrder.getOrderId(), result.getOrderId());
        verify(orderRepository, times(1)).findById(1);
        verify(orderRepository, times(1)).save(any(Order.class));
    }

    @Test
    @DisplayName("Should delete order when deleteById is called")
    void testDeleteById() {
        // Arrange
        when(orderRepository.findById(1)).thenReturn(Optional.of(testOrder));
        doNothing().when(orderRepository).delete(any(Order.class));

        // Act
        orderService.deleteById(1);

        // Assert
        verify(orderRepository, times(1)).findById(1);
        verify(orderRepository, times(1)).delete(any(Order.class));
    }

    @Test
    @DisplayName("Should throw OrderNotFoundException when deleting non-existent order")
    void testDeleteById_WhenOrderNotExists() {
        // Arrange
        when(orderRepository.findById(999)).thenReturn(Optional.empty());

        // Act & Assert
        assertThrows(
            OrderNotFoundException.class,
            () -> orderService.deleteById(999)
        );
        
        verify(orderRepository, times(1)).findById(999);
        verify(orderRepository, never()).delete(any(Order.class));
    }

}

