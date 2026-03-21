# Quarkus Testing Reference

## Overview

Quarkus provides a test framework that starts the full application context and supports CDI injection, HTTP testing, and Dev Services inside test classes.

- Use `@QuarkusTest` for JVM-mode integration tests with full CDI and HTTP.
- Use `@QuarkusIntegrationTest` for black-box testing against the packaged artifact (JAR or native).
- Dev Services automatically provisions backing services (databases, brokers) during tests.
- Test profiles allow per-test configuration overrides and CDI alternative selection.

### General guidelines

- Prefer `@QuarkusTest` integration tests over unit tests for most Quarkus code.
- Only write unit tests when they are actually beneficial, for example methods with complex logic that can be tested in isolation.
- Use `@InjectMock` sparingly; prefer real implementations backed by Dev Services.
- Use test profiles when different tests need conflicting configuration.
- Keep test classes in `src/test/java` with the same package structure as production code.

## Extension entry points

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit5</artifactId>
    <scope>test</scope>
</dependency>

<dependency>
    <groupId>io.rest-assured</groupId>
    <artifactId>rest-assured</artifactId>
    <scope>test</scope>
</dependency>
```

For mocking support:

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit5-mockito</artifactId>
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
