# Quarkus Messaging Usage Patterns

Use these patterns for repeatable broker-backed messaging workflows.

## Pattern: Bridge HTTP to a Broker with an Emitter

When to use:

- A REST endpoint accepts a request and publishes an event asynchronously.

Example:

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

Keep the endpoint thin and move broker routing details into configuration.

## Pattern: Transform One Channel into Another

When to use:

- The service enriches, validates, or reshapes events between brokers or topics.

Example:

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

## Pattern: Use Internal Channels Only When You Need Channel Semantics In One Service

When to use:

- The event stays in one application, but you specifically want channel composition, stream wiring, or back-pressure.

Example:

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

This is the exception case for in-process-only messaging. If you do not need channel semantics, plain CDI events are usually simpler, and if you need request/reply or event-loop behavior, use `vertx-event-bus`.

## Pattern: Move Blocking Work Off the Event Loop

When to use:

- A consumer writes to a database, calls a blocking SDK, or performs filesystem work.

Example:

```java
@ApplicationScoped
class InvoiceConsumer {
    @Incoming("invoices")
    @Blocking
    void persist(Invoice invoice) {
        repository.save(invoice);
    }
}
```

Use `@RunOnVirtualThread` for Java 21+ code when the handler has a blocking signature and you want lightweight concurrency.

## Pattern: Test Without a Broker Using `InMemoryConnector`

When to use:

- You want fast JVM tests for channel logic without Docker or Dev Services.

Example:

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

## Pattern: Persist an Outbox Record in the Same Transaction as the Business Write

When to use:

- A side effect must cross a service boundary reliably, and the integration event must commit atomically with the business change.

Example:

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

Publish the outbox to a broker from a separate background component. This keeps the business write and the integration event durable together in one transaction.

## Pattern: Configure Kafka Consumer Groups and Offset Handling

When to use:

- You need multiple service instances to share partition load or control replay behavior.

Example:

```properties
mp.messaging.incoming.orders.connector=smallrye-kafka
mp.messaging.incoming.orders.topic=orders
mp.messaging.incoming.orders.group.id=order-processor
mp.messaging.incoming.orders.auto.offset.reset=earliest
mp.messaging.incoming.orders.enable.auto.commit=true
```

Each consumer group gets its own offset tracking. Use `earliest` for replay from the beginning on first connect; use `latest` to start from the newest record.

## Pattern: Route Failed Messages to a Dead Letter Topic

When to use:

- Messages that cannot be processed should not block the channel or be silently dropped.

Example:

```properties
mp.messaging.incoming.orders.connector=smallrye-kafka
mp.messaging.incoming.orders.failure-strategy=dead-letter-queue
mp.messaging.incoming.orders.dead-letter-queue.topic=orders-dlq
mp.messaging.incoming.orders.dead-letter-queue.key.serializer=org.apache.kafka.common.serialization.StringSerializer
mp.messaging.incoming.orders.dead-letter-queue.value.serializer=org.apache.kafka.common.serialization.StringSerializer
```

The `dead-letter-queue` failure strategy forwards the failed message (with original headers and reason) to the configured DLQ topic.

## Pattern: Produce Keyed Kafka Messages for Partition Affinity

When to use:

- Messages with the same business key (order ID, customer ID) must land on the same partition for ordering guarantees.

Example:

```java
import io.smallrye.reactive.messaging.kafka.Record;

@Channel("shipments")
Emitter<Record<String, Shipment>> emitter;

void ship(String orderId, Shipment shipment) {
    emitter.send(Record.of(orderId, shipment));
}
```

```properties
mp.messaging.outgoing.shipments.connector=smallrye-kafka
mp.messaging.outgoing.shipments.topic=shipments
mp.messaging.outgoing.shipments.key.serializer=org.apache.kafka.common.serialization.StringSerializer
mp.messaging.outgoing.shipments.value.serializer=io.quarkus.kafka.client.serialization.ObjectMapperSerializer
```

Use `Record<K, V>` to set the key explicitly. Kafka hashes the key to determine partition assignment.
