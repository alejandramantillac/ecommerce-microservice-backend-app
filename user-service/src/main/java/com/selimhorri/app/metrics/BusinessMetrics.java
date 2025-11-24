package com.selimhorri.app.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Business metrics for User Service
 * Tracks user-related business events
 */
@Component
@RequiredArgsConstructor
public class BusinessMetrics {

    private final MeterRegistry meterRegistry;

    // Counters
    private Counter usersRegisteredCounter;
    private Counter usersLoggedInCounter;

    // Gauges
    private final AtomicLong activeUsersCount = new AtomicLong(0);

    @PostConstruct
    public void init() {
        // Initialize counters
        this.usersRegisteredCounter = Counter.builder("users.registered.total")
                .description("Total number of users registered")
                .register(meterRegistry);

        this.usersLoggedInCounter = Counter.builder("users.logged.in.total")
                .description("Total number of user login events")
                .register(meterRegistry);

        // Initialize gauge for active users
        Gauge.builder("users.active.current", activeUsersCount, AtomicLong::get)
                .description("Current number of active users")
                .register(meterRegistry);
    }

    /**
     * Record a new user registration
     */
    public void recordUserRegistered() {
        this.usersRegisteredCounter.increment();
        this.activeUsersCount.incrementAndGet();
    }

    /**
     * Record a user login event
     */
    public void recordUserLoggedIn() {
        this.usersLoggedInCounter.increment();
    }

    /**
     * Increment active users count
     */
    public void incrementActiveUsers() {
        this.activeUsersCount.incrementAndGet();
    }

    /**
     * Decrement active users count
     */
    public void decrementActiveUsers() {
        long current = this.activeUsersCount.get();
        if (current > 0) {
            this.activeUsersCount.decrementAndGet();
        }
    }

    /**
     * Set active users count
     * @param count The number of active users
     */
    public void setActiveUsers(long count) {
        this.activeUsersCount.set(count);
    }
}

