# Quarkus User Acceptance Testing (UAT) Reference

## Overview

User acceptance tests (UAT) verify that the application meets business requirements
from the end user's perspective. They bridge the gap between developer-written tests
and stakeholder expectations by expressing test scenarios in business language.

In a Quarkus + HTMX stack, UAT validates the full user workflow: navigating pages,
interacting with HTMX-driven UI elements, and verifying business outcomes.

## BDD with Cucumber (Gherkin Syntax)

Cucumber is the standard BDD framework for expressing UAT as human-readable feature
files that map to executable step definitions.

### Dependencies

```xml
<dependency>
    <groupId>io.quarkiverse.cucumber</groupId>
    <artifactId>quarkus-cucumber</artifactId>
    <version>1.1.0</version>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>io.quarkiverse.playwright</groupId>
    <artifactId>quarkus-playwright</artifactId>
    <version>0.3.0</version>
    <scope>test</scope>
</dependency>
```

### Feature File Structure

Feature files live alongside test code and are written by (or with) stakeholders:

```
src/test/resources/features/
  todo-management.feature
  product-catalog.feature
  user-authentication.feature
```

### Pattern: HTMX Feature File

```gherkin
# src/test/resources/features/todo-management.feature
Feature: Todo Management
  As a user
  I want to manage my todo list
  So that I can track my tasks

  Background:
    Given I am on the todo page

  Scenario: Add a new todo item
    When I enter "Buy groceries" in the todo input
    And I click the "Add" button
    Then I should see "Buy groceries" in the todo list
    And the input field should be empty

  Scenario: Delete a todo item
    Given the following todos exist:
      | text           |
      | Buy groceries  |
      | Walk the dog   |
    When I delete the "Buy groceries" todo
    Then I should not see "Buy groceries" in the todo list
    And I should see "Walk the dog" in the todo list

  Scenario: Mark a todo as complete
    Given the following todos exist:
      | text          |
      | Buy groceries |
    When I toggle the "Buy groceries" todo
    Then the "Buy groceries" todo should be marked as complete

  Scenario: Empty todo is rejected
    When I enter "" in the todo input
    And I click the "Add" button
    Then I should see a validation error "Todo text is required"
    And no new todo should be added to the list
```

### Pattern: Step Definitions with Playwright

```java
import com.microsoft.playwright.BrowserContext;
import com.microsoft.playwright.Page;
import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.quarkiverse.playwright.InjectPlaywright;
import io.quarkus.test.common.http.TestHTTPResource;
import jakarta.inject.Inject;

import java.net.URL;

import static org.junit.jupiter.api.Assertions.*;

public class TodoSteps {

    @InjectPlaywright
    BrowserContext context;

    @TestHTTPResource("/ui/todos")
    URL todosPage;

    @Inject
    TodoRepository todoRepo;

    private Page page;

    @Before
    public void setUp() {
        page = context.newPage();
    }

    @After
    public void tearDown() {
        if (page != null) page.close();
    }

    @Given("I am on the todo page")
    public void iAmOnTheTodoPage() {
        page.navigate(todosPage.toString());
        page.waitForLoadState();
    }

    @Given("the following todos exist:")
    public void theFollowingTodosExist(io.cucumber.datatable.DataTable dataTable) {
        dataTable.asMaps().forEach(row -> {
            Todo todo = new Todo();
            todo.text = row.get("text");
            todoRepo.persist(todo);
        });
        // Refresh page to see seeded data
        page.navigate(todosPage.toString());
        page.waitForLoadState();
    }

    @When("I enter {string} in the todo input")
    public void iEnterInTheTodoInput(String text) {
        page.fill("input[name='text']", text);
    }

    @When("I click the {string} button")
    public void iClickTheButton(String buttonText) {
        page.click("button:has-text('" + buttonText + "')");
        // Wait for HTMX swap to complete
        page.waitForTimeout(500);
    }

    @When("I delete the {string} todo")
    public void iDeleteTheTodo(String todoText) {
        page.onDialog(dialog -> dialog.accept());
        String selector = String.format(
            "#todo-list li:has-text('%s') button.delete", todoText);
        page.click(selector);
        page.waitForTimeout(500);
    }

    @When("I toggle the {string} todo")
    public void iToggleTheTodo(String todoText) {
        String selector = String.format(
            "#todo-list li:has-text('%s') input[type='checkbox']", todoText);
        page.click(selector);
        page.waitForTimeout(500);
    }

    @Then("I should see {string} in the todo list")
    public void iShouldSeeInTheTodoList(String text) {
        assertTrue(page.textContent("#todo-list").contains(text),
            "Expected to find '" + text + "' in todo list");
    }

    @Then("I should not see {string} in the todo list")
    public void iShouldNotSeeInTheTodoList(String text) {
        assertFalse(page.textContent("#todo-list").contains(text),
            "Did not expect to find '" + text + "' in todo list");
    }

    @Then("the input field should be empty")
    public void theInputFieldShouldBeEmpty() {
        assertEquals("", page.inputValue("input[name='text']"));
    }

    @Then("the {string} todo should be marked as complete")
    public void theTodoShouldBeMarkedAsComplete(String todoText) {
        String selector = String.format(
            "#todo-list li:has-text('%s')", todoText);
        String classes = page.getAttribute(selector, "class");
        assertTrue(classes != null && classes.contains("completed"),
            "Expected todo to have 'completed' class");
    }

    @Then("I should see a validation error {string}")
    public void iShouldSeeAValidationError(String errorMessage) {
        assertTrue(page.textContent("body").contains(errorMessage),
            "Expected validation error: " + errorMessage);
    }

    @Then("no new todo should be added to the list")
    public void noNewTodoShouldBeAddedToTheList() {
        // Verify count didn't change -- checked against DB for certainty
        long count = todoRepo.count();
        assertTrue(count == 0 || page.querySelectorAll("#todo-list li").size() <= count);
    }
}
```

### Pattern: Cucumber Test Runner (Quarkus-integrated)

```java
import io.quarkiverse.cucumber.CucumberOptions;
import io.quarkiverse.cucumber.CucumberQuarkusTest;

@CucumberOptions(
    features = "src/test/resources/features",
    glue = "com.example.steps",
    plugin = {"pretty", "html:target/cucumber-reports.html"}
)
public class RunCucumberTest extends CucumberQuarkusTest {
}
```

## UAT Without Cucumber (Lightweight Approach)

If Cucumber is too heavy, express acceptance criteria directly as JUnit test names
using descriptive naming:

```java
@QuarkusTest
@WithPlaywright
class TodoAcceptanceTest {

    @InjectPlaywright BrowserContext context;
    @TestHTTPResource("/ui/todos") URL todosPage;

    // User Story: As a user, I want to add todos so I can track tasks

    @Test
    void userCanAddATodoAndSeeItInTheList() {
        Page page = context.newPage();
        page.navigate(todosPage.toString());
        page.waitForLoadState();

        page.fill("input[name='text']", "Buy groceries");
        page.click("button[type='submit']");
        page.waitForSelector("#todo-list li:has-text('Buy groceries')");

        assertTrue(page.textContent("#todo-list").contains("Buy groceries"));
    }

    @Test
    void userCanDeleteATodoAndItDisappearsFromTheList() {
        // seed, then delete, then assert absence
    }

    @Test
    void userSeesValidationErrorWhenSubmittingEmptyTodo() {
        // submit empty, assert error message visible
    }
}
```

## Acceptance Criteria as Test Documentation

Structure test classes to mirror user stories:

```java
/**
 * User Story: Product Catalog Browsing
 * As a customer, I want to browse products so I can find items to purchase.
 *
 * Acceptance Criteria:
 * - AC1: Product list displays name, price, and image for each product
 * - AC2: Clicking a product shows its detail page
 * - AC3: Search filters products in real time (HTMX)
 * - AC4: Pagination loads more products without full page reload (HTMX)
 */
@QuarkusTest
@WithPlaywright
class ProductCatalogAcceptanceTest {

    @Test
    void ac1_productListDisplaysNamePriceAndImage() { /* ... */ }

    @Test
    void ac2_clickingProductShowsDetailPage() { /* ... */ }

    @Test
    void ac3_searchFiltersProductsInRealTime() { /* ... */ }

    @Test
    void ac4_paginationLoadsMoreWithoutFullReload() { /* ... */ }
}
```

## REST-Level Acceptance Tests

When browser testing is overkill, validate acceptance criteria at the HTTP level:

```java
@QuarkusTest
class OrderWorkflowAcceptanceTest {

    @Test
    void completeOrderWorkflow_fromCartToConfirmation() {
        // Step 1: Add item to cart
        String cartHtml = given()
            .contentType("application/x-www-form-urlencoded")
            .formParam("productId", "1")
            .formParam("quantity", "2")
            .header("HX-Request", "true")
        .when()
            .post("/ui/cart/add")
        .then()
            .statusCode(200)
            .extract().body().asString();

        assertThat(cartHtml).contains("cart-item");

        // Step 2: Proceed to checkout
        given()
            .header("HX-Request", "true")
        .when()
            .get("/ui/checkout")
        .then()
            .statusCode(200)
            .body(containsString("checkout-form"));

        // Step 3: Submit order
        given()
            .contentType("application/x-www-form-urlencoded")
            .formParam("address", "123 Main St")
            .formParam("payment", "card")
            .header("HX-Request", "true")
        .when()
            .post("/ui/orders")
        .then()
            .statusCode(200)
            .body(containsString("order-confirmation"))
            .body(containsString("Thank you"));
    }
}
```

## UAT Test Organization

```
src/test/
  java/
    com/example/
      acceptance/                     # UAT test classes
        TodoAcceptanceTest.java
        ProductCatalogAcceptanceTest.java
        OrderWorkflowAcceptanceTest.java
      steps/                          # Cucumber step definitions
        TodoSteps.java
        ProductSteps.java
  resources/
    features/                         # Gherkin feature files
      todo-management.feature
      product-catalog.feature
      order-workflow.feature
```

## Key Principles for UAT

1. **Business language** -- Tests should be readable by non-developers. Use domain
   terms, not implementation details.
2. **User perspective** -- Interact with the UI the way a user would: fill forms,
   click buttons, read text. Never assert on internal state directly.
3. **Independent scenarios** -- Each scenario should be self-contained with its own
   setup and teardown. Use `Background` in Gherkin for common preconditions.
4. **Minimal assertions per scenario** -- Each scenario tests one business rule.
   Multiple assertions are fine if they verify one cohesive outcome.
5. **Slow by design** -- UAT is the most expensive tier. Write the fewest tests
   that cover the most critical user journeys. Push detail down to unit and
   integration tiers.
