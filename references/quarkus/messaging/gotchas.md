# Quarkus Messaging Gotchas

Common Reactive Messaging pitfalls, symptoms, and fixes.

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `@Incoming` method never runs in tests or business code | Method was called directly instead of letting the runtime wire channels | Trigger the channel through a broker, emitter, or in-memory channel instead |
| Deployment fails because a channel has multiple consumers | One producer channel feeds more than one consumer without `@Broadcast` | Add `@Broadcast` on the outgoing side or split the flow explicitly |
| Deployment fails because a channel has multiple producers | Several methods publish to one channel without `@Merge` | Add `@Merge` on the incoming side or redesign the topology |
| Consumer blocks or stalls under load | Blocking I/O runs on an event-loop-dispatched handler | Add `@Blocking` or `@RunOnVirtualThread`, or move the blocking call out of the handler |
| Request or security context seems to disappear across channels | Connector context propagation is disabled by default | Pass required data in the message, or enable only the contexts you truly need |
| Need dynamic topics or channels at runtime | Reactive Messaging channels are fixed at startup | Use low-level broker clients when the topology itself must be created dynamically |
| Metrics expected but no per-channel counters appear | Observation metrics are disabled by default | Set `smallrye.messaging.observation.enabled=true` and include Micrometer |
| Health checks make readiness fail during local work | Channel health is enabled and the broker is unavailable | Disable specific channel checks for that environment or use Dev Services |
| In-memory tests pass but production broker behavior differs | `InMemoryConnector` skips connector metadata and real serialization | Add integration tests against a real broker for metadata, headers, and serialization |
| Native tests fail with in-memory channels | `InMemoryConnector` is JVM-test only | Use JVM tests for in-memory channels and real-broker tests for native coverage |

## Message security

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Sensitive data visible in broker logs or DLQ | Messages contain PII or secrets in plaintext | Encrypt sensitive message payloads before publishing; decrypt on consumption |
| Untrusted message causes deserialization exploit | No schema validation on incoming messages | Validate message schema/content before deserializing into domain objects |
| Messages processed from unauthorized producers | Broker has no authentication configured | Enable broker authentication (Kafka SASL/SSL, RabbitMQ credentials) and restrict topic/queue ACLs |

## Kafka-specific pitfalls

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Consumer reprocesses all messages on restart | `auto.offset.reset` is `earliest` and offsets are lost | Set a stable `group.id` and verify offset commit behavior |
| Messages arrive out of order across instances | Messages with different keys land on different partitions | Use `Record<K, V>` with a consistent key to ensure partition affinity |
| Dead letter queue is not receiving failed messages | `failure-strategy` is not set to `dead-letter-queue` | Configure `mp.messaging.incoming.<channel>.failure-strategy=dead-letter-queue` |
| Serialization fails for complex objects | Default serializer does not handle the payload type | Set explicit `value.serializer` and `value.deserializer` for the channel |
| Kafka Dev Services container does not start | Docker unavailable or `quarkus.kafka.devservices.enabled=false` | Start Docker and verify Dev Services is not disabled |
