# CDI Events Reference

Use this module when the task is about in-process domain events with Jakarta CDI in Quarkus: `Event<T>`, `@Observes`, `@ObservesAsync`, transactional observers, and deciding when CDI events are enough.

## Overview

CDI events are the lightest eventing model in Quarkus.

- Use them when producers and observers live in the same service.
- Prefer them for portable, type-safe in-process choreography.
- Use transactional observers to align side effects with commit outcome.
- Move to `vertx-event-bus` for local request/reply or event-loop driven messaging.
- Move to `messaging` when events must cross service or process boundaries.

## Decision Fit

```text
Is the event crossing a service/process boundary?
+-- YES -> messaging
+-- NO (in-process only)
      |
      Do you need clustering or non-blocking event loop behavior?
      +-- YES -> vertx-event-bus
      +-- NO
            |
            Do you want portability and type safety?
            +-- YES -> cdi-events
```

---

## CDI Events API

### Fire a local domain event

```java
record OrderPlaced(String id) {
}

@ApplicationScoped
class Orders {
    @Inject
    Event<OrderPlaced> orderPlaced;

    @Transactional
    void place(String id) {
        orderPlaced.fire(new OrderPlaced(id));
    }
}
```

### Observe synchronously

```java
@ApplicationScoped
class AuditLog {
    void onOrder(@Observes OrderPlaced event) {
    }
}
```

`@Observes` runs in-process and synchronously with the firing call.

### Observe asynchronously

```java
@ApplicationScoped
class Notifications {
    void onOrder(@ObservesAsync OrderPlaced event) {
    }
}

@ApplicationScoped
class OrderNotifier {
    @Inject
    Event<OrderPlaced> orderPlaced;

    CompletionStage<OrderPlaced> notifyAsync(String id) {
        return orderPlaced.fireAsync(new OrderPlaced(id));
    }
}
```

`@ObservesAsync` is still in-process. It is async dispatch, not messaging with durability.

### Transactional observers

```java
@ApplicationScoped
class AuditLog {
    void onOrder(@Observes(during = TransactionPhase.AFTER_SUCCESS) OrderPlaced event) {
    }
}
```

Useful phases:

- `IN_PROGRESS` - default, inside the current transaction
- `BEFORE_COMPLETION` - just before commit
- `AFTER_SUCCESS` - only after commit succeeds
- `AFTER_FAILURE` - only after rollback
- `AFTER_COMPLETION` - after transaction completion regardless of result

Prefer `AFTER_SUCCESS` for side effects that should happen only after a successful commit.

### Observer ordering with `@Priority`

Control the order in which multiple observers for the same event type run:

```java
import jakarta.annotation.Priority;

@ApplicationScoped
class AuditLog {
    void onOrder(@Observes @Priority(10) OrderPlaced event) {
        // runs first
    }
}

@ApplicationScoped
class Notifications {
    void onOrder(@Observes @Priority(20) OrderPlaced event) {
        // runs second
    }
}
```

Lower values run first. Observers without `@Priority` run after prioritized ones.

### Qualified events

Filter observers by qualifier so they only receive matching events:

```java
@Qualifier
@Retention(RUNTIME)
@Target({ TYPE, METHOD, FIELD, PARAMETER })
@interface Critical {
}

@ApplicationScoped
class AlertService {
    @Inject
    @Critical
    Event<OrderPlaced> criticalOrders;

    void escalate(String id) {
        criticalOrders.fire(new OrderPlaced(id));
    }
}

@ApplicationScoped
class PagerDutyListener {
    void onCritical(@Observes @Critical OrderPlaced event) {
        // only receives events fired with @Critical qualifier
    }
}
```

---

## Configuration Reference

### High-value properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.arc.test.disable-application-lifecycle-observers` | `false` | Startup and shutdown observers should not run during tests |
| `quarkus.arc.exclude-types` | - | A discovered observer type should be excluded from CDI discovery |
| `quarkus.arc.exclude-dependency."name".*` | - | An entire dependency brings in unwanted observers |
| `quarkus.arc.remove-unused-beans` | `all` | You are diagnosing build-time bean removal that may affect observer discovery |
| `quarkus.arc.unremovable-types` | - | Programmatic lookup or framework integration makes an observer bean look unused |
| `quarkus.arc.dev-mode.monitoring-enabled` | `false` | You want extra dev-mode visibility for CDI behavior |

### Test-focused lifecycle control

```properties
quarkus.arc.test.disable-application-lifecycle-observers=true
```

This affects lifecycle observers such as startup or shutdown events, not normal domain-event observers fired by your own code.

### Discovery exclusions

```properties
quarkus.arc.exclude-types=org.acme.legacy.LegacyObserver,org.acme.internal.*
quarkus.arc.exclude-dependency.legacy.group-id=org.acme
quarkus.arc.exclude-dependency.legacy.artifact-id=legacy-events
```

Use exclusions when third-party observers should not become active in the application.

## See Also

- `../dependency-injection/` - Broader CDI/ArC injection, scopes, qualifiers, and bean model
- `../vertx-event-bus/` - Local async request/reply and event-loop friendly messaging
- `../messaging/` - Broker-backed asynchronous messaging across service boundaries
