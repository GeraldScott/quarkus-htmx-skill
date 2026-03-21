# Quarkus Testing Gotchas

Common testing pitfalls, symptoms, and fixes.

## Test lifecycle and context

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `@Inject` field is null in test | Test class is missing `@QuarkusTest` | Add `@QuarkusTest` to the class |
| CDI injection fails in `@QuarkusIntegrationTest` | Integration tests do not support CDI injection | Use `@QuarkusTest` for tests that need injection, or test via HTTP only |
| Tests pass individually but fail together | Shared mutable state or conflicting test profiles restart the app | Isolate state per test or use `@TestProfile` consistently |
| Application restarts between test classes | Different `@TestProfile` annotations cause separate app boots | Group tests by profile when startup cost matters |

## Mocking pitfalls

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `@InjectMock` does not replace the bean | Bean is a `@ConfigMapping` or not a normal CDI proxy | Use a producer-based mock or a test profile with alternatives |
| Mock setup in `@BeforeEach` is ignored | Mock interactions happen before `@BeforeEach` runs | Use `@BeforeAll` for static setup or verify mock reset behavior |
| `@InjectSpy` changes bean behavior unexpectedly | Spy wraps a proxy, not the actual bean instance | Verify the spy delegates correctly; prefer `@InjectMock` with explicit stubs |

## Dev Services in tests

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Tests fail with connection refused | Docker is not running or Dev Services is disabled | Start Docker and verify `quarkus.datasource.devservices.enabled` is not `false` |
| Tests are slow due to container startup | Each test profile restart provisions new containers | Minimize the number of distinct test profiles |
| Test database has leftover data from previous tests | Tables are not cleaned between tests | Use `@Transactional` rollback, truncate in `@BeforeEach`, or `drop-and-create` schema strategy for tests |

## Test profile issues

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Config override from `getConfigOverrides()` is ignored | A higher-priority config source (env var, system property) overrides it | Remove the conflicting source or use a different key |
| Test profile tags filter out all tests | `quarkus.test.profile.tags` does not match any profile's `tags()` | Verify tag spelling matches between the system property and profile class |

## REST Assured pitfalls

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| REST Assured targets wrong port | Quarkus test port differs from the default 8080 | Use `@TestHTTPEndpoint` or let Quarkus configure REST Assured automatically via `quarkus-junit5` |
| JSON body assertion fails unexpectedly | Response shape changed or Jackson serialization differs from expectation | Log the response body with `.log().body()` before asserting |
