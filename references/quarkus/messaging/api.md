# Messaging Reference

Use this module when an event crosses a service or process boundary, or when you need broker-backed asynchronous messaging with durability, buffering, replay, or consumer scaling.

## Overview

Quarkus Messaging is built on MicroProfile Reactive Messaging with SmallRye connectors.

- Use it for Kafka, RabbitMQ, AMQP, Pulsar, MQTT, and similar broker-backed channels.
- Model application flow with named channels, `@Incoming`, `@Outgoing`, and `@Channel`.
- Keep business code connector-agnostic where possible; push broker details into configuration.
- Treat it as the default choice when messages must survive restarts or move between services.

## Boundary-First Chooser

```text
Is the event crossing a service/process boundary?
+-- YES -> SmallRye Reactive Messaging + broker connector
+-- NO (in-process only)
      |
      Do you need clustering or non-blocking event loop behavior?
      +-- YES -> Vert.x Event Bus (@ConsumeEvent)
      +-- NO
            |
            Do you want portability and type safety?
            +-- YES -> Jakarta CDI Events (@Observes)
```

Use this module for the first branch. For the other branches, route to the linked modules.

---

## Reactive Messaging API

### Common extensions

Choose the connector that matches the broker:

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-messaging-kafka</artifactId>
</dependency>
```

Other common choices are `quarkus-messaging-rabbitmq`, `quarkus-messaging-amqp`, and `quarkus-messaging-pulsar`.

### Core channel annotations

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

### Imperative publishing with `@Channel`

Send from REST, scheduled jobs, or other imperative entry points:

```java
@Path("/orders")
@ApplicationScoped
class OrderResource {
    @Channel("orders-out")
    Emitter<OrderPlaced> emitter;

    @POST
    CompletionStage<Void> create(OrderPlaced order) {
        return emitter.send(order);
    }
}
```

Use `MutinyEmitter<T>` when you want Mutiny-style APIs such as `sendAndAwait`.

### Inject channel streams

Expose a channel as a reactive stream:

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

When injecting `Multi<T>` with `@Channel`, your code is responsible for subscribing to it.

### Messages and metadata

Use `Message<T>` when you need the envelope rather than only the payload:

```java
@Incoming("orders-in")
@Outgoing("orders-out")
Message<String> process(Message<String> message) {
    return message.withPayload(message.getPayload().toUpperCase());
}
```

Connector metadata can be injected directly as a parameter after the payload:

```java
@Incoming("orders-in")
String process(String payload, MyConnectorMetadata metadata) {
    return payload + ":" + metadata.partition();
}
```

### Fan-out and fan-in

Broadcast to multiple downstream consumers:

```java
@Incoming("raw")
@Outgoing("enriched")
@Broadcast
String enrich(String payload) {
    return payload.toUpperCase();
}
```

Allow multiple producers into one channel:

```java
@Incoming("a")
@Outgoing("merged")
String fromA(String payload) {
    return payload;
}

@Incoming("b")
@Outgoing("merged")
String fromB(String payload) {
    return payload;
}

@Incoming("merged")
@Merge
void consume(String payload) {
}
```

### Stream processing signatures

Operate on the whole stream when per-message methods are too limiting:

```java
@Incoming("source")
@Outgoing("sink")
Multi<String> process(Multi<String> input) {
    return input.map(String::toUpperCase);
}
```

### Execution control

Quarkus chooses event-loop vs worker execution from the method signature, but you can override it:

```java
@Incoming("jobs")
@Blocking
void runBlocking(Job job) {
}

@Incoming("events")
@NonBlocking
Uni<Void> runAsync(Event event) {
    return Uni.createFrom().voidItem();
}

@Incoming("imports")
@RunOnVirtualThread
void importBatch(Batch batch) {
}
```

`@Transactional` implies blocking execution.

### Pausable channels

Control an incoming channel at runtime:

```java
@ApplicationScoped
class ChannelController {
    @Inject
    ChannelRegistry registry;

    void pause() {
        registry.getPausable("orders").pause();
    }

    void resume() {
        registry.getPausable("orders").resume();
    }
}
```

Enable pausability in configuration before using `ChannelRegistry#getPausable`.

---

## Configuration Reference

### High-value properties

| Property | Default | Use when |
|----------|---------|----------|
| `mp.messaging.incoming.<channel>.connector` | auto-selected if only one connector is present | Bind an incoming channel to a specific connector |
| `mp.messaging.outgoing.<channel>.connector` | auto-selected if only one connector is present | Bind an outgoing channel to a specific connector |
| `mp.messaging.incoming.<channel>.<connector-attr>` | connector-specific | Configure broker-specific inbound settings such as `topic`, `address`, deserializers, or consumer group |
| `mp.messaging.outgoing.<channel>.<connector-attr>` | connector-specific | Configure broker-specific outbound settings such as `topic`, serializers, keys, or acknowledgements |
| `mp.messaging.connector.<connector>.<attr>` | connector-specific | Apply connector-wide defaults such as Kafka bootstrap servers |
| `mp.messaging.incoming.<channel>.enabled` | `true` | Disable a channel for a profile or build slice |
| `mp.messaging.incoming.<channel>.concurrency` | `1` | Increase parallel consumption when the connector supports it |
| `mp.messaging.incoming.<channel>.pausable` | `false` | Allow runtime pause/resume through `ChannelRegistry` |
| `mp.messaging.incoming.<channel>.tracing-enabled` | connector-specific | Turn OpenTelemetry propagation off for a noisy or special-case channel |
| `mp.messaging.incoming.<channel>.tls-configuration-name` | - | Attach a named Quarkus TLS configuration to one channel |
| `mp.messaging.connector.<connector>.tls-configuration-name` | - | Attach the same TLS configuration to all channels of a connector |
| `quarkus.messaging.connector-context-propagation` | none | Explicitly propagate selected contexts such as `CDI` through connectors |
| `quarkus.messaging.request-scoped.enabled` | `false` | Activate request scope for each incoming message |
| `quarkus.messaging.health.enabled` | `true` | Disable all messaging health checks |
| `quarkus.messaging.health.<channel>.enabled` | `true` | Disable health checks for one channel |
| `quarkus.messaging.health.<channel>.liveness.enabled` | `true` | Disable only one health-check type for a channel |
| `smallrye.messaging.observation.enabled` | `false` | Enable per-channel Micrometer observation metrics |

### Channel naming and prefixes

Channel properties always use one of these prefixes:

```properties
mp.messaging.incoming.orders.connector=smallrye-kafka
mp.messaging.outgoing.shipments.connector=smallrye-kafka
```

The channel name in config must match the annotation value exactly.

### Example: Kafka channel configuration

```properties
mp.messaging.connector.smallrye-kafka.bootstrap.servers=localhost:9092

mp.messaging.incoming.orders.connector=smallrye-kafka
mp.messaging.incoming.orders.topic=orders
mp.messaging.incoming.orders.value.deserializer=org.apache.kafka.common.serialization.StringDeserializer
mp.messaging.incoming.orders.auto.offset.reset=earliest

mp.messaging.outgoing.shipments.connector=smallrye-kafka
mp.messaging.outgoing.shipments.topic=shipments
mp.messaging.outgoing.shipments.value.serializer=org.apache.kafka.common.serialization.StringSerializer
```

The actual destination property varies by connector. Kafka commonly uses `topic`; other connectors may use properties such as `address` or `queue`.

### Profile-based channel disablement

Disable a channel only when the bean graph still makes sense without it:

```properties
%test.mp.messaging.incoming.orders.enabled=false
```

Pair disabled channels with build-time bean filtering when necessary:

```java
@ApplicationScoped
@IfBuildProfile("prod")
class OrderIngestion {
    @Incoming("orders")
    void consume(String payload) {
    }
}
```

### Concurrency

Increase inbound concurrency only when the connector and workload support it:

```properties
mp.messaging.incoming.orders.concurrency=4
```

This creates multiple logical copies of the incoming channel and can improve throughput, especially on partitioned brokers such as Kafka.

### TLS integration

Use the Quarkus TLS registry instead of connector-specific truststore flags when the connector supports it:

```properties
quarkus.tls.messaging.trust-store=truststore.jks
quarkus.tls.messaging.trust-store-password=secret

mp.messaging.incoming.orders.tls-configuration-name=messaging
```

### Context and health controls

```properties
quarkus.messaging.connector-context-propagation=CDI
quarkus.messaging.request-scoped.enabled=true
quarkus.messaging.health.enabled=true
smallrye.messaging.observation.enabled=true
```

Leave connector context propagation off unless you have a clear need; broad propagation can hide lifecycle mistakes.

## See Also

- `../vertx-event-bus/` - Local async request/reply and pub/sub with Vert.x addresses
- `../dependency-injection/` - CDI events for same-process observer patterns
- `../configuration/` - Profiles and property layering for connector setup
