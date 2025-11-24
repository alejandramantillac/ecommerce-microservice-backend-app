package com.selimhorri.app.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Business metrics for Order Service
 * Tracks order-related business events
 */
@Component
@RequiredArgsConstructor
public class BusinessMetrics {

    private final MeterRegistry meterRegistry;

    // Counters
    private Counter ordersCreatedCounter;
    private Counter ordersCompletedCounter;
    private Counter ordersFailedCounter;
    private Counter ordersValueCounter;

    // Gauges
    private final AtomicLong totalOrdersValue = new AtomicLong(0);
    private final AtomicLong totalOrdersCount = new AtomicLong(0);

    @PostConstruct
    public void init() {
        // Initialize counters
        this.ordersCreatedCounter = Counter.builder("orders.created.total")
                .description("Total number of orders created")
                .register(meterRegistry);

        this.ordersCompletedCounter = Counter.builder("orders.completed.total")
                .description("Total number of orders completed")
                .register(meterRegistry);

        this.ordersFailedCounter = Counter.builder("orders.failed.total")
                .description("Total number of orders that failed")
                .register(meterRegistry);

        this.ordersValueCounter = Counter.builder("orders.value.total")
                .description("Total value of all orders")
                .baseUnit("currency")
                .register(meterRegistry);

        // Initialize gauge for average order value
        Gauge.builder("orders.average.value", () -> {
            long count = totalOrdersCount.get();
            if (count == 0) {
                return 0.0;
            }
            return totalOrdersValue.get() / (double) count;
        })
                .description("Average value of orders")
                .baseUnit("currency")
                .register(meterRegistry);
    }

    /**
     * Record a new order creation
     * @param orderValue The value of the order
     */
    public void recordOrderCreated(double orderValue) {
        this.ordersCreatedCounter.increment();
        this.ordersValueCounter.increment(orderValue);
        this.totalOrdersValue.addAndGet((long) orderValue);
        this.totalOrdersCount.incrementAndGet();
    }

    /**
     * Record an order completion
     */
    public void recordOrderCompleted() {
        this.ordersCompletedCounter.increment();
    }

    /**
     * Record an order failure
     */
    public void recordOrderFailed() {
        this.ordersFailedCounter.increment();
    }

    /**
     * Record order value
     * @param orderValue The value of the order
     */
    public void recordOrderValue(double orderValue) {
        this.ordersValueCounter.increment(orderValue);
        this.totalOrdersValue.addAndGet((long) orderValue);
    }
}

