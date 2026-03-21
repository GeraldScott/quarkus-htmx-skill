# Quarkus Web REST Gotchas

Common REST pitfalls, symptoms, and fixes.

## Routing and parameter binding

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Endpoint path is not where expected | `@ApplicationPath`, `quarkus.rest.path`, and `quarkus.http.root-path` are combined unexpectedly | Standardize on one base-path strategy and verify final path composition |
| Path/query parameter binding fails after refactor | Parameter names changed and compiler metadata is missing | Compile with `-parameters` or use explicit annotation values |

## JSON behavior

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Unknown JSON fields are silently accepted | Jackson defaults to ignore unknown properties in Quarkus | Set `quarkus.jackson.fail-on-unknown-properties=true` |
| JSON body is empty in native executable | Serialized type cannot be inferred from raw `Response` return types | Prefer concrete return types or annotate model with `@RegisterForReflection` |
| Extension-provided JSON behavior disappears | Custom `ObjectMapper` or `Jsonb` producer ignored Quarkus customizers | Inject and apply all customizer beans in custom producers |

## Multipart uploads

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Multipart requests fail with HTTP 413 | Part exceeds `quarkus.http.limits.max-form-attribute-size` | Increase the size limit |
| Uploaded file is unavailable after request completion | File remained in temp storage and was cleaned up | Move uploads to durable storage during request handling |

## Threading and filters

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Event-loop blocked warnings or degraded throughput | Blocking code runs on IO thread | Use reactive APIs or `@Blocking` |
| Filter behavior differs between endpoints | Filters follow endpoint threading model | Use `@ServerRequestFilter(nonBlocking = true)` when event-loop pre-processing is required |

## Exception mapping

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Custom mapper for `JsonMappingException` is not invoked | Built-in mapper for subtype (`MismatchedInputException`) takes precedence | Disable selected built-in mapper with `quarkus.rest.exception-mapping.disable-mapper-for` |
| Exception context is missing in logs | Quarkus REST suppresses some exception logs by default | Raise relevant REST log categories to `DEBUG` |

## Bean Validation

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `@Valid` annotation has no effect | `quarkus-hibernate-validator` extension is missing | Add the extension to your project |
| Validation error response format is unexpected | Default violation mapper produces its own structure | Add a custom `@ServerExceptionMapper` for `ConstraintViolationException` |

## REST Client

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `RestClient` injection is null or fails | `@RegisterRestClient` missing or base URL not configured | Add the annotation and set `quarkus.rest-client.<configKey>.url` |
| REST Client ignores custom Jackson configuration | Client and server may use separate `ObjectMapper` instances | Apply customizers to both or use shared `@Provider` registration |
| SSL errors when calling external service | Trust store not configured for the client | Set `quarkus.rest-client.<configKey>.trust-store` or use the TLS registry |

## SSE streaming

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| SSE endpoint returns entire payload at once | Missing `@Produces(MediaType.SERVER_SENT_EVENTS)` or `@RestStreamElementType` | Add both annotations to the streaming endpoint |
| Client disconnects but server keeps producing | `Multi` source does not detect cancellation | Use `Multi` operators that respect cancellation signals |
