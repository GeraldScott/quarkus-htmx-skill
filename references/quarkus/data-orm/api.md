# Quarkus Data ORM Reference

Use this module for standard Quarkus Hibernate ORM work: entity mapping, `EntityManager` or `Session` usage, transactions, schema generation basics, and database dialect/version configuration.

## Overview

This module covers plain Hibernate ORM with Quarkus configuration in `application.properties`.

- Use it when the task is about `@Entity`, `@Id`, `EntityManager`, `Session`, `@Transactional`, or schema-management defaults.
- Prefer this module when the question is Quarkus + JPA and there is no explicit Panache, Flyway-first, or advanced persistence-unit concern.
- Quarkus usually auto-configures the persistence layer from the datasource, so explicit ORM settings are often minimal.

## What This Covers

- Adding `quarkus-hibernate-orm` with a JDBC driver.
- Basic entity mapping and persistence operations.
- Transaction boundaries for reads and writes.
- Dev/test/prod schema-management choices.
- Dialect and database version guidance.
- `import.sql` and SQL seed loading basics.

## What This Does Not Cover

- Panache APIs and active-record/repository helpers.
- Flyway-led schema migration workflows.
- Multiple persistence units, multitenancy, caching, XML mapping, or SPI extensions.

---

## Extension entry point

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-hibernate-orm</artifactId>
</dependency>

<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-jdbc-postgresql</artifactId>
</dependency>
```

Quarkus creates the ORM setup from the datasource plus the Hibernate ORM extension; `persistence.xml` is usually unnecessary.

## Minimal entity

```java
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;

@Entity
public class Fruit {
    @Id
    @GeneratedValue
    public Long id;

    public String name;
}
```

Use normal Jakarta Persistence annotations; Quarkus handles build-time enhancement automatically.

## Inject `EntityManager`

```java
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

@ApplicationScoped
public class FruitService {
    @Inject
    EntityManager em;

    @Transactional
    public void create(String name) {
        Fruit fruit = new Fruit();
        fruit.name = name;
        em.persist(fruit);
    }
}
```

For writes, make the CDI method a transaction boundary with `@Transactional`.

## Inject `Session`

```java
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.hibernate.Session;

@ApplicationScoped
public class InventoryService {
    @Inject
    Session session;

    @Transactional
    public void rename(Long id, String name) {
        Fruit fruit = session.find(Fruit.class, id);
        fruit.name = name;
    }
}
```

Use `Session` when you want Hibernate-native APIs; otherwise `EntityManager` is fine.

## Transaction boundaries

```java
import jakarta.transaction.Transactional;

@Transactional
public void updateStock(Long id, int stock) {
    Fruit fruit = em.find(Fruit.class, id);
    fruit.stock = stock;
}
```

- Writes should run inside `@Transactional` methods.
- A transaction boundary is usually best at the application edge: REST resource, messaging consumer, or service entry method.
- Managed entities flush on commit.

## Basic persistence operations

```java
Fruit fruit = new Fruit();
fruit.name = "Apple";
em.persist(fruit);

Fruit byId = em.find(Fruit.class, fruit.id);

em.remove(byId);
```

## Basic query examples

```java
List<Fruit> fruits = em.createQuery(
        "select f from Fruit f order by f.name", Fruit.class)
    .getResultList();

Fruit fruit = em.createQuery(
        "select f from Fruit f where f.name = :name", Fruit.class)
    .setParameter("name", "Apple")
    .getSingleResult();
```

Typed queries keep the result shape explicit and are usually easier to maintain.

## Seed data with `import.sql`

Place `import.sql` in `src/main/resources/`:

```sql
insert into Fruit(id, name) values (1, 'Apple');
insert into Fruit(id, name) values (2, 'Pear');
```

- In `dev` and `test`, Quarkus loads `/import.sql` by default when present.
- Every statement must end with a semicolon.
- Override the file with `quarkus.hibernate-orm.sql-load-script`.
- Disable SQL loading with `quarkus.hibernate-orm.sql-load-script=no-file`.

---

## Configuration Reference

### High-value properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.hibernate-orm.schema-management.strategy` | environment-dependent | You need Quarkus/Hibernate to create, update, validate, or ignore schema changes |
| `quarkus.hibernate-orm.sql-load-script` | `import.sql` in `dev`/`test`, `no-file` otherwise | Seed SQL should load automatically or be disabled explicitly |
| `quarkus.datasource.db-version` | minimum supported version | Hibernate should target the actual database version for better SQL |
| `quarkus.hibernate-orm.dialect` | inferred from datasource when possible | You use an unsupported database or need a non-default dialect |
| `quarkus.hibernate-orm.database.version-check.enabled` | `true` | Startup should skip version validation because DB reachability is limited |
| `quarkus.hibernate-orm.persistence-xml.ignore` | `false` | A stray `persistence.xml` is on the classpath and Quarkus config should win |

### Schema management strategy

```properties
%dev.quarkus.hibernate-orm.schema-management.strategy=drop-and-create
%test.quarkus.hibernate-orm.schema-management.strategy=drop-and-create
%prod.quarkus.hibernate-orm.schema-management.strategy=none
```

Common values:

- `drop-and-create` - rebuild schema on startup; best for clean dev loops.
- `update` - best-effort schema update; acceptable for development, not production.
- `validate` - verify schema matches mappings without changing it.
- `none` - disable schema generation; safest production baseline.

### SQL seed loading

```properties
%dev.quarkus.hibernate-orm.sql-load-script=import.sql
%test.quarkus.hibernate-orm.sql-load-script=import.sql
%prod.quarkus.hibernate-orm.sql-load-script=no-file
```

Quarkus defaults to loading `/import.sql` only in `dev` and `test`; production defaults intentionally avoid accidental data resets.

### Database version

```properties
quarkus.datasource.db-kind=postgresql
quarkus.datasource.db-version=16.3
```

Set `quarkus.datasource.db-version` as high as possible without exceeding any real target database version. This lets Hibernate generate more efficient SQL and catches mismatches at startup.

### Explicit dialect only when needed

```properties
quarkus.datasource.db-kind=postgresql
quarkus.hibernate-orm.dialect=Cockroach
quarkus.datasource.db-version=25.1
```

For mainstream supported databases, let Quarkus infer the dialect. Set `quarkus.hibernate-orm.dialect` only for unsupported databases or intentional overrides.

### Important default behavior

- Dialect is usually inferred from the datasource.
- ORM configuration is usually done in `application.properties`, not `persistence.xml`.
- Mixing `persistence.xml` with `quarkus.hibernate-orm.*` configuration causes a startup failure.

Keep the explicit configuration surface small: set schema strategy, SQL loading, and database version first, then add dialect overrides only for real edge cases.

For production, treat `%prod.quarkus.hibernate-orm.schema-management.strategy=none` and `%prod.quarkus.hibernate-orm.sql-load-script=no-file` as the safe default starting point.
