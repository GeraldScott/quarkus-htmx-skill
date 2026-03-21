# PostgreSQL, Panache ORM & Flyway Reference

## Datasource configuration

### application.properties — full example

For DevServices image/port/reuse config, see `project-structure.md` > DevServices PostgreSQL.

```properties
# Prod datasource (values come from environment or .env)
%prod.quarkus.datasource.db-kind=postgresql
%prod.quarkus.datasource.username=${DB_USER}
%prod.quarkus.datasource.password=${DB_PASSWORD}
%prod.quarkus.datasource.jdbc.url=jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME}

# Connection pool (Agroal)
%prod.quarkus.datasource.jdbc.min-size=5
%prod.quarkus.datasource.jdbc.max-size=20
%prod.quarkus.datasource.jdbc.acquisition-timeout=30S

# Hibernate
%dev.quarkus.hibernate-orm.log.sql=true
%dev.quarkus.hibernate-orm.log.format-sql=true
%prod.quarkus.hibernate-orm.database.generation=none

# Flyway
quarkus.flyway.migrate-at-start=true
quarkus.flyway.locations=db/migration
# quarkus.flyway.baseline-on-migrate=true  # Enable when adding Flyway to existing DB
```

### Multiple datasources

```properties
quarkus.datasource.db-kind=postgresql          # default datasource
quarkus.datasource."reporting".db-kind=postgresql
quarkus.datasource."reporting".jdbc.url=jdbc:postgresql://...
```

```java
@ApplicationScoped
public class ReportingRepository implements PanacheRepository<Report> {
    @PersistenceUnit("reporting")
    EntityManagerFactory emf;
}
```

---

## Panache — Active Record vs. Repository

**Active Record**: Query methods live on the entity class. Best for simple CRUD.

**Repository**: Query methods in a separate CDI bean. Preferred when the entity has complex
logic, you need mocking, or multiple aggregates share query patterns.

Mix and match: Active Record for simple entities, Repository for complex ones.

---

## Panache Entity (Active Record style)

```java
@Entity
@Table(name = "orders",
       indexes = {
           @Index(name = "idx_orders_customer", columnList = "customer_id"),
           @Index(name = "idx_orders_created_at", columnList = "created_at DESC")
       })
@NamedQuery(name = "Order.pendingOlderThan",
    query = "FROM Order WHERE status = 'PENDING' AND createdAt < :cutoff")
public class Order extends PanacheEntity {

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    public OrderStatus status;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "customer_id", nullable = false)
    public Customer customer;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    public List<OrderLine> lines = new ArrayList<>();

    @Column(name = "created_at", nullable = false, updatable = false)
    public Instant createdAt;

    @Column(name = "total_amount", precision = 10, scale = 2)
    public BigDecimal totalAmount;

    @PrePersist
    void onPersist() {
        this.createdAt = Instant.now();
    }

    // ----- Static query helpers (Active Record pattern) -----

    public static List<Order> findByCustomer(Customer customer) {
        return list("customer", customer);
    }

    public static List<Order> findByStatus(OrderStatus status) {
        return list("status = ?1 ORDER BY createdAt DESC", status);
    }

    public static PanacheQuery<Order> findPendingOlderThan(Instant cutoff) {
        return find("#Order.pendingOlderThan", Parameters.with("cutoff", cutoff));
    }

    public static long countByStatus(OrderStatus status) {
        return count("status", status);
    }

    public static void markAllPendingAsExpired(Instant cutoff) {
        update("status = ?1 WHERE status = ?2 AND createdAt < ?3",
               OrderStatus.EXPIRED, OrderStatus.PENDING, cutoff);
    }
}
```

### PanacheEntity vs. PanacheBaseEntity

- **PanacheEntity**: adds a `Long id` field (auto-generated). Use this 95% of the time.
- **PanacheBaseEntity<K>**: use when you need a non-Long PK (e.g., `UUID`, composite key).

```java
@Entity
public class Product extends PanacheBaseEntity<UUID> {
    @Id
    @GeneratedValue
    public UUID id;
    // ...
}
```

---

## Panache Repository pattern

```java
@ApplicationScoped
public class OrderRepository implements PanacheRepository<Order> {

    // PanacheRepository provides: findById, findAll, list, stream, count,
    //   persist, delete, update, and their variants.

    public Optional<Order> findWithLines(Long id) {
        return find(
            "FROM Order o LEFT JOIN FETCH o.lines WHERE o.id = ?1", id
        ).firstResultOptional();
    }

    public Page<Order> findByCustomerPaged(Customer customer, int page, int size) {
        return find("customer = ?1 ORDER BY createdAt DESC", customer)
            .page(page, size);
    }

    public List<Order> findRecentByStatus(OrderStatus status, int limit) {
        return find("status = ?1 ORDER BY createdAt DESC", status)
            .page(0, limit)
            .list();
    }

    // Bulk update — returns number of rows affected
    public int expirePending(Instant cutoff) {
        return update(
            "status = ?1 WHERE status = ?2 AND createdAt < ?3",
            OrderStatus.EXPIRED, OrderStatus.PENDING, cutoff
        );
    }
}
```

---

## Common Panache query patterns

```java
// Equals shorthand
Order.find("status", OrderStatus.PENDING).list();

// JPQL fragment (Panache auto-adds FROM Order WHERE)
Order.find("status = ?1 AND totalAmount > ?2", status, threshold).list();

// Named parameters (clearer for complex queries)
Order.find("status = :s AND createdAt > :since",
           Parameters.with("s", status).and("since", cutoff)).list();

// Full JPQL (use FROM to override auto-prefix)
Order.find("FROM Order o JOIN FETCH o.customer WHERE o.id = ?1", id).firstResult();

// Count
long pending = Order.count("status", OrderStatus.PENDING);

// Paged results
PanacheQuery<Order> query = Order.findAll(Sort.by("createdAt").descending());
List<Order> page1 = query.page(0, 20).list();
long total = query.count();

// Stream (auto-scrolling, lower memory for large result sets)
try (Stream<Order> stream = Order.streamAll()) {
    stream.filter(o -> ...).forEach(this::process);
}

// Sort
Order.findAll(Sort.by("status").and("createdAt", Sort.Direction.Descending)).list();

// Optional
Optional<Order> maybeOrder = Order.findByIdOptional(id);

// persist / delete
Order order = new Order();
order.persist();            // INSERT
order.status = SHIPPED;
// No explicit update needed — changes tracked by Hibernate within @Transactional

order.delete();             // DELETE
Order.deleteById(id);
Order.delete("status = ?1", OrderStatus.EXPIRED);
```

### Projections

```java
@RegisterForReflection
public record OrderSummary(Long id, OrderStatus status, BigDecimal totalAmount) {}

List<OrderSummary> summaries = Order.find("status", OrderStatus.PENDING)
        .project(OrderSummary.class).list();
```

`project(Class)` builds a constructor-based DTO projection. Use `@ProjectedConstructor` when the DTO has multiple constructors. Use `@ProjectedFieldName("fieldPath")` for nested or differently-named fields. Add `@RegisterForReflection` for native compilation.

### Locking

```java
Order locked = Order.findById(id, LockModeType.PESSIMISTIC_WRITE);
Order alsoLocked = Order.find("customer", customer)
        .withLock(LockModeType.PESSIMISTIC_WRITE).firstResult();
```

Lock queries must run inside a `@Transactional` method.

---

## Transaction management

```java
@ApplicationScoped
public class OrderService {

    @Inject OrderRepository orderRepo;
    @Inject InventoryService inventoryService;

    @Transactional                              // begins transaction, commits on return
    public Order placeOrder(PlaceOrderRequest req) {
        Order order = new Order();
        order.customer = customerRepo.findById(req.customerId())
            .orElseThrow(NotFoundException::new);
        order.status = OrderStatus.PENDING;
        order.lines = buildLines(req.items());

        inventoryService.reserve(req.items()); // also @Transactional — joins this tx

        orderRepo.persist(order);
        return order;
    }

    @Transactional(readOnly = true)            // read-only hint → better pool efficiency
    public Optional<Order> findById(Long id) {
        return orderRepo.findWithLines(id);
    }

    // Force a new transaction (e.g., for audit logs that must commit even on rollback)
    @Transactional(Transactional.TxType.REQUIRES_NEW)
    public void logEvent(String event) { ... }
}
```

Scoping: `REQUIRED` (default, joins or creates), `REQUIRES_NEW` (new tx, suspends outer),
`MANDATORY` (must exist), `NEVER` (must not exist), `NOT_SUPPORTED` (suspends),
`SUPPORTS` (uses if present).

### Early flush for failure detection

```java
@Transactional
void create(Order order) {
    try {
        order.persistAndFlush();
    } catch (PersistenceException e) {
        auditFailure(order);
        throw e;
    }
}
```

`persistAndFlush()` forces an immediate SQL write so constraint violations surface inside your try/catch rather than at commit time.

---

## Flyway migrations

### File naming convention

```
src/main/resources/db/migration/
├── V1__create_customers.sql
├── V2__create_orders.sql
├── V3__add_order_status_index.sql
├── V4__add_customer_email_unique.sql
└── R__refresh_order_summary_view.sql   # Repeatable migration (re-runs when changed)
```

Rules:
- `V{version}__{description}.sql` — versioned (runs once, in order)
- `R__{description}.sql` — repeatable (re-runs when checksum changes)
- Double underscore between version and description

### Example migration

```sql
-- V1__create_customers.sql
CREATE TABLE customers (
    id         BIGSERIAL PRIMARY KEY,
    name       VARCHAR(255)   NOT NULL,
    email      VARCHAR(255)   NOT NULL UNIQUE,
    created_at TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- V2__create_orders.sql
CREATE TABLE orders (
    id           BIGSERIAL PRIMARY KEY,
    customer_id  BIGINT         NOT NULL REFERENCES customers(id),
    status       VARCHAR(50)    NOT NULL DEFAULT 'PENDING',
    total_amount NUMERIC(10,2),
    created_at   TIMESTAMPTZ    NOT NULL DEFAULT now()
);
CREATE INDEX idx_orders_customer ON orders(customer_id);
```

### Flyway config properties

```properties
quarkus.flyway.migrate-at-start=true
quarkus.flyway.locations=db/migration
quarkus.flyway.baseline-on-migrate=true    # Required when adding Flyway to existing DB
quarkus.flyway.baseline-version=0          # Treat everything before V1 as baseline
quarkus.flyway.out-of-order=false          # Reject out-of-order migrations in prod
%dev.quarkus.flyway.clean-at-start=false   # Set true only when you want a full reset
```

### Hibernate-to-Flyway transition

Six-step handoff from `database.generation=drop-and-create` to Flyway:

1. Stabilize the first model with Hibernate schema generation.
2. Use Dev UI Flyway page to generate the initial migration from the current schema.
3. Review the generated `V1.0.0__*.sql` before committing.
4. Enable `quarkus.flyway.migrate-at-start=true`.
5. Set `quarkus.flyway.baseline-on-migrate=true` if adopting against an existing schema.
6. Switch production to `quarkus.hibernate-orm.schema-management.strategy=none` (or `validate`).

### Multi-datasource migrations

```text
src/main/resources/
  db/default/V1__init.sql
  db/users/V1__init.sql
  db/inventory/V1__init.sql
```

```properties
quarkus.flyway.locations=db/default
quarkus.flyway.users.locations=db/users
quarkus.flyway.inventory.locations=db/inventory
quarkus.flyway.migrate-at-start=true
quarkus.flyway.users.migrate-at-start=true
quarkus.flyway.inventory.migrate-at-start=true
```

Use `@FlywayDataSource("name")` for per-datasource `FlywayConfigurationCustomizer` injection.

### CI migration validation

```properties
%test.quarkus.flyway.migrate-at-start=true
%test.quarkus.flyway.validate-at-start=true
```

Verify: fresh schema creation, upgrade from a representative older version, no checksum drift.

---

## PostgreSQL-specific Hibernate mappings

```java
@Id @GeneratedValue
@Column(columnDefinition = "uuid DEFAULT gen_random_uuid()")
public UUID id;                                          // UUID primary key

@Column(columnDefinition = "jsonb") @JdbcTypeCode(SqlTypes.JSON)
public Map<String, Object> metadata;                     // JSONB column

@Column(columnDefinition = "text[]") @JdbcTypeCode(SqlTypes.ARRAY)
public String[] tags;                                    // Array type

@Enumerated(EnumType.STRING)
public OrderStatus status;                               // Enum as text

@Version public int version;                             // Optimistic locking
```

## N+1 queries — prevention

```java
// BAD: N+1
List<Order> orders = Order.listAll();
orders.forEach(o -> o.customer.name); // fires N extra queries

// GOOD: JOIN FETCH
List<Order> orders = Order.find("FROM Order o LEFT JOIN FETCH o.customer").list();

// GOOD: @EntityGraph
@NamedEntityGraph(name = "Order.withCustomerAndLines",
    attributeNodes = { @NamedAttributeNode("customer"), @NamedAttributeNode("lines") })
```

## Pagination helper (for REST responses)

```java
public record PagedResult<T>(List<T> data, long total, int page, int size) {

    public static <T> PagedResult<T> of(PanacheQuery<T> query, int page, int size) {
        long total = query.count();
        List<T> data = query.page(page, size).list();
        return new PagedResult<>(data, total, page, size);
    }
}
```

## Testing Panache code

**Active record** — add `io.quarkus:quarkus-panache-mock` in test scope:

```java
PanacheMock.mock(Order.class);
Mockito.when(Order.count()).thenReturn(23L);
assertEquals(23L, Order.count());
PanacheMock.verify(Order.class).count();
```

**Repository** — use `@InjectMock` from `quarkus-junit5-mockito`:

```java
@InjectMock
OrderRepository orderRepo;

Mockito.when(orderRepo.count()).thenReturn(23L);
assertEquals(23L, orderRepo.count());
Mockito.verify(orderRepo).count();
```

### Panache gotchas

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `persist()`, `delete()`, or `update()` silently does nothing | Write runs outside a transaction | Add `@Transactional` on the calling method |
| Data changed in memory but not yet in SQL | Hibernate flush is deferred until commit or query | Use `persistAndFlush()` only when early feedback is required |
| `streamAll()` throws or leaks resources | Stream used without a transaction or not closed | Wrap in `@Transactional` and use try-with-resources |
| Large table causes memory pressure | `listAll()` loads everything | Switch to `find()` with paging or a projection |
| Entity fails with multiple persistence units | A Panache entity belongs to only one unit | Split model per unit or drop to lower-level ORM |
| Queries scattered across styles | Active record and repository mixed carelessly | Pick one dominant style per feature |
| `project(Class)` picks wrong constructor | DTO has multiple constructors | Use a single constructor or annotate with `@ProjectedConstructor` |
| Nested projection value is null | Projection needs explicit path | Use `@ProjectedFieldName` for referenced fields |
| Projection fails in native mode | DTO not retained for reflection | Add `@RegisterForReflection` |
| Simplified query does something unexpected | Shorthand expansion differs from intended HQL | Use full HQL when the short form is ambiguous |
| Paging fails after using `range()` | Range and page state are mutually exclusive | Re-apply `page(...)` or stick with one style |

### Flyway gotchas

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Validation fails with checksum mismatch | An applied migration file was edited | Restore original file; use `repair()` only as deliberate recovery |
| Team databases diverge after rebase | Migration files renamed, deleted, or reordered | Treat applied migrations as append-only |
| Flyway marks schema as initialized but objects are missing | `baseline-on-migrate` on wrong DB or version | Use baseline only for trusted existing schemas with explicit version |
| First migration never runs on legacy database | Baseline created history without matching actual schema | Compare real schema to intended baseline before enabling |
| Local dev keeps wiping data | `%dev.quarkus.flyway.clean-at-start=true` is active | Limit `clean-at-start` to disposable environments |
| Cleanup blocked unexpectedly | `clean-disabled=true` or missing DB permissions | Reserve clean for dev/test only |
| Flyway does not run for reactive application | Only reactive client is configured | Add JDBC datasource and driver — Flyway uses JDBC internally |
| Named datasource migrations hit wrong schema | Flyway configured on default instead of named DS | Use `quarkus.flyway.<name>.*` keys and `@FlywayDataSource("name")` |
