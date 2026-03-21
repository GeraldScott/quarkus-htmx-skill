# Dependency Injection (CDI / ArC) Reference

Service beans are injected into JAX-RS resources that serve Qute/HTMX responses.
This reference covers Quarkus CDI APIs, patterns, configuration, and common pitfalls.

---

## Overview and guidelines

- Quarkus uses **ArC**, a build-time CDI implementation. Bean wiring is resolved at build time, not runtime.
- Prefer **constructor injection** for required dependencies (no `@Inject` needed with a single constructor).
- Use **`@Identifier`** over `@Named` for internal string-based bean selection.
- Normal-scoped beans (`@ApplicationScoped`, `@RequestScoped`) are **client proxies** -- invoke methods, never access fields directly.
- Use `@ApplicationScoped` for stateless services; `@Dependent` for short-lived or stateful-per-injection-point beans.
- Keep injected members **package-private** where possible to avoid reflection in native builds.

---

## Core injection model (constructor, field, programmatic)

### Constructor injection (preferred)

```java
@ApplicationScoped
class OrderService {
    private final PaymentClient paymentClient;

    OrderService(PaymentClient paymentClient) {
        this.paymentClient = paymentClient;
    }
}
```

With Lombok:

```java
import lombok.RequiredArgsConstructor;

@ApplicationScoped
@RequiredArgsConstructor
class OrderService {
    private final PaymentClient paymentClient;
}
```

With a single generated constructor, Quarkus injects dependencies without an explicit `@Inject`.

### Field and initializer method injection

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

### Programmatic lookup

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

### Basic resource example

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

---

## Bean discovery and scopes

### Bean discovery

Class beans need a bean-defining annotation:

```java
@ApplicationScoped
class InventoryService {
}
```

Producer and observer methods are discovered even if the declaring class has no scope:

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

### Scopes

```java
@ApplicationScoped   // single instance, client proxy, lazy by default
class AppCache {
}

@RequestScoped       // per-request lifecycle
class RequestContext {
}

@Dependent           // new instance per injection point, no proxy
class IdGenerator {
}

@Singleton           // single instance, no proxy, not interceptable by default
class GlobalCounter {
}
```

---

## Qualifiers and @Identifier

### Custom qualifier for multiple implementations

```java
@Qualifier
@Retention(RUNTIME)
@Target({ TYPE, FIELD, PARAMETER, METHOD })
@interface Fast {}

@Fast
@ApplicationScoped
class FastSearch implements SearchEngine {}

@Inject
@Fast
SearchEngine searchEngine;
```

### String-based selection with @Identifier

Prefer `@Identifier("...")` over `@Named("...")` for internal selection.

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

---

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

---

## Lifecycle callbacks

```java
@ApplicationScoped
class WarmupService {
    @PostConstruct
    void init() {
    }

    void onStart(@Observes StartupEvent event) {
        // perform startup work
    }

    @PreDestroy
    void shutdown() {
    }
}
```

Alternative: annotate the bean with `@Startup` to force eager initialization.

---

## Interceptors and decorators

### Interceptors

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

### Decorators

Wrap an existing implementation with business-aware behavior (not just cross-cutting interception).

```java
import jakarta.annotation.Priority;
import jakarta.decorator.Decorator;
import jakarta.decorator.Delegate;
import jakarta.enterprise.inject.Any;
import jakarta.inject.Inject;

interface Notifier {
    void send(String message);
}

@Decorator
@Priority(10)
class NotifierDecorator implements Notifier {
    @Inject
    @Delegate
    @Any
    Notifier delegate;

    @Override
    public void send(String message) {
        delegate.send("[decorated] " + message);
    }
}
```

---

## Quarkus-specific CDI features

### @IfBuildProfile and @DefaultBean

Conditional defaults by profile or property:

```java
@Dependent
class TracerConfig {
    @Produces
    @IfBuildProfile("prod")
    Tracer realTracer() { return new RealTracer(); }

    @Produces
    @DefaultBean
    Tracer noopTracer() { return new NoopTracer(); }
}
```

### @All -- collect all implementations

Pipeline, strategy chain, plugin list, or ordered processing:

```java
@Inject
@All
List<Handler> handlers;
```

`@All List<T>` is immutable and sorted by bean priority (highest first).

### @WithCaching

```java
@Inject
@WithCaching
Instance<Formatter> formatter;
```

### @Lock -- container-managed locking

For `@ApplicationScoped` or `@Singleton` beans with concurrent access:

```java
@Lock
@ApplicationScoped
class BalanceService {
    void mutate() {}

    @Lock(Lock.Type.READ)
    BigDecimal read() { return BigDecimal.ZERO; }
}
```

Use standard Java concurrency when finer-grained control is needed.

### InterceptionProxy -- intercept external classes

When a produced class comes from an external library and cannot be annotated directly:

```java
import io.quarkus.arc.BindingsSource;
import io.quarkus.arc.InterceptionProxy;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;

abstract class ExternalApiBindings {
    @Logged
    abstract String call(String input);
}

@ApplicationScoped
class ExternalApiProducer {
    @Produces
    ExternalApiClient client(
            @BindingsSource(ExternalApiBindings.class)
            InterceptionProxy<ExternalApiClient> proxy) {
        return proxy.create(new ExternalApiClient());
    }
}
```

### @NoClassInterceptors

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

---

## Configuration

### High-value properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.arc.remove-unused-beans` | `all` | Tune bean removal: `all`, `none`, or `fwk` |
| `quarkus.arc.unremovable-types` | - | Programmatic lookup causes false-positive removals |
| `quarkus.arc.exclude-types` | - | A discovered type should not become a bean/observer |
| `quarkus.arc.exclude-dependency."name".*` | - | Entire dependency excluded from discovery |
| `quarkus.arc.selected-alternatives` | - | Select alternatives globally through config |
| `quarkus.arc.strict-compatibility` | `false` | You need behavior closer to the CDI spec |
| `quarkus.arc.transform-unproxyable-classes` | `true` | Control final/unproxyable class transformations |
| `quarkus.arc.transform-private-injected-fields` | `true` | Private injected fields stay private (reflection fallback) |
| `quarkus.arc.fail-on-intercepted-private-method` | `true` | Private intercepted methods fail build vs warn |
| `quarkus.arc.auto-inject-fields` | `true` | Disable auto-adding `@Inject` to qualifier annotations |
| `quarkus.arc.auto-producer-methods` | `true` | Disable auto-detection of producer methods |
| `quarkus.arc.dev-mode.monitoring-enabled` | `false` | Method/event monitoring in Dev UI |
| `quarkus.arc.test.disable-application-lifecycle-observers` | `false` | Skip startup/shutdown observers during tests |
| `quarkus.arc.context-propagation.enabled` | `true` | Toggle CDI context propagation with SmallRye |

### Bean discovery and indexing

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

```properties
quarkus.arc.remove-unused-beans=all
quarkus.arc.unremovable-types=org.acme.ImportantBean,org.acme.plugin.**
```

Use `none` to disable removal completely if diagnosis is still in progress.

### Strict mode

```properties
quarkus.arc.strict-compatibility=true
```

When moving toward strict behavior, also review `quarkus.arc.transform-unproxyable-classes` and `quarkus.arc.remove-unused-beans`.

### Pattern syntax for type lists

Properties such as `selected-alternatives`, `exclude-types`, and `unremovable-types` accept:

- Fully qualified class names (`org.acme.Foo`)
- Simple class names (`Foo`)
- Package match (`org.acme.*`)
- Package prefix match (`org.acme.**`)

### Dev mode diagnostics

```bash
quarkus dev
curl http://localhost:8080/q/arc
curl http://localhost:8080/q/arc/beans
curl "http://localhost:8080/q/arc/beans?scope=ApplicationScoped"
curl http://localhost:8080/q/arc/removed-beans
curl http://localhost:8080/q/arc/observers
```

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

---

## Gotchas

### Injection resolution

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `UnsatisfiedResolutionException` | No bean matches required type/qualifiers | Add a bean-defining scope, correct qualifiers, or verify discovery/indexing |
| `AmbiguousResolutionException` | Multiple beans match the same injection point | Add a qualifier, select alternatives, or use `Instance<T>` |
| Injection unexpectedly ambiguous with `@Named` | `@Named` can interact with `@Default` unexpectedly | Prefer `@Identifier` for internal string-based selection |

### Scope and lifecycle

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `@ApplicationScoped` bean not created at startup | Normal scopes are lazy by default | Observe `StartupEvent` or use `@Startup` |
| Stateful `@ApplicationScoped` bean behaves inconsistently | Shared bean accessed concurrently without protection | Make state thread-safe or use `@Lock` |
| Unexpected behavior when accessing injected bean fields directly | Normal-scoped beans are client proxies | Invoke methods; do not rely on direct field reads/writes |

### Build-time and native

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Native image grows or fails due to reflection | Private injected members force reflective access | Use package-private constructor/fields/methods where possible |
| Bean available in code but missing at runtime | Bean removed as unused during build | Mark bean unremovable (`@Unremovable` or `quarkus.arc.unremovable-types`) |
| Build fails on intercepted private method | Interceptor binding on private method and fail-on-private enabled | Make method non-private or adjust `quarkus.arc.fail-on-intercepted-private-method` |

### Discovery and integration

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Third-party beans are not discovered | Dependency not indexed and no `beans.xml` | Add Jandex index or configure `quarkus.index-dependency.*` |
| Third-party beans break startup | Problematic beans discovered automatically | Exclude with `quarkus.arc.exclude-types` or `quarkus.arc.exclude-dependency.*` |
| CDI Portable Extension does not work | Portable extensions not supported in Quarkus build-time model | Replace with Quarkus extension/build-step approach |

### Dev mode debugging

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `/q/arc/*` endpoints unavailable | Not running in dev mode | Run with `quarkus dev` / `./mvnw quarkus:dev` / `./gradlew quarkusDev` |
| Hard to understand removals/resolution | Diagnostics not enabled | Use ArC endpoints, enable processor DEBUG logs, enable monitoring |
