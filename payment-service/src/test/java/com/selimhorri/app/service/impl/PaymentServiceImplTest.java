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

import com.selimhorri.app.domain.Payment;
import com.selimhorri.app.domain.PaymentStatus;
import com.selimhorri.app.dto.OrderDto;
import com.selimhorri.app.dto.PaymentDto;
import com.selimhorri.app.exception.wrapper.PaymentNotFoundException;
import com.selimhorri.app.repository.PaymentRepository;

/**
 * Unit tests for PaymentServiceImpl
 * Tests validate individual component functionality without external dependencies
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("Payment Service Unit Tests")
class PaymentServiceImplTest {

    @Mock
    private PaymentRepository paymentRepository;

    @Mock
    private RestTemplate restTemplate;

    @InjectMocks
    private PaymentServiceImpl paymentService;

    private Payment testPayment;
    private PaymentDto testPaymentDto;
    private OrderDto testOrderDto;

    @BeforeEach
    void setUp() {
        // Setup test data
        testPayment = Payment.builder()
            .paymentId(1)
            .orderId(1)
            .isPayed(true)
            .paymentStatus(PaymentStatus.COMPLETED)
            .build();

        testPaymentDto = PaymentDto.builder()
            .paymentId(1)
            .isPayed(true)
            .paymentStatus(PaymentStatus.COMPLETED)
            .orderDto(OrderDto.builder()
                .orderId(1)
                .build())
            .build();

        testOrderDto = OrderDto.builder()
            .orderId(1)
            .orderDesc("Test Order")
            .orderFee(99.99)
            .build();
    }

    @Test
    @DisplayName("Should return all payments when findAll is called")
    void testFindAll() {
        // Arrange
        List<Payment> payments = Arrays.asList(testPayment);
        when(paymentRepository.findAll()).thenReturn(payments);
        when(restTemplate.getForObject(anyString(), eq(OrderDto.class))).thenReturn(testOrderDto);

        // Act
        List<PaymentDto> result = paymentService.findAll();

        // Assert
        assertNotNull(result);
        assertEquals(1, result.size());
        assertEquals(testPayment.getPaymentId(), result.get(0).getPaymentId());
        assertNotNull(result.get(0).getOrderDto());
        verify(paymentRepository, times(1)).findAll();
        verify(restTemplate, times(1)).getForObject(anyString(), eq(OrderDto.class));
    }

    @Test
    @DisplayName("Should return empty list when no payments exist")
    void testFindAll_WhenNoPayments() {
        // Arrange
        when(paymentRepository.findAll()).thenReturn(Arrays.asList());

        // Act
        List<PaymentDto> result = paymentService.findAll();

        // Assert
        assertNotNull(result);
        assertTrue(result.isEmpty());
        verify(paymentRepository, times(1)).findAll();
        verify(restTemplate, never()).getForObject(anyString(), eq(OrderDto.class));
    }

    @Test
    @DisplayName("Should return payment when findById is called with valid id")
    void testFindById() {
        // Arrange
        when(paymentRepository.findById(1)).thenReturn(Optional.of(testPayment));
        when(restTemplate.getForObject(anyString(), eq(OrderDto.class))).thenReturn(testOrderDto);

        // Act
        PaymentDto result = paymentService.findById(1);

        // Assert
        assertNotNull(result);
        assertEquals(testPayment.getPaymentId(), result.getPaymentId());
        assertEquals(testPayment.getIsPayed(), result.getIsPayed());
        assertEquals(testPayment.getPaymentStatus(), result.getPaymentStatus());
        assertNotNull(result.getOrderDto());
        verify(paymentRepository, times(1)).findById(1);
        verify(restTemplate, times(1)).getForObject(anyString(), eq(OrderDto.class));
    }

    @Test
    @DisplayName("Should throw PaymentNotFoundException when payment not found")
    void testFindById_WhenPaymentNotExists() {
        // Arrange
        when(paymentRepository.findById(999)).thenReturn(Optional.empty());

        // Act & Assert
        PaymentNotFoundException exception = assertThrows(
            PaymentNotFoundException.class,
            () -> paymentService.findById(999)
        );
        
        assertEquals("Payment with id: 999 not found", exception.getMessage());
        verify(paymentRepository, times(1)).findById(999);
        verify(restTemplate, never()).getForObject(anyString(), eq(OrderDto.class));
    }

    @Test
    @DisplayName("Should save payment when save is called")
    void testSave() {
        // Arrange
        when(paymentRepository.save(any(Payment.class))).thenReturn(testPayment);

        // Act
        PaymentDto result = paymentService.save(testPaymentDto);

        // Assert
        assertNotNull(result);
        assertEquals(testPayment.getPaymentId(), result.getPaymentId());
        verify(paymentRepository, times(1)).save(any(Payment.class));
    }

    @Test
    @DisplayName("Should update payment when update is called")
    void testUpdate() {
        // Arrange
        testPaymentDto.setIsPayed(false);
        testPaymentDto.setPaymentStatus(PaymentStatus.IN_PROGRESS);
        testPayment.setIsPayed(false);
        testPayment.setPaymentStatus(PaymentStatus.IN_PROGRESS);
        when(paymentRepository.save(any(Payment.class))).thenReturn(testPayment);

        // Act
        PaymentDto result = paymentService.update(testPaymentDto);

        // Assert
        assertNotNull(result);
        assertFalse(result.getIsPayed());
        assertEquals(PaymentStatus.IN_PROGRESS, result.getPaymentStatus());
        verify(paymentRepository, times(1)).save(any(Payment.class));
    }

    @Test
    @DisplayName("Should delete payment when deleteById is called")
    void testDeleteById() {
        // Arrange
        doNothing().when(paymentRepository).deleteById(1);

        // Act
        paymentService.deleteById(1);

        // Assert
        verify(paymentRepository, times(1)).deleteById(1);
    }

    @Test
    @DisplayName("Should handle payment with NOT_STARTED status")
    void testSave_WithNotStartedStatus() {
        // Arrange
        testPayment.setPaymentStatus(PaymentStatus.NOT_STARTED);
        testPaymentDto.setPaymentStatus(PaymentStatus.NOT_STARTED);
        when(paymentRepository.save(any(Payment.class))).thenReturn(testPayment);

        // Act
        PaymentDto result = paymentService.save(testPaymentDto);

        // Assert
        assertNotNull(result);
        assertEquals(PaymentStatus.NOT_STARTED, result.getPaymentStatus());
        verify(paymentRepository, times(1)).save(any(Payment.class));
    }

}

