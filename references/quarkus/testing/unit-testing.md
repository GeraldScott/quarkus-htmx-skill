# Quarkus Unit Testing Reference

## Overview

Unit tests verify individual classes and methods in isolation, without starting the
Quarkus container or any infrastructure. They are the fastest tier of the testing
pyramid and provide the tightest TDD feedback loop.

### When to write unit tests

- Pure business logic: validators, calculators, mappers, DTOs, utility methods.
- Complex branching or algorithms where exhaustive input coverage matters.
- Code that does NOT depend on CDI injection, JPA, or HTTP infrastructure.
- When you need sub-second feedback during red-green-refactor cycles.

### When NOT to write unit tests

- Thin resource/controller classes that only delegate to services (test via integration).
- Panache entity static methods (they require the Quarkus runtime).
- Configuration mapping classes (`@ConfigMapping`).
- Anything where the wiring IS the logic -- prefer `@QuarkusTest` or `@QuarkusComponentTest`.

## TDD Workflow (Red-Green-Refactor)

```
1. RED    -- Write a failing test that defines the expected behavior.
2. GREEN  -- Write the minimum production code to make the test pass.
3. REFACTOR -- Clean up duplication in both test and production code.
4. REPEAT
```

Run continuously with `./mvnw quarkus:test` for sub-second feedback on save.

## Plain JUnit 5 + Mockito (No Container)

The fastest unit tests use plain JUnit 5 with Mockito -- no Quarkus annotations needed.

### Dependencies

```xml
<!-- Already included by quarkus-junit5, but can also be used standalone -->
<dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.mockito</groupId>
    <artifactId>mockito-junit-jupiter</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.assertj</groupId>
    <artifactId>assertj-core</artifactId>
    <scope>test</scope>
</dependency>
```

### Pattern: Service logic with constructor injection

Production code designed for testability uses constructor injection:

```java
@ApplicationScoped
public class PricingService {

    private final TaxCalculator taxCalculator;
    private final DiscountRepository discountRepo;

    @Inject
    public PricingService(TaxCalculator taxCalculator, DiscountRepository discountRepo) {
        this.taxCalculator = taxCalculator;
        this.discountRepo = discountRepo;
    }

    public BigDecimal calculateTotal(Order order) {
        BigDecimal subtotal = order.lineItems().stream()
            .map(li -> li.price().multiply(BigDecimal.valueOf(li.quantity())))
            .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal discount = discountRepo.findByCode(order.discountCode())
            .map(d -> subtotal.multiply(d.percentage()))
            .orElse(BigDecimal.ZERO);

        return taxCalculator.applyTax(subtotal.subtract(discount));
    }
}
```

Unit test -- no container, sub-second execution:

```java
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PricingServiceTest {

    @Mock TaxCalculator taxCalculator;
    @Mock DiscountRepository discountRepo;
    @InjectMocks PricingService pricingService;

    @Test
    void calculateTotal_withDiscount_appliesDiscountBeforeTax() {
        // Arrange
        var items = List.of(new LineItem("Widget", new BigDecimal("10.00"), 2));
        var order = new Order(items, "SAVE10");

        when(discountRepo.findByCode("SAVE10"))
            .thenReturn(Optional.of(new Discount(new BigDecimal("0.10"))));
        when(taxCalculator.applyTax(any()))
            .thenAnswer(inv -> inv.getArgument(0, BigDecimal.class)
                .multiply(new BigDecimal("1.08")));

        // Act
        BigDecimal total = pricingService.calculateTotal(order);

        // Assert
        assertThat(total).isEqualByComparingTo("19.44"); // (20 - 2) * 1.08
    }

    @Test
    void calculateTotal_noDiscount_appliesTaxToFullSubtotal() {
        var items = List.of(new LineItem("Widget", new BigDecimal("10.00"), 1));
        var order = new Order(items, null);

        when(discountRepo.findByCode(null)).thenReturn(Optional.empty());
        when(taxCalculator.applyTax(any()))
            .thenAnswer(inv -> inv.getArgument(0, BigDecimal.class)
                .multiply(new BigDecimal("1.08")));

        BigDecimal total = pricingService.calculateTotal(order);

        assertThat(total).isEqualByComparingTo("10.80");
    }
}
```

### Pattern: Validator / mapper unit test

```java
class OrderValidatorTest {

    private final OrderValidator validator = new OrderValidator();

    @Test
    void validate_emptyLineItems_returnsError() {
        var order = new Order(List.of(), null);
        var result = validator.validate(order);
        assertThat(result.errors()).containsExactly("Order must have at least one item");
    }

    @Test
    void validate_negativeQuantity_returnsError() {
        var items = List.of(new LineItem("X", BigDecimal.TEN, -1));
        var result = validator.validate(new Order(items, null));
        assertThat(result.errors()).contains("Quantity must be positive");
    }

    @Test
    void validate_validOrder_returnsNoErrors() {
        var items = List.of(new LineItem("X", BigDecimal.TEN, 1));
        var result = validator.validate(new Order(items, null));
        assertThat(result.isValid()).isTrue();
    }
}
```

## `@QuarkusComponentTest` (Lightweight CDI Container)

When code depends on CDI wiring but you don't need the full application context:

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
    void greet_knownUser_returnsPersonalizedGreeting() {
        Mockito.when(userRepo.findByName("Ada")).thenReturn(new User("Ada"));
        assertEquals("Hello, Ada!", service.greet("Ada"));
    }
}
```

### Dependency

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit5-component</artifactId>
    <scope>test</scope>
</dependency>
```

### When to prefer `@QuarkusComponentTest` over plain Mockito

- The class under test uses CDI interceptors (e.g., `@Transactional`, `@Logged`).
- The class uses `@ConfigProperty` or `@ConfigMapping` for configuration.
- You want to test CDI event observers or producers.
- The wiring between 2-3 beans is itself the behavior under test.

### When to prefer plain JUnit + Mockito instead

- No CDI annotations on the class under test.
- You need maximum speed (no CDI container startup at all).
- The class is a pure function or utility.

## Test Naming Conventions

Use descriptive method names that express the scenario and expected outcome:

```
methodUnderTest_scenario_expectedBehavior
```

Examples:
- `calculateTotal_withDiscount_appliesDiscountBeforeTax`
- `validate_emptyLineItems_returnsError`
- `greet_unknownUser_returnsDefaultGreeting`

## Arrange-Act-Assert Structure

Every unit test should follow this structure:

```java
@Test
void methodName_scenario_expected() {
    // Arrange -- set up test data and mock behavior
    when(mock.method()).thenReturn(value);

    // Act -- call the method under test
    var result = sut.method(input);

    // Assert -- verify the outcome
    assertThat(result).isEqualTo(expected);
}
```

## Continuous Testing Integration

Unit tests run first in the continuous testing pipeline due to speed:

```properties
# application.properties
quarkus.test.continuous-testing=enabled

# Run only unit tests (no @QuarkusTest) for fastest feedback
quarkus.test.include-pattern=.*UnitTest|.*Test[^I].*
```

Or run continuous testing standalone:

```bash
./mvnw quarkus:test
```

Press `r` to re-run all, `f` to re-run failures, `o` for toggle output.
