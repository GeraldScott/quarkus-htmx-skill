# Quarkus Testing Usage Patterns

Use these patterns for repeatable testing workflows. See also:
- `unit-testing.md` -- pure unit tests, `@QuarkusComponentTest`, TDD workflow
- `e2e-testing.md` -- Playwright browser tests, `@QuarkusIntegrationTest`
- `uat-testing.md` -- Cucumber/Gherkin BDD, acceptance criteria as tests

## Pattern: Integration Test with REST Assured and Dev Services

When to use:

- You want a full integration test against real infrastructure with zero manual setup.

Example:

```java
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.RestAssured;
import jakarta.transaction.Transactional;
import org.junit.jupiter.api.Test;

import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
class FruitResourceTest {
    @Test
    void testListEndpoint() {
        RestAssured.given()
            .when().get("/fruits")
            .then()
            .statusCode(200);
    }

    @Test
    void testCreateEndpoint() {
        RestAssured.given()
            .contentType("application/json")
            .body("{\"name\": \"Apple\"}")
            .when().post("/fruits")
            .then()
            .statusCode(201);
    }
}
```

Dev Services starts a database container automatically. No URL or credentials needed in test config.

## Pattern: Override Configuration with a Test Profile

When to use:

- A test needs different config values than the default `%test` profile.

Example:

```java
import io.quarkus.test.junit.QuarkusTestProfile;

import java.util.Map;

public class MockedExternalApiProfile implements QuarkusTestProfile {
    @Override
    public Map<String, String> getConfigOverrides() {
        return Map.of(
            "external.api.url", "http://localhost:8089",
            "external.api.timeout", "1S"
        );
    }

    @Override
    public String getConfigProfile() {
        return "test-mocked";
    }
}
```

```java
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.TestProfile;

@QuarkusTest
@TestProfile(MockedExternalApiProfile.class)
class ExternalApiTest {
    @Test
    void testWithMockedApi() {
    }
}
```

## Pattern: Replace a Bean with `@InjectMock`

When to use:

- A CDI bean calls an external service or has side effects that should be controlled in tests.

Example:

```java
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.RestAssured;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

@QuarkusTest
class PaymentResourceTest {
    @InjectMock
    PaymentGateway gateway;

    @BeforeEach
    void setup() {
        Mockito.when(gateway.charge(Mockito.any()))
            .thenReturn(new PaymentResult("ok"));
    }

    @Test
    void testPayment() {
        RestAssured.given()
            .contentType("application/json")
            .body("{\"amount\": 100}")
            .when().post("/payments")
            .then()
            .statusCode(200);
    }
}
```

Prefer real implementations backed by Dev Services over mocks when feasible.

## Pattern: Use CDI Alternatives via Test Profile

When to use:

- A bean should be swapped for a test-specific implementation without `@InjectMock`.

Example:

```java
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;

@Alternative
@Priority(1)
@ApplicationScoped
class MockNotificationService extends NotificationService {
    @Override
    public void send(String message) {
        // no-op in tests
    }
}

public class MockedProfile implements QuarkusTestProfile {
    @Override
    public Set<Class<?>> getEnabledAlternatives() {
        return Set.of(MockNotificationService.class);
    }
}
```

## Pattern: Native Integration Test

When to use:

- You need to verify the application works correctly as a native executable.

Example:

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

Run with:

```bash
./mvnw verify -Dnative
```

`@QuarkusIntegrationTest` does not support CDI injection or `@InjectMock` because it tests the packaged artifact as a black box.

## Pattern: Scope a Test Resource to One Test Class

When to use:

- A heavy external resource (WireMock, custom container) should only start for specific tests.

Example:

```java
@QuarkusTest
@QuarkusTestResource(value = WireMockResource.class, restrictToAnnotatedClass = true)
class SpecificApiTest {
}
```

Without `restrictToAnnotatedClass = true`, the resource starts for all `@QuarkusTest` classes in the module.

## Pattern: Database test state management with `@TestTransaction`

When to use:

- Test data should be automatically rolled back after each test method.

Example:

```java
@QuarkusTest
@TestTransaction
class OrderRepositoryTest {

    @Inject OrderRepository repo;

    @Test
    void persist_andFind() {
        Order order = new Order();
        order.status = OrderStatus.PENDING;
        repo.persist(order);

        assertThat(repo.findById(order.id)).isPresent();
        // Rolled back after the test -- no cleanup needed
    }
}
```

## Pattern: Test HTMX endpoints

When to use:

- You are testing endpoints that return HTML fragments for HTMX consumption.

### Test that a page renders HTML

```java
@QuarkusTest
class ProductUiResourceTest {

    @Test
    void productList_rendersTable() {
        given()
            .accept(ContentType.HTML)
        .when()
            .get("/ui/products")
        .then()
            .statusCode(200)
            .body(containsString("<table"))
            .body(containsString("product-list"));
    }
}
```

### Test HTMX POST with form params and HX-Request header

```java
@QuarkusTest
class ProductUiResourceTest {

    @Test
    void addProduct_htmxPost_returnsRow() {
        given()
            .contentType("application/x-www-form-urlencoded")
            .formParam("name", "Widget")
            .formParam("price", "9.99")
            .header("HX-Request", "true")     // HTMX sets this header
        .when()
            .post("/ui/products")
        .then()
            .statusCode(200)
            .body(containsString("Widget"));
    }
}
```

### Test HTMX fragments

When testing endpoints that return template fragments rather than full pages, assert on the HTML content of the fragment:

```java
@QuarkusTest
class TodoUiResourceTest {

    @Test
    void addTodo_returnsListItem() {
        given()
            .contentType("application/x-www-form-urlencoded")
            .formParam("text", "Buy groceries")
            .header("HX-Request", "true")
        .when()
            .post("/ui/todos")
        .then()
            .statusCode(200)
            .body(containsString("Buy groceries"))
            .body(containsString("<li"));
    }

    @Test
    void deleteTodo_returnsEmpty() {
        given()
            .header("HX-Request", "true")
        .when()
            .delete("/ui/todos/1")
        .then()
            .statusCode(200)
            .body(is(""));
    }
}
```

Key points for HTMX endpoint testing:

- Send `HX-Request: true` header to match how HTMX sends requests.
- Use `application/x-www-form-urlencoded` content type with `formParam()` for HTMX form submissions.
- Assert on HTML content using `containsString()` for fragment content validation.
- Test both successful responses and empty responses (for delete operations with `outerHTML` swap).

## Pattern: TDD with Continuous Testing

When to use:

- You are actively developing a feature and want sub-second feedback on every save.

### Start continuous testing in Dev Mode

```bash
./mvnw quarkus:dev
# Press 'r' in the console to run all tests
# Tests re-run automatically on file save
```

### Start continuous testing standalone (no Dev UI)

```bash
./mvnw quarkus:test
# Useful when Dev Mode interferes (e.g., WireMock port conflict)
```

### Configure which tests run in continuous testing

```properties
# Run only fast tests (unit + component) during development
quarkus.test.continuous-testing=enabled
quarkus.test.include-pattern=.*UnitTest|.*ComponentTest

# Exclude slow E2E tests from continuous testing
quarkus.test.exclude-pattern=.*E2ETest|.*IT|.*AcceptanceTest
```

### TDD inner loop

1. Write a failing test (unit or integration).
2. Save the file -- continuous testing runs automatically.
3. See the red result in the console.
4. Write the minimum code to pass.
5. Save -- see the green result.
6. Refactor -- save -- confirm still green.

## Pattern: Test Organization by Tier

When to use:

- You want a clear separation between test tiers for selective execution.

### Directory structure

```
src/test/java/com/example/
  service/                        # Unit tests (plain JUnit + Mockito)
    PricingServiceTest.java
    OrderValidatorTest.java
  component/                      # @QuarkusComponentTest
    GreetingServiceComponentTest.java
  resource/                       # @QuarkusTest + REST Assured
    FruitResourceTest.java
    ProductUiResourceTest.java
  e2e/                            # @QuarkusTest + @WithPlaywright
    TodoE2ETest.java
  acceptance/                     # UAT / Cucumber
    TodoAcceptanceTest.java
  it/                             # @QuarkusIntegrationTest
    ApplicationIT.java
src/test/resources/
  features/                       # Gherkin feature files
    todo-management.feature
```

### Maven Surefire/Failsafe configuration for tiered execution

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <configuration>
        <!-- Unit + integration tests run with `mvn test` -->
        <excludes>
            <exclude>**/*IT.java</exclude>
            <exclude>**/*E2ETest.java</exclude>
            <exclude>**/*AcceptanceTest.java</exclude>
        </excludes>
    </configuration>
</plugin>
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-failsafe-plugin</artifactId>
    <configuration>
        <!-- E2E + UAT + integration tests run with `mvn verify` -->
        <includes>
            <include>**/*IT.java</include>
            <include>**/*E2ETest.java</include>
            <include>**/*AcceptanceTest.java</include>
        </includes>
    </configuration>
</plugin>
```
