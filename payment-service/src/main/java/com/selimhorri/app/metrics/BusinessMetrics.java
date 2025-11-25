package com.selimhorri.app.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;

/**
 * Business metrics for Payment Service
 * Tracks payment-related business events
 */
@Component
@RequiredArgsConstructor
public class BusinessMetrics {

    private final MeterRegistry meterRegistry;

    // Counters
    private Counter paymentsProcessedCounter;
    private Counter paymentsSuccessfulCounter;
    private Counter paymentsFailedCounter;
    private Counter paymentsAmountCounter;

    @PostConstruct
    public void init() {
        // Initialize counters
        this.paymentsProcessedCounter = Counter.builder("payments.processed.total")
                .description("Total number of payments processed")
                .register(meterRegistry);

        this.paymentsSuccessfulCounter = Counter.builder("payments.successful.total")
                .description("Total number of successful payments")
                .register(meterRegistry);

        this.paymentsFailedCounter = Counter.builder("payments.failed.total")
                .description("Total number of failed payments")
                .register(meterRegistry);

        this.paymentsAmountCounter = Counter.builder("payments.amount.total")
                .description("Total amount of all payments")
                .baseUnit("currency")
                .register(meterRegistry);
    }

    /**
     * Record a payment processing event
     * @param amount The payment amount
     */
    public void recordPaymentProcessed(double amount) {
        this.paymentsProcessedCounter.increment();
        this.paymentsAmountCounter.increment(amount);
    }

    /**
     * Record a successful payment
     */
    public void recordPaymentSuccessful() {
        this.paymentsSuccessfulCounter.increment();
    }

    /**
     * Record a failed payment
     */
    public void recordPaymentFailed() {
        this.paymentsFailedCounter.increment();
    }

    /**
     * Record payment amount
     * @param amount The payment amount
     */
    public void recordPaymentAmount(double amount) {
        this.paymentsAmountCounter.increment(amount);
    }
}

