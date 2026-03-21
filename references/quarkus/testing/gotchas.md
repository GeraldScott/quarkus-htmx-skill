# Quarkus Testing Gotchas

Common testing pitfalls, symptoms, and fixes across all tiers of the testing pyramid.

## Unit testing pitfalls

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Mockito `@InjectMocks` field is null | Missing `@ExtendWith(MockitoExtension.class)` on the test class | Add the extension or use `MockitoAnnotations.openMocks(this)` in `@BeforeEach` |
| Constructor injection fails in test | Class has no no-arg constructor and `@InjectMocks` can't find matching mocks | Ensure all constructor params have corresponding `@Mock` fields |
| Panache static methods throw errors in unit test | Panache requires the Quarkus runtime | Use `@QuarkusTest` for Panache entities, or extract logic into a service class that can be unit-tested |
| `@QuarkusComponentTest` can't find bean | Bean class not on the component test's classpath scan | Add the component class explicitly via `@QuarkusComponentTest(value = MyBean.class)` |
| `@ConfigProperty` is null in `@QuarkusComponentTest` | Config not set | Use `@TestConfigProperty(key = "...", value = "...")` on the test class |

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

## E2E / Playwright pitfalls

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Playwright test fails with "element not found" | HTMX swap hasn't completed yet | Use `page.waitForSelector()` or `page.waitForResponse()` instead of fixed timeouts |
| `hx-confirm` dialog blocks the test | Playwright doesn't auto-accept dialogs | Register `page.onDialog(dialog -> dialog.accept())` before the action that triggers the dialog |
| Test passes locally but fails in CI | CI has no display server for the browser | Playwright runs headless by default; ensure Docker/CI has required system libraries |
| OOB swap target not updated in assertions | Assertion runs before the secondary swap completes | Wait for the specific OOB target selector after the primary swap |
| `@TestHTTPResource` URL is null | Missing `@QuarkusTest` annotation | `@TestHTTPResource` requires the Quarkus test framework to be active |

## UAT / Cucumber pitfalls

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Step definitions not found | Glue package path doesn't match step definition package | Verify the `glue` path in `@CucumberOptions` matches the step class package |
| Scenario isolation failure (data leaks) | Database state shared between scenarios | Use `@TestTransaction` or truncate tables in a `@Before` hook |
| Feature file not found | Wrong path in `@CucumberOptions` | Use relative path from project root: `features = "src/test/resources/features"` |

## Testing pyramid anti-patterns

| Anti-pattern | Problem | Fix |
|--------------|---------|-----|
| Ice cream cone (mostly E2E, few unit tests) | Slow feedback, fragile tests, hard to debug failures | Push logic into testable services; cover with unit tests; use E2E only for critical paths |
| Mocking everything in integration tests | Tests don't verify real behavior; refactors break tests | Use Dev Services for real backends; reserve mocks for external APIs |
| No tests at all ("it works in dev mode") | Regressions caught late, no safety net for refactoring | Start with `@QuarkusTest` for endpoints, add unit tests for business logic |
| Testing implementation details | Tests break on every refactor even when behavior is unchanged | Assert on observable behavior (HTTP responses, DOM content), not internal method calls |
