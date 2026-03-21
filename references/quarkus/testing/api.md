# Quarkus Testing Reference

## Overview

Quarkus provides a layered test framework supporting the full testing pyramid:
unit tests, component tests, integration tests, end-to-end tests, and user
acceptance tests. Choose the right tier based on what you need to verify.

### Testing Pyramid (fastest to slowest)

```
            /  UAT  \          Fewest -- business-critical user journeys
           /  E2E    \         Browser-based (Playwright) or black-box artifact
          / Integration\       @QuarkusTest + REST Assured + Dev Services
         /  Component   \      @QuarkusComponentTest (CDI only, no HTTP)
        /   Unit Tests   \     Plain JUnit 5 + Mockito (no container)
```

| Tier | Annotation | Container | Speed | See |
|------|-----------|-----------|-------|-----|
| Unit | None (plain JUnit) | None | ~ms | `unit-testing.md` |
| Component | `@QuarkusComponentTest` | CDI only | ~1s | `unit-testing.md` |
| Integration | `@QuarkusTest` | Full app | ~5-15s first, ~ms hot | `patterns.md` |
| E2E | `@QuarkusTest` + `@WithPlaywright` | Full app + browser | ~seconds | `e2e-testing.md` |
| E2E (artifact) | `@QuarkusIntegrationTest` | Packaged JAR/native | ~seconds | `e2e-testing.md` |
| UAT / BDD | Cucumber + Playwright | Full app + browser | ~seconds | `uat-testing.md` |

### TDD Approach

Follow **red-green-refactor** at every tier:

1. **RED** -- Write a failing test that defines the expected behavior.
2. **GREEN** -- Write the minimum production code to make the test pass.
3. **REFACTOR** -- Clean up duplication in both test and production code.

Use `./mvnw quarkus:dev` (continuous testing) or `./mvnw quarkus:test` for the
fastest TDD feedback loop. Tests re-run automatically on save.

### General guidelines

- **Unit tests first**: Start with plain JUnit + Mockito for business logic. No container overhead.
- **Component tests** for CDI-dependent logic: Use `@QuarkusComponentTest` when you need interceptors or config injection but not the full application.
- **Integration tests** for wiring and HTTP: Use `@QuarkusTest` + REST Assured for endpoint behavior with real Dev Services backends.
- **E2E tests** for critical user flows: Use Playwright for browser-based HTMX interaction testing.
- **UAT** for stakeholder-visible scenarios: Express acceptance criteria as Gherkin features or descriptive JUnit test names.
- Use `@InjectMock` sparingly; prefer real implementations backed by Dev Services.
- Use test profiles when different tests need conflicting configuration.
- Keep test classes in `src/test/java` with the same package structure as production code.

## Extension entry points

```xml
<!-- Integration testing (full app) -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit5</artifactId>
    <scope>test</scope>
</dependency>

<!-- HTTP assertions -->
<dependency>
    <groupId>io.rest-assured</groupId>
    <artifactId>rest-assured</artifactId>
    <scope>test</scope>
</dependency>

<!-- Mocking (works with @QuarkusTest and @QuarkusComponentTest) -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit5-mockito</artifactId>
    <scope>test</scope>
</dependency>

<!-- Component testing (lightweight CDI, no full app) -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit5-component</artifactId>
    <scope>test</scope>
</dependency>

<!-- Browser E2E testing -->
<dependency>
    <groupId>io.quarkiverse.playwright</groupId>
    <artifactId>quarkus-playwright</artifactId>
    <scope>test</scope>
</dependency>

<!-- BDD / Cucumber (UAT) -->
<dependency>
    <groupId>io.quarkiverse.cucumber</groupId>
    <artifactId>quarkus-cucumber</artifactId>
    <scope>test</scope>
</dependency>
```

## `@QuarkusTest`

Starts the full Quarkus application for JVM-mode testing with CDI injection and HTTP access:

```java
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.RestAssured;
import org.junit.jupiter.api.Test;

import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
class GreetingResourceTest {
    @Test
    void testHelloEndpoint() {
        RestAssured.given()
            .when().get("/hello")
            .then()
            .statusCode(200)
            .body(is("hello"));
    }
}
```

## `@QuarkusComponentTest`

Lightweight CDI-only testing without starting the full application. Faster than
`@QuarkusTest`, suitable for testing service-layer beans with their CDI wiring:

```java
import io.quarkus.test.component.QuarkusComponentTest;
import io.quarkus.test.component.TestConfigProperty;
import io.quarkus.test.InjectMock;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import static org.junit.jupiter.api.Assertions.assertEquals;

@QuarkusComponentTest
@TestConfigProperty(key = "greeting.prefix", value = "Hello")
class GreetingServiceTest {

    @Inject
    GreetingService service;

    @InjectMock
    UserRepository userRepo;

    @Test
    void greet_returnsPersonalizedGreeting() {
        Mockito.when(userRepo.findByName("Ada")).thenReturn(new User("Ada"));
        assertEquals("Hello, Ada!", service.greet("Ada"));
    }
}
```

Supports `@Nested` test classes, method parameter injection, and `@TestConfigProperty`.
See `unit-testing.md` for detailed patterns and guidance on when to use this vs plain JUnit.

## `@QuarkusIntegrationTest`

Black-box test against the packaged artifact (JAR or native). No CDI injection available:

```java
import io.quarkus.test.junit.QuarkusIntegrationTest;
import io.restassured.RestAssured;
import org.junit.jupiter.api.Test;

@QuarkusIntegrationTest
class GreetingResourceIT {
    @Test
    void testHelloEndpoint() {
        RestAssured.given()
            .when().get("/hello")
            .then()
            .statusCode(200);
    }
}
```

Run with `./mvnw verify` or `./mvnw verify -Dnative` for native integration tests.

## CDI injection in tests

```java
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertNotNull;

@QuarkusTest
class ServiceTest {
    @Inject
    GreetingService service;

    @Test
    void testService() {
        assertNotNull(service.hello());
    }
}
```

## `@InjectMock`

Replace a CDI bean with a Mockito mock for the duration of the test:

```java
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

@QuarkusTest
class OrderResourceTest {
    @InjectMock
    OrderService orderService;

    @Test
    void testMockedService() {
        Mockito.when(orderService.count()).thenReturn(42L);
        // test against the mock
    }
}
```

`@InjectMock` replaces the bean for all injection points in the test and the application.

## `@InjectSpy`

Wrap a real CDI bean with a Mockito spy to verify interactions while preserving real behavior:

```java
import io.quarkus.test.junit.mockito.InjectSpy;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

@QuarkusTest
class AuditTest {
    @InjectSpy
    AuditService auditService;

    @Test
    void testAuditCalled() {
        // call the real endpoint
        Mockito.verify(auditService).log(Mockito.anyString());
    }
}
```

## `@TestProfile`

Apply a custom test profile to a test class:

```java
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.TestProfile;

@QuarkusTest
@TestProfile(CustomTestProfile.class)
class ProfiledTest {
    @Test
    void testWithCustomProfile() {
    }
}
```

See `patterns.md` for how to implement `QuarkusTestProfile`.

## `@TestHTTPEndpoint` and `@TestHTTPResource`

Target a specific resource class or inject a URL:

```java
import io.quarkus.test.common.http.TestHTTPEndpoint;
import io.quarkus.test.common.http.TestHTTPResource;
import io.quarkus.test.junit.QuarkusTest;
import java.net.URL;

@QuarkusTest
@TestHTTPEndpoint(GreetingResource.class)
class EndpointTest {
    @TestHTTPResource
    URL url;

    @Test
    void test() {
        // url points to the GreetingResource base path
    }
}
```

## `@QuarkusTestResource`

Register a custom lifecycle manager for external resources:

```java
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.common.QuarkusTestResourceLifecycleManager;

import java.util.Map;

public class WireMockResource implements QuarkusTestResourceLifecycleManager {
    @Override
    public Map<String, String> start() {
        // start WireMock, return config overrides
        return Map.of("api.url", "http://localhost:8089");
    }

    @Override
    public void stop() {
        // stop WireMock
    }
}

@QuarkusTest
@QuarkusTestResource(WireMockResource.class)
class ExternalApiTest {
}
```

Use `restrictToAnnotatedClass = true` to limit resource scope to the annotated test class only.

## Configuration

### High-value properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.test.continuous-testing` | `paused` | Continuous testing should start enabled or disabled by default |
| `quarkus.test.include-pattern` | - | Only specific test classes should run in continuous testing |
| `quarkus.test.exclude-pattern` | - | Specific test classes should be skipped |
| `quarkus.test.type` | `unit` | Integration tests should also run in continuous testing |
| `quarkus.test.profile` | `test` | Tests should use a different config profile |
| `quarkus.test.profile.tags` | - | Only tests with matching profile tags should run |
| `quarkus.test.hang-detection-timeout` | `10M` | Test hang detection timeout should be adjusted |
| `quarkus.test.native-image-wait-time` | `PT5M` | Native image build wait time should be extended |
| `quarkus.test.integration-test-profile` | `prod` | Integration tests should use a non-default profile |
| `quarkus.http.test-port` | `8081` | The test HTTP port should be changed |
| `quarkus.http.test-ssl-port` | `8444` | The test HTTPS port should be changed |

### Test profile activation

```properties
quarkus.test.profile=staging
```

This sets the Quarkus config profile during test execution, which loads `application-staging.properties` values.

### Dev Services in tests

Dev Services are enabled by default in test mode. When `@QuarkusTest` starts, it automatically provisions containers for configured extensions.

Disable Dev Services for tests when using an external database:

```properties
%test.quarkus.datasource.devservices.enabled=false
%test.quarkus.datasource.jdbc.url=jdbc:postgresql://localhost:5432/testdb
```

### ArC test settings

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.arc.test.disable-application-lifecycle-observers` | `false` | Startup and shutdown observers should not run during tests |

### Logging in tests

```properties
%test.quarkus.log.category."org.acme".level=DEBUG
%test.quarkus.log.console.format=%d{HH:mm:ss} %-5p [%c] %s%e%n
```
