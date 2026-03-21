# Messaging & Events Reference

Quarkus offers three messaging tiers. Pick the lightest tier that satisfies the requirement,
then graduate upward only when you need the next tier's capabilities.

## Decision guide

| Need | Tier | Why |
|------|------|-----|
| Decouple beans inside one service, type-safe | **CDI Events** | Zero config, synchronous or async, transaction-aware |
| Address-based routing, request/reply inside one app | **Vert.x Event Bus** | Lightweight, supports send/publish/request, non-blocking by default |
| Durable delivery, cross-service, broker features (replay, consumer groups, back-pressure) | **Reactive Messaging** | Broker-backed (Kafka, AMQP, RabbitMQ, Pulsar), channel-based wiring |

Rules of thumb:

- Start with CDI Events for local choreography.
- Move to Vert.x Event Bus when you need address-based dispatch or request/reply without a broker.
- Move to Reactive Messaging when the event must leave the process, survive restarts, or leverage broker semantics.

---

## CDI Events (same-process, type-safe)

No extension required -- CDI events are part of the core Quarkus runtime.

### Fire and observe

Fire a domain event:

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

Observe synchronously:

```java
@ApplicationScoped
class AuditLog {
    void onOrder(@Observes OrderPlaced event) {
    }
}
```

`@Observes` runs in-process and synchronously with the firing call.

### Async observers

```java
@ApplicationScoped
class Notifications {
    void onOrder(@ObservesAsync OrderPlaced event) {
        // runs on a separate thread
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
If failure handling, retries, or durability become important, graduate this flow to broker-backed messaging.

### Transactional observers

```java
@ApplicationScoped
class AuditLog {
    void onOrder(@Observes(during = TransactionPhase.AFTER_SUCCESS) OrderPlaced event) {
    }
}
```

Useful phases:

- `IN_PROGRESS` -- default, inside the current transaction
- `BEFORE_COMPLETION` -- just before commit
- `AFTER_SUCCESS` -- only after commit succeeds
- `AFTER_FAILURE` -- only after rollback
- `AFTER_COMPLETION` -- after transaction completion regardless of result

Prefer `AFTER_SUCCESS` for side effects that should happen only after a successful commit.

**Pattern -- Domain event after successful transaction:**

```java
record UserRegistered(String username) {
}

@ApplicationScoped
class UserService {
    @Inject
    Event<UserRegistered> events;

    @Transactional
    void register(String username) {
        repository.persist(new User(username));
        events.fire(new UserRegistered(username));
    }
}

@ApplicationScoped
class AuditListener {
    void onRegistered(@Observes(during = TransactionPhase.AFTER_SUCCESS) UserRegistered event) {
        audit.write(event.username());
    }
}
```

**Pattern -- Optional async side effects:**

```java
@ApplicationScoped
class WelcomeEmailListener {
    void onRegistered(@ObservesAsync UserRegistered event) {
        mailer.send(event.username());
    }
}
```

**Pattern -- Escalate to an outbox when local events need cross-service reliability:**

```java
@ApplicationScoped
class UserService {
    @Transactional
    void register(String username) {
        userRepository.persist(new User(username));
        OutboxRecord.persist(OutboxRecord.userRegistered(username));
    }
}
```

Persist the outbox record in the same transaction as the business write, then publish it to a broker from a separate background component.

### Gotchas

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Async observer never runs | Event fired with `fire()` but observer uses `@ObservesAsync` | Use `fireAsync()` for async observers, or switch the observer to `@Observes` |
| Async observer exception seems lost | `fireAsync()` completion is ignored | Observe the returned `CompletionStage` and handle exceptional completion |
| Side effect runs even though transaction rolled back | Observer ran in the default `IN_PROGRESS` phase | Use `@Observes(during = TransactionPhase.AFTER_SUCCESS)` for post-commit side effects |
| Expecting CDI events to reach another service | CDI events are same-process only and not durable | Use Reactive Messaging for broker-backed delivery |
| Using async observers as a reactive pipeline stage | `@ObservesAsync` is thread-offloaded dispatch, not a stream operator | Keep observers `void` and use reactive APIs for stream composition |

**Key configuration properties:**

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.arc.test.disable-application-lifecycle-observers` | `false` | Startup/shutdown observers should not run during tests |
| `quarkus.arc.remove-unused-beans` | `all` | Diagnosing build-time bean removal that may affect observer discovery |
| `quarkus.arc.unremovable-types` | - | Framework integration makes an observer bean look unused |

---

## Vert.x Event Bus (same-process, address-based)

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-vertx</artifactId>
</dependency>
```

### @ConsumeEvent and EventBus

Declarative consumer:

```java
@ApplicationScoped
class GreetingService {
    @ConsumeEvent("greeting")
    String greet(String name) {
        return "Hello " + name;
    }
}
```

If no address is provided, the fully qualified bean class name is used.

Inject and use the `EventBus`:

```java
@Path("/bus")
@ApplicationScoped
class GreetingResource {
    @Inject
    EventBus bus;

    @GET
    @Path("/{name}")
    Uni<String> greet(String name) {
        return bus.<String>request("greeting", name)
                .onItem().transform(Message::body);
    }
}
```

### Send, publish, request

```java
bus.send("jobs", job);                  // one consumer receives the message
bus.publish("notifications", notice);   // all consumers on the address receive it
Uni<String> response = bus.<String>request("greeting", "quarkus")
        .onItem().transform(Message::body);  // expect a reply
```

Consume the full `Message<T>` when you need headers, address, or manual reply:

```java
@ConsumeEvent("jobs")
void consume(Message<Job> message) {
    Job job = message.body();
}
```

Async handlers return `Uni<T>` or `CompletionStage<T>`:

```java
@ConsumeEvent("greeting")
Uni<String> greetAsync(String name) {
    return Uni.createFrom().item(() -> name.toUpperCase());
}
```

Blocking handlers must move off the event loop:

```java
@ConsumeEvent("reports")
@Blocking
void generateReport(String id) {
}
```

Virtual-thread consumers (Java 21+, blocking signatures only):

```java
@ConsumeEvent("imports")
@RunOnVirtualThread
void importBatch(String payload) {
}
```

Config-driven addresses:

```java
@ConsumeEvent("${app.events.greeting-address:greeting}")
String greet(String name) {
    return name.toUpperCase();
}
```

**Pattern -- Bridge HTTP to request/reply:**

```java
@Path("/async")
@ApplicationScoped
class EventResource {
    @Inject
    EventBus bus;

    @GET
    @Path("/{name}")
    Uni<String> greeting(String name) {
        return bus.<String>request("greeting", name)
                .onItem().transform(Message::body);
    }
}

@ApplicationScoped
class GreetingService {
    @ConsumeEvent("greeting")
    String greeting(String name) {
        return "Hello " + name;
    }
}
```

**Pattern -- Publish to all local consumers:**

```java
@ApplicationScoped
class NotificationPublisher {
    @Inject
    EventBus bus;

    void publish(Notification notice) {
        bus.publish("notifications", notice);
    }
}
```

Use `publish`, not `send`, when every consumer on the address should receive the message.

**Pattern -- Offload blocking work:**

```java
@ApplicationScoped
class PdfConsumer {
    @ConsumeEvent("pdf-jobs")
    @Blocking
    void render(String jobId) {
        renderer.render(jobId);
    }
}
```

### Gotchas

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Request times out waiting for a reply | No consumer on the address, or consumer does not return a reply | Add a matching `@ConsumeEvent` or use fire-and-forget instead |
| Only one consumer receives but all were expected to | `send` uses point-to-point delivery | Use `publish` for fan-out |
| Handler blocks event-loop threads | Consumer performs blocking work without `@Blocking` | Add `@Blocking` or redesign around async APIs |
| `@RunOnVirtualThread` has no effect | Virtual-thread handlers require blocking signatures | Use `void` or plain return types, not `Uni` or `CompletionStage` |
| Startup fails on `@ConsumeEvent("${...}")` | Config property is missing and no default was provided | Add the property or include a default in the expression |
| Expecting back-pressure, replay, or stream operators | Event Bus delivers messages, not broker-managed streams | Use Reactive Messaging for stream processing and broker-backed flow control |
| Event bus used for cross-service durable events | Event bus is local transport, not a durable broker | Use Reactive Messaging with Kafka, RabbitMQ, or AMQP |

**Key configuration properties:**

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.vertx.event-loops-pool-size` | CPU-count based | Tune event-loop parallelism |
| `quarkus.vertx.max-event-loop-execute-time` | `2S` | Detect handlers that block the event loop too long |
| `quarkus.vertx.warning-exception-time` | `2S` | Control when blocked-event-loop warnings appear |

---

## Reactive Messaging (broker-backed: Kafka, AMQP, etc.)

Choose the connector that matches the broker:

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-messaging-kafka</artifactId>
</dependency>
```

Other common choices: `quarkus-messaging-rabbitmq`, `quarkus-messaging-amqp`, `quarkus-messaging-pulsar`.

### Channel annotations

Transform a stream from one channel to another:

```java
@ApplicationScoped
class PriceProcessor {
    @Incoming("prices-in")
    @Outgoing("prices-out")
    String normalize(String payload) {
        return payload.trim().toUpperCase();
    }
}
```

Consume only:

```java
@ApplicationScoped
class AuditConsumer {
    @Incoming("audit")
    void onMessage(String payload) {
    }
}
```

Produce only:

```java
@ApplicationScoped
class SeedProducer {
    @Outgoing("seed")
    Multi<String> seed() {
        return Multi.createFrom().items("a", "b", "c");
    }
}
```

Do not call `@Incoming` or `@Outgoing` methods directly from user code; Quarkus invokes them.

Stream processing -- operate on the whole `Multi`:

```java
@Incoming("source")
@Outgoing("sink")
Multi<String> process(Multi<String> input) {
    return input.map(String::toUpperCase);
}
```

Fan-out with `@Broadcast`:

```java
@Incoming("raw")
@Outgoing("enriched")
@Broadcast
String enrich(String payload) {
    return payload.toUpperCase();
}
```

Fan-in with `@Merge`:

```java
@Incoming("merged")
@Merge
void consume(String payload) {
}
```

Execution control:

```java
@Incoming("jobs")
@Blocking
void runBlocking(Job job) {
}

@Incoming("imports")
@RunOnVirtualThread
void importBatch(Batch batch) {
}
```

`@Transactional` implies blocking execution.

### Emitter for imperative publishing

Send from REST, scheduled jobs, or other imperative entry points:

```java
@Path("/orders")
@ApplicationScoped
class OrderResource {
    @Channel("orders-out")
    MutinyEmitter<OrderPlaced> emitter;

    @POST
    Response create(OrderPlaced order) {
        emitter.sendAndAwait(order);
        return Response.accepted().build();
    }
}
```

Use `MutinyEmitter<T>` for Mutiny-style APIs. Plain `Emitter<T>` returns `CompletionStage<Void>` from `send()`.

Inject a channel as a reactive stream:

```java
@Path("/prices")
@ApplicationScoped
class PriceStreamResource {
    @Channel("prices")
    Multi<Double> prices;

    @GET
    Multi<Double> stream() {
        return prices;
    }
}
```

**Pattern -- Transform between channels:**

```java
@ApplicationScoped
class PaymentProcessor {
    @Incoming("payments-in")
    @Outgoing("payments-out")
    PaymentApproved process(PaymentReceived payment) {
        return new PaymentApproved(payment.id());
    }
}
```

Prefer payload signatures until you need metadata or custom ack control.

**Pattern -- Internal channels (no broker):**

```java
@ApplicationScoped
class CommandGateway {
    @Channel("internal-orders")
    Emitter<OrderPlaced> emitter;

    void submit(OrderPlaced order) {
        emitter.send(order);
    }
}

@ApplicationScoped
class OrderProjector {
    @Incoming("internal-orders")
    void project(OrderPlaced order) {
    }
}
```

Use internal channels only when you specifically need channel composition, stream wiring, or back-pressure.
If you do not need those, plain CDI events are simpler.

### Testing with InMemoryConnector

Fast JVM tests without Docker or Dev Services:

```java
public class MessagingTestResource implements QuarkusTestResourceLifecycleManager {
    @Override
    public Map<String, String> start() {
        Map<String, String> env = new HashMap<>();
        env.putAll(InMemoryConnector.switchIncomingChannelsToInMemory("orders-in"));
        env.putAll(InMemoryConnector.switchOutgoingChannelsToInMemory("orders-out"));
        return env;
    }

    @Override
    public void stop() {
        InMemoryConnector.clear();
    }
}
```

Use Dev Services or real brokers for connector-specific metadata, serialization, and native-test coverage.

### Gotchas

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `@Incoming` method never runs | Method was called directly instead of letting the runtime wire channels | Trigger through broker, emitter, or in-memory channel |
| Deployment fails: channel has multiple consumers | One producer feeds multiple consumers without `@Broadcast` | Add `@Broadcast` on the outgoing side |
| Deployment fails: channel has multiple producers | Several methods publish to one channel without `@Merge` | Add `@Merge` on the incoming side |
| Consumer blocks or stalls under load | Blocking I/O runs on an event-loop-dispatched handler | Add `@Blocking` or `@RunOnVirtualThread` |
| Security context disappears across channels | Connector context propagation is disabled by default | Pass data in the message, or set `quarkus.messaging.connector-context-propagation=CDI` |
| Need dynamic topics at runtime | Reactive Messaging channels are fixed at startup | Use low-level broker clients for dynamic topology |
| No per-channel metrics | Observation metrics are disabled by default | Set `smallrye.messaging.observation.enabled=true` and include Micrometer |
| Health checks fail during local dev | Channel health enabled but broker unavailable | Disable channel checks for that env or use Dev Services |
| In-memory tests pass but production differs | `InMemoryConnector` skips real serialization and metadata | Add integration tests against a real broker |
| Native tests fail with in-memory channels | `InMemoryConnector` is JVM-test only | Use JVM tests for in-memory, real-broker tests for native |

**Key configuration properties:**

```properties
# Channel wiring
mp.messaging.incoming.orders.connector=smallrye-kafka
mp.messaging.outgoing.shipments.connector=smallrye-kafka

# Kafka example
mp.messaging.connector.smallrye-kafka.bootstrap.servers=localhost:9092
mp.messaging.incoming.orders.topic=orders
mp.messaging.incoming.orders.value.deserializer=org.apache.kafka.common.serialization.StringDeserializer
mp.messaging.incoming.orders.auto.offset.reset=earliest
mp.messaging.outgoing.shipments.topic=shipments
mp.messaging.outgoing.shipments.value.serializer=org.apache.kafka.common.serialization.StringSerializer
```

| Property | Default | Use when |
|----------|---------|----------|
| `mp.messaging.incoming.<channel>.connector` | auto-selected | Bind channel to a specific connector |
| `mp.messaging.incoming.<channel>.concurrency` | `1` | Increase parallel consumption |
| `mp.messaging.incoming.<channel>.pausable` | `false` | Allow runtime pause/resume via `ChannelRegistry` |
| `mp.messaging.incoming.<channel>.enabled` | `true` | Disable a channel for a profile or build slice |
| `quarkus.messaging.health.enabled` | `true` | Disable all messaging health checks |
| `smallrye.messaging.observation.enabled` | `false` | Enable per-channel Micrometer metrics |

Profile-based channel disablement:

```properties
%test.mp.messaging.incoming.orders.enabled=false
```
