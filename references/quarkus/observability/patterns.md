# Quarkus Observability Patterns

Use these patterns for health checks, metrics, tracing, and logging workflows.

## Pattern: Readiness check gating on external dependency

When to use:

- The application depends on an external service and should not receive traffic until it is reachable.

```java
@Readiness
@ApplicationScoped
public class PaymentGatewayCheck implements HealthCheck {

    @Inject PaymentClient client;

    @Override
    public HealthCheckResponse call() {
        try {
            client.ping();
            return HealthCheckResponse.up("payment-gateway");
        } catch (Exception e) {
            return HealthCheckResponse.named("payment-gateway")
                .down()
                .withData("error", e.getMessage())
                .build();
        }
    }
}
```

Kubernetes readinessProbe maps to `/q/health/ready`. The pod is removed from the Service until the check passes.

## Pattern: Custom business metrics with Micrometer

When to use:

- You need to track domain-specific counters, gauges, or timers beyond built-in HTTP/JVM metrics.

```java
@ApplicationScoped
public class OrderService {

    private final Counter ordersPlaced;
    private final Counter ordersFailed;
    private final Timer orderLatency;
    private final AtomicInteger activeOrders;

    OrderService(MeterRegistry registry) {
        ordersPlaced = registry.counter("orders.placed", "channel", "web");
        ordersFailed = registry.counter("orders.failed", "channel", "web");
        orderLatency = registry.timer("orders.latency");
        activeOrders = registry.gauge("orders.active", new AtomicInteger(0));
    }

    @Transactional
    public Order placeOrder(OrderRequest req) {
        activeOrders.incrementAndGet();
        try {
            return orderLatency.record(() -> {
                Order order = processOrder(req);
                ordersPlaced.increment();
                return order;
            });
        } catch (Exception e) {
            ordersFailed.increment();
            throw e;
        } finally {
            activeOrders.decrementAndGet();
        }
    }
}
```

## Pattern: Trace propagation across HTMX requests

When to use:

- You want distributed traces to connect HTMX fragment requests to backend service calls.

HTMX requests are standard HTTP -- OpenTelemetry auto-instruments them on the server side. Each `hx-get`, `hx-post`, etc. becomes a new trace or child span.

To correlate multiple HTMX requests from the same page load, propagate a correlation ID:

```java
@Provider
@Priority(Priorities.HEADER_DECORATOR)
public class TraceResponseFilter implements ContainerResponseFilter {

    @Override
    public void filter(ContainerRequestContext req, ContainerResponseContext res) {
        String traceId = Span.current().getSpanContext().getTraceId();
        if (traceId != null && !traceId.equals("00000000000000000000000000000000")) {
            res.getHeaders().putSingle("X-Trace-ID", traceId);
        }
    }
}
```

## Pattern: Structured logging with MDC context

When to use:

- You need request-scoped context (user ID, tenant, correlation ID) in every log line.

```java
@Provider
@Priority(Priorities.HEADER_DECORATOR)
public class MdcFilter implements ContainerRequestFilter, ContainerResponseFilter {

    @Inject SecurityIdentity identity;

    @Override
    public void filter(ContainerRequestContext req) {
        MDC.put("requestId", UUID.randomUUID().toString());
        MDC.put("method", req.getMethod());
        MDC.put("path", req.getUriInfo().getPath());
        if (!identity.isAnonymous()) {
            MDC.put("userId", identity.getPrincipal().getName());
        }
    }

    @Override
    public void filter(ContainerRequestContext req, ContainerResponseContext res) {
        MDC.clear();
    }
}
```

```properties
%prod.quarkus.log.console.json=true
quarkus.log.console.format=%d{HH:mm:ss} %-5p [%c] (req=%X{requestId} user=%X{userId}) %s%e%n
```

## Pattern: Health check for Flyway migrations

When to use:

- The application should report as not-started until database migrations complete.

```java
@Startup
@ApplicationScoped
public class FlywayMigrationCheck implements HealthCheck {

    @Inject Flyway flyway;

    @Override
    public HealthCheckResponse call() {
        var info = flyway.info();
        var pending = info.pending();
        if (pending.length > 0) {
            return HealthCheckResponse.named("flyway-migrations")
                .down()
                .withData("pending", pending.length)
                .build();
        }
        return HealthCheckResponse.named("flyway-migrations")
            .up()
            .withData("applied", info.applied().length)
            .build();
    }
}
```

## Pattern: Disable observability in tests

When to use:

- Observability extensions slow down tests or interfere with assertions.

```properties
%test.quarkus.smallrye-health.extensions.enabled=false
%test.quarkus.micrometer.enabled=false
%test.quarkus.otel.enabled=false
%test.quarkus.otel.traces.exporter=none
```

Or selectively enable for observability-specific tests using a test profile:

```java
public class ObservabilityTestProfile implements QuarkusTestProfile {
    @Override
    public Map<String, String> getConfigOverrides() {
        return Map.of(
            "quarkus.micrometer.enabled", "true",
            "quarkus.smallrye-health.extensions.enabled", "true"
        );
    }
}
```

## Pattern: Test health check endpoints

When to use:

- You need to verify that custom health checks report correct status.

```java
@QuarkusTest
class HealthCheckTest {

    @Test
    void liveness_returnsUp() {
        given()
            .when().get("/q/health/live")
            .then()
            .statusCode(200)
            .body("status", is("UP"));
    }

    @Test
    void readiness_returnsUp_whenDependenciesAvailable() {
        given()
            .when().get("/q/health/ready")
            .then()
            .statusCode(200)
            .body("status", is("UP"))
            .body("checks.name", hasItem("external-service"));
    }
}
```

## Pattern: Test custom metrics

When to use:

- You need to verify that business metrics are correctly recorded.

```java
@QuarkusTest
@TestProfile(ObservabilityTestProfile.class)
class MetricsTest {

    @Test
    void orderPlaced_incrementsCounter() {
        // Place an order
        given()
            .contentType("application/json")
            .body("{\"item\": \"widget\", \"quantity\": 1}")
            .when().post("/api/orders")
            .then().statusCode(201);

        // Verify the metric
        given()
            .when().get("/q/metrics")
            .then()
            .statusCode(200)
            .body(containsString("orders_placed_total"));
    }
}
```
