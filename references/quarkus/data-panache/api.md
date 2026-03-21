# Quarkus Data Panache Reference

Use this module when the task is about Quarkus Panache on top of Hibernate ORM: `PanacheEntity`, `PanacheRepository`, active record, repository-style data access, simplified HQL, paging, projections, or Panache-specific mocking.

## Overview

Panache reduces common ORM boilerplate while still using Hibernate ORM underneath.

- Use `PanacheEntity` for the active record style with built-in `id` and static query helpers.
- Use `PanacheEntityBase` when you want Panache helpers but need your own ID mapping.
- Use `PanacheRepository<T>` or `PanacheRepositoryBase<T, ID>` when you prefer injected repositories over static entity methods.
- Use Panache query helpers for common CRUD, simplified HQL fragments, sorting, paging, projections, and locking.

## When Panache is a good fit

- Most persistence work is straightforward CRUD or filtered lookup.
- You want less repository and DAO boilerplate.
- You want query helpers close to the entity or repository code.
- You still want full Hibernate ORM behavior when needed.

## Scope boundaries

- This module covers the Panache programming model and Panache-specific APIs.
- It does not re-explain basic JPA mapping, datasource setup, or advanced persistence unit design in depth.
- Panache still depends on normal Hibernate ORM concepts: entities, transactions, flush, locking, and HQL.

---

## Extension entry point

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-hibernate-orm-panache</artifactId>
</dependency>
```

## Active record with `PanacheEntity`

```java
import jakarta.persistence.Entity;
import io.quarkus.hibernate.orm.panache.PanacheEntity;

@Entity
public class Person extends PanacheEntity {
    public String name;
    public Status status;
}
```

`PanacheEntity` gives you a generated `Long id` plus static helpers like `listAll()`, `findById()`, `count()`, and `delete()`.

## Active record with custom IDs: `PanacheEntityBase`

```java
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import io.quarkus.hibernate.orm.panache.PanacheEntityBase;

@Entity
public class Person extends PanacheEntityBase {
    @Id
    @GeneratedValue
    public Integer id;

    public String name;
}
```

## Repository pattern with `PanacheRepository`

```java
import jakarta.enterprise.context.ApplicationScoped;
import io.quarkus.hibernate.orm.panache.PanacheRepository;

@ApplicationScoped
public class PersonRepository implements PanacheRepository<Person> {
}
```

## Repository pattern with custom IDs: `PanacheRepositoryBase`

```java
import jakarta.enterprise.context.ApplicationScoped;
import io.quarkus.hibernate.orm.panache.PanacheRepositoryBase;

@ApplicationScoped
public class PersonRepository implements PanacheRepositoryBase<Person, Integer> {
}
```

## Common CRUD helpers

```java
Person p = new Person();
p.name = "Stef";
p.status = Status.Alive;

p.persist();
boolean managed = p.isPersistent();

Person one = Person.findById(1L);
List<Person> all = Person.listAll();
List<Person> alive = Person.list("status", Status.Alive);

long total = Person.count();
long aliveCount = Person.count("status", Status.Alive);

boolean deleted = Person.deleteById(1L);
long removed = Person.delete("status", Status.Deceased);
long updated = Person.update("status = ?1 where name = ?2", Status.Alive, "stef");
```

## Add custom query helpers

```java
@Entity
public class Person extends PanacheEntity {
    public String name;
    public Status status;

    public static Person findByName(String name) {
        return find("name", name).firstResult();
    }

    public static List<Person> findAlive() {
        return list("status", Status.Alive);
    }
}
```

## Simplified queries

```java
Person.find("name", name).firstResult();
Person.list("status", Status.Alive);
Person.list("order by name");
Person.find("name = ?1 and status = ?2", name, Status.Alive).list();
Person.find("name = :name and status = :status", Map.of("name", name, "status", Status.Alive)).list();
```

Panache expands short forms into normal HQL. Full HQL still works when needed.

## Paging and range queries

```java
import io.quarkus.hibernate.orm.panache.PanacheQuery;
import io.quarkus.panache.common.Page;

PanacheQuery<Person> query = Person.find("status", Status.Alive).page(Page.ofSize(25));

List<Person> first = query.list();
List<Person> second = query.nextPage().list();
int pages = query.pageCount();
long count = query.count();
```

```java
List<Person> firstRange = Person.find("status", Status.Alive)
        .range(0, 24)
        .list();
```

Do not mix `range()` and page-navigation methods on the same query state.

## Sorting

```java
import io.quarkus.panache.common.Sort;

List<Person> people = Person.list(Sort.by("name").and("birth"));
List<Person> alive = Person.list("status", Sort.by("name"), Status.Alive);
```

## Named queries

```java
import jakarta.persistence.Entity;
import jakarta.persistence.NamedQuery;

@Entity
@NamedQuery(name = "Person.byName", query = "from Person where name = ?1")
public class Person extends PanacheEntity {
    public String name;
}

Person p = Person.find("#Person.byName", "stef").firstResult();
```

Prefix the query name with `#` for `find`, `count`, `update`, or `delete`.

## Projections

```java
import io.quarkus.runtime.annotations.RegisterForReflection;

@RegisterForReflection
public record PersonName(String name) {
}

List<PersonName> names = Person.find("status", Status.Alive)
        .project(PersonName.class)
        .list();
```

`project(Class)` builds a DTO projection from constructor parameters. Use `@ProjectedConstructor` or `@ProjectedFieldName` when constructor selection or nested field mapping is ambiguous.

## Flush helpers

```java
@Transactional
void create(Person p) {
    p.persistAndFlush();
}
```

Use `flush()` or `persistAndFlush()` only when you need early database feedback inside the transaction.

## Locking

```java
import jakarta.persistence.LockModeType;

Person locked = Person.findById(id, LockModeType.PESSIMISTIC_WRITE);

Person alsoLocked = Person.find("name", name)
        .withLock(LockModeType.PESSIMISTIC_WRITE)
        .firstResult();
```

Lock queries must run inside a transaction.

## Streams

```java
try (Stream<Person> stream = Person.streamAll()) {
    return stream.map(p -> p.name).toList();
}
```

`stream*` methods require a transaction and should be closed.

## One persistence unit per Panache entity

A Panache entity can belong to only one persistence unit. Panache resolves the right `EntityManager` for that entity automatically.

---

## Configuration Reference

### Key point

Panache does not introduce a separate configuration model for normal runtime use. It uses the same datasource and Hibernate ORM settings as standard Quarkus ORM.

### High-value properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.datasource.db-kind` | - | Selecting the database family |
| `quarkus.datasource.jdbc.url` | - | Pointing the ORM layer at the database |
| `quarkus.datasource.username` | - | Providing DB credentials |
| `quarkus.datasource.password` | - | Providing DB credentials |
| `quarkus.hibernate-orm.schema-management.strategy` | `none` | Creating, updating, or recreating schema during development/tests |
| `quarkus.hibernate-orm.log.sql` | `false` | Inspecting generated SQL from Panache operations |
| `quarkus.hibernate-orm.database.generation.create-schemas` | `false` | Auto-creating database schemas when supported |
| `quarkus.hibernate-orm.sql-load-script` | `import.sql` in dev/test | Loading seed data that Panache queries can use immediately |

### Minimal setup

```properties
quarkus.datasource.db-kind=postgresql
quarkus.datasource.jdbc.url=jdbc:postgresql://localhost:5432/app
quarkus.datasource.username=app
quarkus.datasource.password=app

quarkus.hibernate-orm.schema-management.strategy=update
```

### Helpful development settings

```properties
quarkus.hibernate-orm.log.sql=true
quarkus.hibernate-orm.schema-management.strategy=drop-and-create
quarkus.hibernate-orm.sql-load-script=import.sql
```

Use `drop-and-create` only for disposable environments.

### Configuration guidance

- If a Panache query fails, check datasource connectivity and base Hibernate ORM configuration first.
- If projection or query behavior looks wrong, enable SQL logging before debugging Panache code.
- If you seed demo data for Panache CRUD examples, keep it in `import.sql` or your normal migration workflow.
