# PostgreSQL, Panache ORM & Flyway Reference

## Datasource configuration

### application.properties — full example

```properties
# Dev Mode: DevServices starts a PostgreSQL container automatically.
# Override only what you need to customise:
quarkus.datasource.devservices.image-name=postgres:16-alpine
quarkus.datasource.devservices.reuse=true
quarkus.datasource.devservices.port=15432

# Prod datasource (values come from environment or .env)
%prod.quarkus.datasource.db-kind=postgresql
%prod.quarkus.datasource.username=${DB_USER}
%prod.quarkus.datasource.password=${DB_PASSWORD}
%prod.quarkus.datasource.jdbc.url=jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME}

# Connection pool tuning (Agroal)
%prod.quarkus.datasource.jdbc.min-size=5
%prod.quarkus.datasource.jdbc.max-size=20
%prod.quarkus.datasource.jdbc.acquisition-timeout=30S
%prod.quarkus.datasource.jdbc.background-validation-interval=2M

# Hibernate
quarkus.hibernate-orm.dialect=org.hibernate.dialect.PostgreSQLDialect
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

**Active Record**: Query methods live on the entity class. Best for simple CRUD with
small domain models where the entity IS the aggregate root.

**Repository**: Query methods live in a separate class injected as a CDI bean. Preferred
when:
- The entity has complex business logic
- You need to mock the data layer in tests
- Multiple aggregates share query patterns

You can mix and match: use Active Record for simple entities, Repository for complex ones.

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

    public static Optional<Order> findByIdOptional(Long id) {
        return findByIdOptional(id);   // inherited; alias for clarity
    }

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

Transaction scoping rules:
- `REQUIRED` (default) — joins existing or creates new
- `REQUIRES_NEW` — always creates new, suspends outer
- `MANDATORY` — must exist, throws if none
- `NEVER` — must not exist, throws if one exists
- `NOT_SUPPORTED` — suspends any active transaction
- `SUPPORTS` — uses existing if present, otherwise non-transactional

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

### Example migrations

```sql
-- V1__create_customers.sql
CREATE TABLE customers (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(255)        NOT NULL,
    email       VARCHAR(255)        NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ         NOT NULL DEFAULT now()
);

-- V2__create_orders.sql
CREATE TABLE orders (
    id           BIGSERIAL PRIMARY KEY,
    customer_id  BIGINT              NOT NULL REFERENCES customers(id),
    status       VARCHAR(50)         NOT NULL DEFAULT 'PENDING',
    total_amount NUMERIC(10, 2),
    created_at   TIMESTAMPTZ         NOT NULL DEFAULT now()
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status   ON orders(status);

-- V3__add_order_lines.sql
CREATE TABLE order_lines (
    id          BIGSERIAL PRIMARY KEY,
    order_id    BIGINT         NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  BIGINT         NOT NULL,
    quantity    INT            NOT NULL CHECK (quantity > 0),
    unit_price  NUMERIC(10,2)  NOT NULL
);
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

---

## PostgreSQL-specific Hibernate mappings

```java
// UUID primary key
@Id
@GeneratedValue
@Column(columnDefinition = "uuid DEFAULT gen_random_uuid()")
public UUID id;

// JSONB column (requires hibernate-types or Hibernate 6 built-in)
@Column(columnDefinition = "jsonb")
@JdbcTypeCode(SqlTypes.JSON)
public Map<String, Object> metadata;

// Array type
@Column(columnDefinition = "text[]")
@JdbcTypeCode(SqlTypes.ARRAY)
public String[] tags;

// Enum stored as text
@Enumerated(EnumType.STRING)
@Column(columnDefinition = "varchar(50)")
public OrderStatus status;

// Optimistic locking
@Version
public int version;
```

## N+1 queries — prevention

```java
// BAD: N+1 — loads orders then fires a query per order for customer
List<Order> orders = Order.listAll();
orders.forEach(o -> System.out.println(o.customer.name)); // N queries

// GOOD: JOIN FETCH in one query
List<Order> orders = Order.find(
    "FROM Order o LEFT JOIN FETCH o.customer"
).list();

// GOOD: Use @EntityGraph for specific use cases
@NamedEntityGraph(name = "Order.withCustomerAndLines",
    attributeNodes = {
        @NamedAttributeNode("customer"),
        @NamedAttributeNode("lines")
    })
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
