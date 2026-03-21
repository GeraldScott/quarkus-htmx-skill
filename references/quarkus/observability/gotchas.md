# Quarkus Observability Gotchas

Common observability pitfalls, symptoms, and fixes.

## Health checks

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Pod killed during startup | Liveness probe fires before app is ready | Use `@Startup` check (not `@Liveness`) for slow initialization; increase `initialDelaySeconds` on liveness probe |
| Readiness check always DOWN | External dependency unreachable from the pod | Verify network policies, DNS, and service URLs from inside the container |
| Health endpoint returns 404 | `quarkus-smallrye-health` extension not added | Add the dependency; endpoint is `/q/health` by default |
| Custom check not appearing | Class missing `@Liveness`, `@Readiness`, or `@Startup` annotation | Add the appropriate annotation; class must also implement `HealthCheck` |

## Metrics

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Custom counter always 0 | Counter created but `increment()` never called, or wrong tag combination | Verify the metric name and tags match between registration and query |
| `/q/metrics` returns 404 | `quarkus-micrometer-registry-prometheus` not added | Add the Prometheus registry dependency; `quarkus-micrometer` alone is not enough |
| `@Counted`/`@Timed` annotations ignored | Micrometer annotation support requires CDI interception | Ensure the annotated class is a CDI bean (not `new`'d manually) |
| Metric cardinality explosion | Dynamic tag values (user IDs, request paths with path params) | Use bounded tag values; avoid user-specific or unbounded cardinality tags |
| Timer records 0ms | Method returns before the timed block completes (async) | Use `Timer.record(Supplier)` wrapping the full operation, or instrument the reactive pipeline |

## Tracing

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| No traces in collector (Jaeger/Tempo) | OTLP endpoint misconfigured or unreachable | Verify `quarkus.otel.exporter.otlp.traces.endpoint` and network connectivity |
| Traces missing in dev mode | Dev Services for tracing not enabled or Docker not running | Start Docker; or set endpoint explicitly to a local Jaeger instance |
| `@WithSpan` annotation ignored | Class not a CDI bean | Ensure the class is managed by CDI (`@ApplicationScoped`, etc.) |
| Child spans not linked to parent | Span context not propagated across async boundaries | Use `Context.current()` to capture and restore context in async callbacks |
| Trace sampling drops everything | Sampler ratio set to 0 | Check `quarkus.otel.traces.sampler.arg` -- `1.0` traces everything, `0.0` traces nothing |

## Logging

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| MDC values are null | MDC not set in the current thread, or cleared prematurely | Set MDC in a `ContainerRequestFilter`; clear in `ContainerResponseFilter` |
| MDC values leak between requests | MDC not cleared after request | Always clear MDC in a response filter or `@PreDestroy` callback |
| JSON logging not working | `quarkus-logging-json` dependency missing | Add the dependency; then set `quarkus.log.console.json=true` |
| Log output missing in tests | Test log level too high | Set `%test.quarkus.log.category."com.example".level=DEBUG` |
| SQL logging too verbose | Hibernate trace logging enabled | Set `org.hibernate.SQL` to `DEBUG` (not `TRACE`) and disable `BasicBinder` in production |

## Dev Services and testing

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Observability extensions slow down tests | Health, metrics, and tracing start even when not needed | Disable with `%test.quarkus.micrometer.enabled=false`, `%test.quarkus.otel.enabled=false` |
| Health checks fail in `@QuarkusTest` | External dependency not available in test environment | Mock the dependency with `@InjectMock` or use a test profile that disables the check |
| Metrics test sees stale values | Counters accumulate across test methods in the same app restart | Use `@TestProfile` to isolate metric tests, or assert on relative increments rather than absolute values |
