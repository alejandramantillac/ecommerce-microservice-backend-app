package com.selimhorri.app.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;

/**
 * Business metrics for Product Service
 * Tracks product-related business events
 */
@Component
@RequiredArgsConstructor
public class BusinessMetrics {

    private final MeterRegistry meterRegistry;

    // Counters
    private Counter productsViewedCounter;
    private Counter productsSearchedCounter;
    private Counter productsAddedToCartCounter;

    @PostConstruct
    public void init() {
        // Initialize counters
        this.productsViewedCounter = Counter.builder("products.viewed.total")
                .description("Total number of product views")
                .register(meterRegistry);

        this.productsSearchedCounter = Counter.builder("products.searched.total")
                .description("Total number of product searches")
                .register(meterRegistry);

        this.productsAddedToCartCounter = Counter.builder("products.added.to.cart.total")
                .description("Total number of products added to cart")
                .register(meterRegistry);
    }

    /**
     * Record a product view event
     */
    public void recordProductViewed() {
        this.productsViewedCounter.increment();
    }

    /**
     * Record a product search event
     */
    public void recordProductSearched() {
        this.productsSearchedCounter.increment();
    }

    /**
     * Record a product added to cart event
     */
    public void recordProductAddedToCart() {
        this.productsAddedToCartCounter.increment();
    }
}

