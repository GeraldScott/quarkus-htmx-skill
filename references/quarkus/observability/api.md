# Quarkus Observability Reference

Use this module when the task involves health checks, metrics, distributed tracing, or structured logging in Quarkus.

## Overview

Quarkus supports three observability pillars: health (SmallRye Health), metrics (Micrometer), and tracing (OpenTelemetry). Each has a dedicated extension with Dev Services support.

## Extensions

```xml
<!-- Health checks -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-smallrye-health</artifactId>
</dependency>

<!-- Metrics (Prometheus) -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-micrometer-registry-prometheus</artifactId>
</dependency>

<!-- Distributed tracing -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-opentelemetry</artifactId>
</dependency>

<!-- Structured JSON logging -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-logging-json</artifactId>
</dependency>
```

## Health Checks

SmallRye Health exposes endpoints at `/q/health`:

| Endpoint | Purpose |
|----------|---------|
| `/q/health/live` | Liveness -- is the process alive? |
| `/q/health/ready` | Readiness -- can it accept traffic? |
| `/q/health/started` | Startup -- has it finished initializing? |
| `/q/health` | All checks combined |

### Built-in checks

Quarkus auto-registers health checks for configured extensions (datasource, Kafka, Redis, etc.). No code needed.

### Custom health checks

```java
import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.Liveness;
import org.eclipse.microprofile.health.Readiness;
import org.eclipse.microprofile.health.Startup;

@Liveness
@ApplicationScoped
public class LivenessCheck implements HealthCheck {
    @Override
    public HealthCheckResponse call() {
        return HealthCheckResponse.up("alive");
    }
}

@Readiness
@ApplicationScoped
public class ExternalServiceCheck implements HealthCheck {

    @Inject ExternalClient client;

    @Override
    public HealthCheckResponse call() {
        boolean reachable = client.ping();
        return HealthCheckResponse.named("external-service")
            .status(reachable)
            .withData("url", client.getUrl())
            .build();
    }
}

@Startup
@ApplicationScoped
public class MigrationCheck implements HealthCheck {
    @Override
    public HealthCheckResponse call() {
        return HealthCheckResponse.up("migrations-applied");
    }
}
```

## Metrics (Micrometer)

Quarkus uses Micrometer with the Prometheus registry. Metrics are exposed at `/q/metrics`.

### Built-in metrics

HTTP request metrics, JVM metrics, and datasource pool metrics are auto-registered.

### Custom metrics

```java
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;

@ApplicationScoped
public class OrderService {

    private final Counter ordersCreated;
    private final Timer orderProcessingTime;

    OrderService(MeterRegistry registry) {
        ordersCreated = Counter.builder("orders.created")
            .description("Number of orders created")
            .tag("type", "web")
            .register(registry);

        orderProcessingTime = Timer.builder("orders.processing.time")
            .description("Time to process an order")
            .register(registry);
    }

    @Transactional
    public Order create(OrderRequest req) {
        return orderProcessingTime.record(() -> {
            Order order = processOrder(req);
            ordersCreated.increment();
            return order;
        });
    }
}
```

### Annotation-based metrics

```java
import io.micrometer.core.annotation.Counted;
import io.micrometer.core.annotation.Timed;

@ApplicationScoped
public class ItemService {

    @Counted(value = "items.searched", description = "Item searches")
    @Timed(value = "items.search.time", description = "Search duration")
    public List<Item> search(String query) {
        return Item.find("name like ?1", "%" + query + "%").list();
    }
}
```

## Distributed Tracing (OpenTelemetry)

Quarkus uses OpenTelemetry for distributed tracing. REST endpoints, REST Client calls, and database queries are traced automatically.

### Configuration

```properties
# OTLP exporter (Jaeger, Grafana Tempo, etc.)
quarkus.otel.exporter.otlp.traces.endpoint=http://localhost:4317

# Service name in traces
quarkus.application.name=my-service

# Sampling (1.0 = trace everything, 0.1 = 10%)
quarkus.otel.traces.sampler=parentbased_traceidratio
quarkus.otel.traces.sampler.arg=1.0
```

### Custom spans

```java
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import io.opentelemetry.instrumentation.annotations.SpanAttribute;

@ApplicationScoped
public class PaymentService {

    @WithSpan("process-payment")
    public Receipt process(
        @SpanAttribute("payment.amount") BigDecimal amount
    ) {
        // automatically creates a child span
        return chargeCard(amount);
    }

    @Inject Tracer tracer;

    public void manualSpan() {
        Span span = tracer.spanBuilder("custom-operation").startSpan();
        try {
            // work
            span.setAttribute("result", "success");
        } finally {
            span.end();
        }
    }
}
```

## Structured Logging

### JSON logging

```properties
# Enable JSON log output (useful for log aggregation)
quarkus.log.console.json=true

# Or only in production
%prod.quarkus.log.console.json=true
```

### Log categories and levels

```properties
# Application logging
quarkus.log.category."com.example".level=DEBUG

# SQL logging
quarkus.log.category."org.hibernate.SQL".level=DEBUG
quarkus.log.category."org.hibernate.type.descriptor.sql.BasicBinder".level=TRACE

# REST request logging
quarkus.log.category."org.jboss.resteasy.reactive".level=DEBUG

# Suppress noisy libraries
quarkus.log.category."io.smallrye.config".level=WARN
```

### Correlation IDs

Add a filter to propagate or generate a correlation ID:

```java
@Provider
@Priority(Priorities.HEADER_DECORATOR)
public class CorrelationFilter implements ContainerRequestFilter, ContainerResponseFilter {

    private static final String CORRELATION_HEADER = "X-Correlation-ID";

    @Override
    public void filter(ContainerRequestContext req) {
        String correlationId = req.getHeaderString(CORRELATION_HEADER);
        if (correlationId == null) {
            correlationId = UUID.randomUUID().toString();
        }
        MDC.put("correlationId", correlationId);
    }

    @Override
    public void filter(ContainerRequestContext req, ContainerResponseContext res) {
        String correlationId = MDC.get("correlationId");
        if (correlationId != null) {
            res.getHeaders().putSingle(CORRELATION_HEADER, correlationId);
        }
        MDC.remove("correlationId");
    }
}
```

Include in log format:

```properties
quarkus.log.console.format=%d{HH:mm:ss} %-5p [%c] (correlation=%X{correlationId}) %s%e%n
```

---

## Configuration Reference

### Health

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.smallrye-health.root-path` | `/q/health` | Health endpoint path must change |
| `quarkus.health.extensions.enabled` | `true` | Auto-registered extension checks should be disabled |
| `quarkus.datasource.health.enabled` | `true` | Datasource health check should be disabled |

### Metrics

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.micrometer.enabled` | `true` | Metrics must be disabled entirely |
| `quarkus.micrometer.export.prometheus.path` | `/q/metrics` | Metrics endpoint path must change |
| `quarkus.micrometer.binder.http-server.enabled` | `true` | HTTP server metrics should be disabled |
| `quarkus.micrometer.binder.jvm` | `true` | JVM metrics should be disabled |

### Tracing

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.otel.enabled` | `true` | Tracing must be disabled entirely |
| `quarkus.otel.exporter.otlp.traces.endpoint` | `http://localhost:4317` | OTLP collector address must change |
| `quarkus.otel.traces.sampler` | `parentbased_always_on` | Sampling strategy must change |
| `quarkus.otel.traces.sampler.arg` | `1.0` | Sampling ratio must be tuned |
| `quarkus.otel.resource.attributes` | - | Custom resource attributes needed |

### Logging

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.log.level` | `INFO` | Global log level must change |
| `quarkus.log.console.json` | `false` | JSON structured logging needed |
| `quarkus.log.console.format` | default pattern | Custom log format needed |
| `quarkus.log.file.enable` | `false` | File logging must be enabled |
| `quarkus.log.file.path` | `quarkus.log` | Log file path must change |

### Kubernetes probe integration

```properties
# Kubernetes probes map to health endpoints:
# livenessProbe  -> /q/health/live
# readinessProbe -> /q/health/ready
# startupProbe   -> /q/health/started
```

When using `quarkus-kubernetes`, probes are auto-configured in the generated manifests.
