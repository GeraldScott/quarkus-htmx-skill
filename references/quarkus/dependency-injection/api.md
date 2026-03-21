# Quarkus Dependency Injection Reference (CDI / ArC)

Use this module when the task is about Quarkus CDI/ArC dependency injection: bean discovery, scopes, qualifiers, producers, lifecycle, interception, and ArC settings.

## Overview

Quarkus dependency injection is powered by ArC, a build-time optimized CDI implementation.

- Based on Jakarta CDI (CDI Lite) with selected CDI Full features.
- Optimized for fast startup and low memory via build-time analysis.
- Focuses on type-safe injection, explicit scopes, and fail-fast resolution.
- Includes Quarkus-specific capabilities for defaults, conditional beans, and lookup ergonomics.

## General guidelines

- Default to `@ApplicationScoped` unless a narrower scope is required.
- Prefer constructor injection for required dependencies and store them in private final fields.
- Prefer type-safe qualifiers; use `@Identifier` over `@Named` for internal wiring.
- Avoid private injection points, observers, and producer methods to reduce reflection usage in native builds.
- Use programmatic lookup (`Instance<T>`) only when static injection is not sufficient.

---

## Core model

```java
@ApplicationScoped
class GreetingService {
    String hello(String name) {
        return "Hello " + name;
    }
}

@Path("/hello")
class GreetingResource {
    private final GreetingService service;

    GreetingResource(GreetingService service) {
        this.service = service;
    }

    @GET
    String hello() {
        return service.hello("quarkus");
    }
}
```

## Bean discovery

Class beans need a bean-defining annotation:

```java
@ApplicationScoped
class InventoryService {
}
```

Producer and observer methods are discovered even if declaring class has no scope:

```java
class DiscoverySupport {
    @Produces
    Clock clock() {
        return Clock.systemUTC();
    }

    void onStart(@Observes StartupEvent event) {
    }
}
```

Index dependencies explicitly when needed:

```properties
quarkus.index-dependency.acme.group-id=org.acme
quarkus.index-dependency.acme.artifact-id=acme-api
```

## Injection API

Constructor + field + initializer method injection:

```java
@ApplicationScoped
class CheckoutService {
    @Inject
    InventoryService inventory;

    private final PricingService pricing;

    CheckoutService(PricingService pricing) {
        this.pricing = pricing;
    }

    @Inject
    void init(AuditService audit) {
        audit.register("checkout");
    }
}
```

Programmatic lookup:

```java
@ApplicationScoped
class StrategySelector {
    @Inject
    Instance<PaymentStrategy> strategies;

    PaymentStrategy pickFirst() {
        for (PaymentStrategy strategy : strategies) {
            return strategy;
        }
        throw new IllegalStateException("No strategy available");
    }
}
```

## Qualifiers

Custom qualifier for multiple implementations:

```java
@Qualifier
@Retention(RUNTIME)
@Target({ TYPE, FIELD, PARAMETER, METHOD })
@interface Fast {
}

interface SearchService {
}

@Fast
@ApplicationScoped
class FastSearchService implements SearchService {
}

@ApplicationScoped
class SearchResource {
    @Inject
    @Fast
    SearchService searchService;
}
```

Internal string-based selection with `@Identifier`:

```java
class PaymentProducers {
    @Produces
    @Identifier("stripe")
    PaymentClient stripe() {
        return new StripeClient();
    }
}

class BillingService {
    @Inject
    @Identifier("stripe")
    PaymentClient client;
}
```

## Scopes

```java
@ApplicationScoped
class AppCache {
}

@RequestScoped
class RequestContext {
}

@SessionScoped
class ShoppingCart {
}

@Dependent
class IdGenerator {
}

@Singleton
class GlobalCounter {
}
```

`@SessionScoped` requires the `quarkus-undertow` extension or an active session context. Use it only when HTTP session semantics are needed.

## Lifecycle callbacks

```java
@ApplicationScoped
class WarmupService {
    @PostConstruct
    void init() {
    }

    void onStart(@Observes StartupEvent event) {
    }

    @PreDestroy
    void shutdown() {
    }
}
```

## Producers

```java
@ApplicationScoped
class ClientProducer {
    @Produces
    @ApplicationScoped
    HttpClient httpClient(@ConfigProperty(name = "remote.timeout-ms") int timeoutMs) {
        return HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(timeoutMs))
                .build();
    }
}
```

## Disposers

Clean up produced resources when the bean is destroyed:

```java
@ApplicationScoped
class ConnectionProducer {
    @Produces
    @RequestScoped
    Connection connection() {
        return dataSource.getConnection();
    }

    void close(@Disposes Connection connection) {
        connection.close();
    }
}
```

The disposer method is called automatically when the scope ends. Match the produced type and qualifiers exactly.

## Interceptors

```java
@InterceptorBinding
@Retention(RUNTIME)
@Target({ TYPE, METHOD })
@interface Logged {
}

@Logged
@Priority(Interceptor.Priority.APPLICATION)
@Interceptor
class LoggingInterceptor {
    @AroundInvoke
    Object log(InvocationContext ctx) throws Exception {
        return ctx.proceed();
    }
}

@Logged
@ApplicationScoped
class BillingService {
    void bill() {
    }
}
```

For decorators, `@Lock`, and `InterceptionProxy`, see `patterns.md`.

## Quarkus-specific CDI APIs

Default/conditional wiring:

```java
@Dependent
class TracerProducer {
    @Produces
    @IfBuildProfile("prod")
    Tracer realTracer() {
        return new RealTracer();
    }

    @Produces
    @DefaultBean
    Tracer noopTracer() {
        return new NoopTracer();
    }
}
```

Lookup enhancements:

```java
@ApplicationScoped
class HandlerRunner {
    @Inject
    @All
    List<Handler> handlers;

    @Inject
    @WithCaching
    Instance<Formatter> formatter;
}
```

Method-level interceptor control:

```java
@Logged
@ApplicationScoped
class ReportService {
    void export() {
    }

    @NoClassInterceptors
    void exportWithoutClassInterceptors() {
    }
}
```

## Dev mode diagnostics endpoints

```bash
quarkus dev
curl http://localhost:8080/q/arc
curl http://localhost:8080/q/arc/beans
curl "http://localhost:8080/q/arc/beans?scope=ApplicationScoped"
curl http://localhost:8080/q/arc/removed-beans
curl http://localhost:8080/q/arc/observers
```

---

## Configuration Reference (ArC)

### High-value properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.arc.remove-unused-beans` | `all` | You need to tune bean removal: `all` removes all unused beans, `none` disables removal, `fwk` keeps unused application beans but still removes unused non-application beans |
| `quarkus.arc.unremovable-types` | - | Programmatic lookup or framework integration causes false-positive removals |
| `quarkus.arc.exclude-types` | - | A discovered type should not become a bean/observer |
| `quarkus.arc.exclude-dependency."name".*` | - | An entire dependency should be excluded from discovery |
| `quarkus.arc.selected-alternatives` | - | Select alternatives globally through config |
| `quarkus.arc.strict-compatibility` | `false` | You need behavior closer to the CDI specification |
| `quarkus.arc.transform-unproxyable-classes` | `true` | Final/unproxyable class transformations should be controlled |
| `quarkus.arc.transform-private-injected-fields` | `true` | Private injected fields should stay private (reflection fallback) |
| `quarkus.arc.fail-on-intercepted-private-method` | `true` | Private intercepted methods should fail build vs warn |
| `quarkus.arc.auto-inject-fields` | `true` | Auto-adding `@Inject` to known qualifier annotations should be disabled |
| `quarkus.arc.auto-producer-methods` | `true` | Auto-detection of producer methods should be disabled |
| `quarkus.arc.dev-mode.monitoring-enabled` | `false` | You want method/event monitoring in Dev UI |
| `quarkus.arc.dev-mode.generate-dependency-graphs` | `auto` | You need explicit dependency graph behavior in dev mode |
| `quarkus.arc.test.disable-application-lifecycle-observers` | `false` | Startup/shutdown observers should not run during tests |
| `quarkus.arc.context-propagation.enabled` | `true` | CDI context propagation with SmallRye Context Propagation must be toggled |

### Bean discovery and indexing

If a dependency is not being discovered as expected, add indexing hints:

```properties
quarkus.index-dependency.acme.group-id=org.acme
quarkus.index-dependency.acme.artifact-id=acme-api
```

Use excludes when discovery pulls in incompatible beans:

```properties
quarkus.arc.exclude-types=org.acme.LegacyBean,org.acme.internal.*,BadBean
quarkus.arc.exclude-dependency.legacy.group-id=org.acme
quarkus.arc.exclude-dependency.legacy.artifact-id=legacy-services
```

### Unused bean removal tuning

Default behavior removes beans considered unused at build time.

Common controls:

```properties
quarkus.arc.remove-unused-beans=all
quarkus.arc.unremovable-types=org.acme.ImportantBean,org.acme.plugin.**
```

Use `none` to disable removal completely if diagnosis is still in progress.

### Strict mode

Enable stricter CDI compatibility checks:

```properties
quarkus.arc.strict-compatibility=true
```

When moving toward strict behavior, also review:

- `quarkus.arc.transform-unproxyable-classes`
- `quarkus.arc.remove-unused-beans`

### Dev mode diagnostics settings

ArC diagnostics and monitoring:

```properties
quarkus.arc.dev-mode.monitoring-enabled=true
quarkus.arc.dev-mode.generate-dependency-graphs=auto
```

Useful logging categories:

```properties
quarkus.log.category."io.quarkus.arc.processor".level=DEBUG
quarkus.log.category."io.quarkus.arc.requestContext".min-level=TRACE
quarkus.log.category."io.quarkus.arc.requestContext".level=TRACE
```

### Pattern syntax for type lists

Properties such as `selected-alternatives`, `exclude-types`, and `unremovable-types` accept:

- Fully qualified class names (`org.acme.Foo`)
- Simple class names (`Foo`)
- Package match (`org.acme.*`)
- Package prefix match (`org.acme.**`)
