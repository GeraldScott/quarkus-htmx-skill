# Quarkus End-to-End Testing Reference

## Overview

End-to-end (E2E) tests verify the entire application stack from the user's
perspective -- browser interaction, HTTP requests through the full backend, real
database, and real template rendering. They sit at the top of the testing pyramid:
fewest in number, highest confidence per test, slowest to execute.

## Testing Tiers for E2E

| Approach | What it tests | Speed | Use when |
|----------|--------------|-------|----------|
| `@QuarkusTest` + REST Assured (HTML) | HTTP request through full stack, no browser | Fast | HTMX fragment responses, server-rendered HTML assertions |
| `@QuarkusTest` + Playwright | Full browser rendering + JS execution | Medium | HTMX interactions, dynamic DOM updates, CSS/layout |
| `@QuarkusIntegrationTest` + REST Assured | Packaged artifact (JAR/native), black-box | Medium | Pre-deployment smoke tests, native image validation |
| `@QuarkusIntegrationTest` + Playwright | Packaged artifact + real browser | Slow | Final acceptance before release |

## Playwright E2E Tests (Browser-Based)

Quarkus has first-class Playwright support for cross-browser E2E testing that
leverages Dev Services and mocking features.

### Dependencies

```xml
<dependency>
    <groupId>io.quarkiverse.playwright</groupId>
    <artifactId>quarkus-playwright</artifactId>
    <version>0.3.0</version>
    <scope>test</scope>
</dependency>
```

### Pattern: Basic page navigation

```java
import com.microsoft.playwright.BrowserContext;
import com.microsoft.playwright.Page;
import com.microsoft.playwright.Response;
import io.quarkiverse.playwright.InjectPlaywright;
import io.quarkiverse.playwright.WithPlaywright;
import io.quarkus.test.common.http.TestHTTPResource;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;

import java.net.URL;

@QuarkusTest
@WithPlaywright
class HomePageE2ETest {

    @InjectPlaywright
    BrowserContext context;

    @TestHTTPResource("/")
    URL index;

    @Test
    void homePage_loadsSuccessfully() {
        Page page = context.newPage();
        Response response = page.navigate(index.toString());

        Assertions.assertEquals("OK", response.statusText());
        page.waitForLoadState();
        Assertions.assertTrue(page.title().contains("My App"));
    }
}
```

### Pattern: HTMX interaction test

Test that HTMX attributes trigger server requests and update the DOM correctly:

```java
@QuarkusTest
@WithPlaywright
class TodoE2ETest {

    @InjectPlaywright
    BrowserContext context;

    @TestHTTPResource("/ui/todos")
    URL todosPage;

    @Test
    void addTodo_htmxPost_appendsItemToList() {
        Page page = context.newPage();
        page.navigate(todosPage.toString());
        page.waitForLoadState();

        // Fill the form and submit (HTMX intercepts the form submission)
        page.fill("input[name='text']", "Buy groceries");
        page.click("button[type='submit']");

        // Wait for HTMX to complete the swap
        page.waitForSelector("#todo-list li:has-text('Buy groceries')");

        // Assert the item appears in the list
        String listContent = page.textContent("#todo-list");
        Assertions.assertTrue(listContent.contains("Buy groceries"));

        // Assert the form was reset (hx-on::after-request="this.reset()")
        String inputValue = page.inputValue("input[name='text']");
        Assertions.assertEquals("", inputValue);
    }

    @Test
    void deleteTodo_htmxDelete_removesItemFromDom() {
        Page page = context.newPage();
        page.navigate(todosPage.toString());
        page.waitForLoadState();

        // Count initial items
        int initialCount = page.querySelectorAll("#todo-list li").size();

        // Click the delete button (with hx-confirm, handle the dialog)
        page.onDialog(dialog -> dialog.accept());
        page.click("#todo-list li:first-child button.delete");

        // Wait for HTMX swap to complete (outerHTML removes the element)
        page.waitForTimeout(500);

        int finalCount = page.querySelectorAll("#todo-list li").size();
        Assertions.assertEquals(initialCount - 1, finalCount);
    }
}
```

### Pattern: Test HTMX indicators and loading states

```java
@Test
void search_showsLoadingIndicator_duringRequest() {
    Page page = context.newPage();
    page.navigate(searchPage.toString());

    // Type in search field (triggers hx-get with delay)
    page.fill("input[name='q']", "quarkus");

    // The indicator should become visible during the request
    page.waitForSelector(".htmx-indicator.htmx-request",
        new Page.WaitForSelectorOptions().setTimeout(2000));

    // After the response, indicator should be hidden again
    page.waitForSelector("#search-results:has-text('quarkus')");
    Assertions.assertFalse(
        page.isVisible(".htmx-indicator.htmx-request"));
}
```

## `@QuarkusIntegrationTest` (Packaged Artifact Testing)

Tests the actual JAR or native executable as a black box. No CDI injection, no
`@InjectMock`. The application runs in a separate process.

### Pattern: Smoke test the packaged artifact

```java
import io.quarkus.test.junit.QuarkusIntegrationTest;
import io.restassured.RestAssured;
import org.junit.jupiter.api.Test;

import static org.hamcrest.CoreMatchers.containsString;

@QuarkusIntegrationTest
class ApplicationIT {

    @Test
    void healthCheck_returnsUp() {
        RestAssured.given()
            .when().get("/q/health/ready")
            .then()
            .statusCode(200)
            .body(containsString("UP"));
    }

    @Test
    void homePage_rendersHtml() {
        RestAssured.given()
            .accept("text/html")
            .when().get("/")
            .then()
            .statusCode(200)
            .body(containsString("<!DOCTYPE html"));
    }
}
```

### Pattern: Reuse @QuarkusTest tests for integration

```java
// Extend the existing test class -- all tests run again against the packaged artifact
@QuarkusIntegrationTest
class FruitResourceIT extends FruitResourceTest {
    // Inherits all @Test methods; runs against JAR/native
}
```

Run with:

```bash
# JVM mode integration tests
./mvnw verify

# Native image integration tests
./mvnw verify -Dnative
```

## Full-Stack E2E with Dev Services

E2E tests benefit from Dev Services provisioning real infrastructure:

```properties
# No config needed -- Dev Services auto-provisions PostgreSQL, Kafka, etc.
# The test starts with a real database, real schema, real migrations.
```

### Pattern: E2E with seeded test data

```java
@QuarkusTest
@WithPlaywright
@TestTransaction
class ProductCatalogE2ETest {

    @Inject EntityManager em;

    @InjectPlaywright BrowserContext context;
    @TestHTTPResource("/ui/products") URL productsPage;

    @BeforeEach
    void seedData() {
        Product p = new Product();
        p.name = "Test Widget";
        p.price = new BigDecimal("29.99");
        em.persist(p);
        em.flush();
    }

    @Test
    void productList_showsSeededProduct() {
        Page page = context.newPage();
        page.navigate(productsPage.toString());
        page.waitForLoadState();

        Assertions.assertTrue(
            page.textContent("#product-list").contains("Test Widget"));
    }
}
```

## Custom Test Resource for External Services

When E2E tests depend on external APIs, use `QuarkusTestResourceLifecycleManager`:

```java
public class WireMockResource implements QuarkusTestResourceLifecycleManager {

    private WireMockServer wireMock;

    @Override
    public Map<String, String> start() {
        wireMock = new WireMockServer(WireMockConfiguration.options().dynamicPort());
        wireMock.start();
        wireMock.stubFor(get(urlEqualTo("/api/rates"))
            .willReturn(okJson("{\"usd\": 1.0, \"eur\": 0.85}")));
        return Map.of("exchange.api.url",
            "http://localhost:" + wireMock.port());
    }

    @Override
    public void stop() {
        if (wireMock != null) wireMock.stop();
    }
}

@QuarkusTest
@QuarkusTestResource(value = WireMockResource.class, restrictToAnnotatedClass = true)
@WithPlaywright
class CurrencyConversionE2ETest {
    // Full E2E with a stubbed external dependency
}
```

## E2E Test Organization

```
src/test/java/
  com/example/
    unit/                   # Plain JUnit + Mockito (fastest)
    integration/            # @QuarkusTest + REST Assured
    e2e/                    # @QuarkusTest + @WithPlaywright
      HomePageE2ETest.java
      TodoE2ETest.java
      ProductCatalogE2ETest.java
    it/                     # @QuarkusIntegrationTest (packaged artifact)
      ApplicationIT.java
```

## Key Points for HTMX E2E Testing

- Use `page.waitForSelector()` after actions that trigger HTMX requests -- HTMX swaps are async.
- Handle `hx-confirm` dialogs with `page.onDialog(dialog -> dialog.accept())`.
- Test OOB swaps by asserting on multiple DOM targets after a single action.
- Test `hx-push-url` by checking `page.url()` after navigation.
- Use `page.waitForResponse()` to wait for specific HTMX XHR requests.
- Avoid fixed `waitForTimeout()` where possible; prefer `waitForSelector()` or `waitForResponse()`.
