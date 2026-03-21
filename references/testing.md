# Testing Reference

## Test types and when to use each

| Test type | Annotation | Starts Quarkus | Use for |
|-----------|-----------|----------------|---------|
| Full integration | `@QuarkusTest` | Full app | REST endpoints, DB, full CDI wiring |
| Profile-based | `@QuarkusTest` + `@TestProfile` | Full app (custom config) | DB-free, mock profiles |
| Unit test | none (plain JUnit 5) | No | Pure logic, services in isolation |
| Native | `@NativeImageTest` | Native binary | Smoke-test native executable |

---

## @QuarkusTest — integration tests

```java
@QuarkusTest
class OrderResourceTest {

    @Test
    void createOrder_returnsCreated() {
        given()
            .contentType(ContentType.JSON)
            .body("""
                {
                  "customerId": 1,
                  "items": [{"productId": 10, "quantity": 2}]
                }
                """)
        .when()
            .post("/api/orders")
        .then()
            .statusCode(201)
            .header("Location", containsString("/api/orders/"))
            .body("status", is("PENDING"));
    }

    @Test
    void getOrder_notFound_returns404() {
        given()
        .when()
            .get("/api/orders/999999")
        .then()
            .statusCode(404);
    }

    @Test
    void listOrders_returnsPaginatedResults() {
        given()
            .queryParam("page", 0)
            .queryParam("size", 5)
        .when()
            .get("/api/orders")
        .then()
            .statusCode(200)
            .body("data", hasSize(lessThanOrEqualTo(5)))
            .body("total", greaterThanOrEqualTo(0));
    }
}
```

RestAssured is auto-configured with the correct base URL in `@QuarkusTest`.

---

## @QuarkusTestResource — external dependencies

### Using DevServices (recommended)

DevServices automatically starts PostgreSQL for tests if Docker is available — no extra
setup needed. Flyway migrations run at test startup via `quarkus.flyway.migrate-at-start=true`.

### Custom Testcontainers resource

Use only when DevServices doesn't cover your needs (e.g., custom PostgreSQL config):

```java
public class PostgresTestResource implements QuarkusTestResourceLifecycleManager {

    private PostgreSQLContainer<?> postgres;

    @Override
    public Map<String, String> start() {
        postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("testdb")
            .withUsername("test")
            .withPassword("test");
        postgres.start();

        return Map.of(
            "quarkus.datasource.jdbc.url", postgres.getJdbcUrl(),
            "quarkus.datasource.username", postgres.getUsername(),
            "quarkus.datasource.password", postgres.getPassword()
        );
    }

    @Override
    public void stop() {
        if (postgres != null) postgres.stop();
    }
}

@QuarkusTest
@QuarkusTestResource(PostgresTestResource.class)
class MyTest { ... }
```

---

## Mocking CDI beans with Mockito

```java
@QuarkusTest
class OrderServiceTest {

    @InjectMock                          // Replaces the CDI bean with a Mockito mock
    InventoryService inventoryService;

    @Inject
    OrderService orderService;           // Real bean, but with mock InventoryService

    @Test
    void placeOrder_insufficientStock_throwsException() {
        doThrow(new InsufficientStockException("Out of stock"))
            .when(inventoryService).reserve(any());

        assertThrows(InsufficientStockException.class,
            () -> orderService.placeOrder(validRequest()));
    }

    @Test
    void placeOrder_success_reservesInventory() {
        doNothing().when(inventoryService).reserve(any());

        Order result = orderService.placeOrder(validRequest());

        verify(inventoryService, times(1)).reserve(any());
        assertThat(result.status).isEqualTo(OrderStatus.PENDING);
    }
}
```

Requires `quarkus-junit5-mockito` extension.

---

## @TestProfile — custom configuration per test class

### Profile definition

```java
public class NoDbProfile implements QuarkusTestProfile {

    @Override
    public Map<String, String> getConfigOverrides() {
        return Map.of(
            "quarkus.datasource.devservices.enabled", "false",
            "quarkus.hibernate-orm.database.generation", "none",
            "quarkus.flyway.migrate-at-start", "false"
        );
    }

    @Override
    public Set<Class<?>> getEnabledAlternatives() {
        return Set.of(MockOrderRepository.class);   // CDI @Alternative beans
    }
}
```

### Using a profile

```java
@QuarkusTest
@TestProfile(NoDbProfile.class)
class OrderServiceUnitTest {
    // Tests run without a database; MockOrderRepository substituted via CDI
}
```

---

## Database test state management

### @Transactional rollback

```java
@QuarkusTest
@TestTransaction          // Rolls back each test method automatically
class OrderRepositoryTest {

    @Inject OrderRepository repo;

    @Test
    void persist_andFind() {
        Order order = new Order();
        order.status = OrderStatus.PENDING;
        repo.persist(order);

        assertThat(repo.findById(order.id)).isPresent();
        // Rolled back after the test — no cleanup needed
    }
}
```

### Manual cleanup with @BeforeEach / @AfterEach

```java
@QuarkusTest
class OrderResourceTest {

    @Inject OrderRepository orderRepo;

    @BeforeEach
    @Transactional
    void setUp() {
        Order.deleteAll();
        // Insert known test fixtures
        Order o = new Order();
        o.status = OrderStatus.PENDING;
        o.persist();
    }
}
```

### Using test fixtures (SQL)

```properties
# application.properties for test profile
%test.quarkus.flyway.locations=db/migration,db/testdata
```

```sql
-- src/test/resources/db/testdata/V999__test_fixtures.sql
INSERT INTO customers(name, email) VALUES ('Test User', 'test@example.com');
INSERT INTO orders(customer_id, status) VALUES (1, 'PENDING');
```

---

## Qute template tests

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

---

## Useful test dependencies in pom.xml

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
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit5-mockito</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.assertj</groupId>
    <artifactId>assertj-core</artifactId>
    <scope>test</scope>
</dependency>
<!-- Only if not using DevServices: -->
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>postgresql</artifactId>
    <scope>test</scope>
</dependency>
```

---

## Running tests

```bash
# All tests (starts/stops Quarkus per test class)
./mvnw test

# Specific test class
./mvnw test -Dtest=OrderResourceTest

# Inside Dev Mode (recommended for inner loop)
# Press 'r' in the Dev Mode console, or:
quarkus.test.continuous-testing=enabled   # in application.properties

# Native tests (requires native build first)
./mvnw verify -Dnative
```

## Test performance tips

- DevServices reuses the same PostgreSQL container across tests in the same JVM run (fast).
- Put test classes that share a profile in the same module — Quarkus restarts the app
  only when the profile changes.
- Prefer `@TestTransaction` over `@BeforeEach` cleanup — it's faster and doesn't need
  explicit fixture teardown.
- Use `@QuarkusIntegrationTest` (not `@QuarkusTest`) to test the packaged JAR/native image
  as a black box.
