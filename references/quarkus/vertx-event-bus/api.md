# Quarkus Vert.x Event Bus Reference

## Overview

Quarkus exposes the Vert.x event bus through declarative consumers and the injected `EventBus` API.

- Use it for local asynchronous request/reply, fire-and-forget, or local pub/sub by address.
- Prefer it when event-loop integration and lightweight local messaging matter more than portability.
- It supports clustering, but it is still not a durable broker and does not provide stream processing semantics.

### When to choose this over other options

- Choose `vertx-event-bus` over `dependency-injection` when you need request/reply, event-loop friendly handlers, or Vert.x cluster transport.
- Choose `messaging` instead when events cross service boundaries and need durability, replay, or broker-managed scaling.

## Extension

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-vertx</artifactId>
</dependency>
```

## Declarative consumers with `@ConsumeEvent`

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

## Inject and use the `EventBus`

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

Core sending styles:

```java
bus.send("jobs", job);
bus.publish("notifications", notice);
Uni<String> response = bus.<String>request("greeting", "quarkus")
        .onItem().transform(Message::body);
```

- `send` -> one consumer receives the message
- `publish` -> all consumers on the address receive the message
- `request` -> expect a reply

## Consume the full message

Use Vert.x `Message<T>` when you need headers, address, or manual reply access:

```java
@ConsumeEvent("jobs")
void consume(Message<Job> message) {
    Job job = message.body();
}
```

## Async and blocking consumers

Async handlers can return `Uni<T>` or `CompletionStage<T>`:

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

Equivalent annotation attribute:

```java
@ConsumeEvent(value = "reports", blocking = true)
void generateReport(String id) {
}
```

## Virtual-thread consumers

```java
@ConsumeEvent("imports")
@RunOnVirtualThread
void importBatch(String payload) {
}
```

Use this only with blocking signatures such as `void` or a plain return type. `Uni` and `CompletionStage` return types do not run on virtual threads.

## Config-driven addresses

```java
@ConsumeEvent("${app.events.greeting-address:greeting}")
String greet(String name) {
    return name.toUpperCase();
}
```

If the property is missing and no default value is provided, startup fails.

## Codecs

Quarkus provides a default codec for local delivery. For explicit codecs:

```java
bus.request("greeting", new MyName("quarkus"),
        new DeliveryOptions().setCodecName(MyNameCodec.class.getName()));

@ConsumeEvent(value = "greeting", codec = MyNameCodec.class)
String greet(MyName name) {
    return "Hello " + name.value();
}
```

## Configuration

### High-value properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.vertx.cluster.clustered` | `false` | Enable Vert.x clustering so the event bus can communicate across nodes |
| `quarkus.vertx.cluster.host` | `localhost` | Bind the cluster manager to a specific host |
| `quarkus.vertx.cluster.port` | implementation-specific | Pin the cluster port instead of using defaults |
| `quarkus.vertx.cluster.public-host` | - | Advertise a reachable public host when bind and advertised addresses differ |
| `quarkus.vertx.cluster.public-port` | - | Advertise a reachable public port |
| `quarkus.vertx.cluster.ping-interval` | `20S` | Tune cluster heartbeat traffic |
| `quarkus.vertx.cluster.ping-reply-interval` | `20S` | Tune heartbeat response timing |
| `quarkus.vertx.eventbus.connect-timeout` | `60S` | Adjust how long remote event-bus connections may take |
| `quarkus.vertx.eventbus.reconnect-attempts` | `0` | Retry remote event-bus reconnection instead of failing immediately |
| `quarkus.vertx.eventbus.reconnect-interval` | `1S` | Control retry interval for reconnect attempts |
| `quarkus.vertx.eventbus.ssl` | `false` | Enable SSL for clustered event-bus transport |
| `quarkus.vertx.eventbus.client-auth` | `NONE` | Require client certificates for clustered transport |
| `quarkus.vertx.eventbus.trust-all` | `false` | Trust all peer certificates in non-production scenarios |
| `quarkus.vertx.event-loops-pool-size` | CPU-count based | Tune event-loop parallelism |
| `quarkus.vertx.max-event-loop-execute-time` | `2S` | Detect handlers that block the event loop too long |
| `quarkus.vertx.warning-exception-time` | `2S` | Control when blocked-event-loop warnings appear |

### Cluster enablement

Minimal clustered setup:

```properties
quarkus.vertx.cluster.clustered=true
quarkus.vertx.cluster.host=0.0.0.0
quarkus.vertx.cluster.public-host=app-1.internal
quarkus.vertx.cluster.port=15701
```

Clustering helps local address-based communication span nodes, but it still does not turn the event bus into a durable broker.

### Reconnect behavior

```properties
quarkus.vertx.eventbus.reconnect-attempts=10
quarkus.vertx.eventbus.reconnect-interval=2S
quarkus.vertx.eventbus.connect-timeout=10S
```

Use reconnect settings only for clustered transport issues. They do not add message durability.

### SSL families

Choose one certificate format family for key and trust material:

- PEM: `quarkus.vertx.eventbus.key-certificate-pem.*`, `quarkus.vertx.eventbus.trust-certificate-pem.*`
- JKS: `quarkus.vertx.eventbus.key-certificate-jks.*`, `quarkus.vertx.eventbus.trust-certificate-jks.*`
- PFX: `quarkus.vertx.eventbus.key-certificate-pfx.*`, `quarkus.vertx.eventbus.trust-certificate-pfx.*`

Example with JKS:

```properties
quarkus.vertx.eventbus.ssl=true
quarkus.vertx.eventbus.client-auth=REQUIRED
quarkus.vertx.eventbus.key-certificate-jks.path=eventbus-keystore.jks
quarkus.vertx.eventbus.key-certificate-jks.password=secret
quarkus.vertx.eventbus.trust-certificate-jks.path=eventbus-truststore.jks
quarkus.vertx.eventbus.trust-certificate-jks.password=secret
```

### Event-loop safety signals

```properties
quarkus.vertx.max-event-loop-execute-time=500ms
quarkus.vertx.warning-exception-time=500ms
```

Use these warnings to catch handlers that should move to `@Blocking` or other worker execution.
