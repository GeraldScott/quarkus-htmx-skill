# Advanced ORM Reference

## When to use this reference

Consult this file when you need to work outside Panache -- injecting `EntityManager` or `Session` directly, configuring multiple persistence units, implementing multitenancy, tuning second-level cache, or wiring Hibernate extension points such as interceptors and statement inspectors.

For Panache-based active record or repository patterns, see the standard ORM reference instead.

---

## Plain Hibernate ORM (non-Panache)

### EntityManager and Session injection

Add the Hibernate ORM extension and a JDBC driver:

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

Quarkus creates the ORM setup from the datasource plus the extension; `persistence.xml` is usually unnecessary.

Inject `EntityManager` (JPA standard) or `Session` (Hibernate-native):

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

### Basic CRUD service

```java
import java.util.List;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

@ApplicationScoped
public class FruitService {
    @Inject
    EntityManager em;

    public List<Fruit> list() {
        return em.createQuery("select f from Fruit f order by f.name", Fruit.class)
            .getResultList();
    }

    public Fruit find(long id) {
        return em.find(Fruit.class, id);
    }

    @Transactional
    public Fruit create(String name) {
        Fruit fruit = new Fruit();
        fruit.name = name;
        em.persist(fruit);
        return fruit;
    }

    @Transactional
    public void delete(long id) {
        Fruit fruit = em.find(Fruit.class, id);
        if (fruit != null) {
            em.remove(fruit);
        }
    }
}
```

Keep write methods transactional; simple reads can stay non-transactional unless consistency rules require otherwise.

### Dev mode schema strategies

```properties
# Fast rebuild with fixtures
%dev.quarkus.hibernate-orm.schema-management.strategy=drop-and-create
%dev.quarkus.hibernate-orm.sql-load-script=import.sql

# Work against real data
%dev-with-data.quarkus.hibernate-orm.schema-management.strategy=update
%dev-with-data.quarkus.hibernate-orm.sql-load-script=no-file

# Production: never mutate schema
%prod.quarkus.hibernate-orm.schema-management.strategy=none
%prod.quarkus.hibernate-orm.sql-load-script=no-file
```

Place `import.sql` in `src/main/resources/`. Every statement must end with a semicolon. Quarkus loads it by default in `dev` and `test` profiles when present.

When early development settles down, hand off schema management to Flyway: generate an initial migration, then set `schema-management.strategy=none`.

---

## Multiple persistence units

### Named units and package attachment

Bind named persistence units to their own datasources and assign entity packages:

```properties
quarkus.datasource."users".db-kind=postgresql
quarkus.datasource."inventory".db-kind=postgresql

quarkus.hibernate-orm."users".datasource=users
quarkus.hibernate-orm."users".packages=org.acme.users,org.acme.shared

quarkus.hibernate-orm."inventory".datasource=inventory
quarkus.hibernate-orm."inventory".packages=org.acme.inventory
```

Inject with the `@PersistenceUnit` qualifier:

```java
@Inject @PersistenceUnit("users") EntityManager usersEm;
@Inject @PersistenceUnit("inventory") EntityManager inventoryEm;
```

The same qualifier works for `Session`, `SessionFactory`, `EntityManagerFactory`, `CriteriaBuilder`, `Metamodel`, and cache entry points.

Alternative: package-level attachment annotation instead of config:

```java
@io.quarkus.hibernate.orm.PersistenceUnit("users")
package org.acme.user;
```

Do not mix `packages` config and package-level `@PersistenceUnit`. Embeddables, mapped superclasses, and shared model packages must follow the same unit split.

### Runtime activation

Predeclare multiple backends and activate exactly one at runtime:

```properties
quarkus.hibernate-orm."pg".packages=org.acme.model.shared
quarkus.hibernate-orm."pg".datasource=pg
quarkus.hibernate-orm."pg".active=false
quarkus.datasource."pg".active=false

quarkus.hibernate-orm."oracle".packages=org.acme.model.shared
quarkus.hibernate-orm."oracle".datasource=oracle
quarkus.hibernate-orm."oracle".active=false
quarkus.datasource."oracle".active=false

%pg.quarkus.hibernate-orm."pg".active=true
%pg.quarkus.datasource."pg".active=true

%oracle.quarkus.hibernate-orm."oracle".active=true
%oracle.quarkus.datasource."oracle".active=true
```

Use dynamic lookup for units that may be inactive -- avoid direct injection:

```java
@Inject @Any InjectableInstance<SessionFactory> sessionFactories;

SessionFactory get() {
    return sessionFactories.getActive();
}
```

To expose one unqualified `Session` from the active unit, use a CDI producer:

```java
@ApplicationScoped
class SessionProducer {
    @Inject @PersistenceUnit("pg") InjectableInstance<Session> pg;
    @Inject @PersistenceUnit("oracle") InjectableInstance<Session> oracle;

    @Produces
    @ApplicationScoped
    Session session() {
        if (pg.getHandle().getBean().isActive()) return pg.get();
        if (oracle.getHandle().getBean().isActive()) return oracle.get();
        throw new IllegalStateException("No active persistence unit");
    }
}
```

---

## Multitenancy

### Schema-based multitenancy with Flyway

Tenants share one database and isolate by schema. Provision schemas through Flyway, not Hibernate schema generation:

```properties
quarkus.hibernate-orm.multitenant=SCHEMA
quarkus.hibernate-orm.schema-management.strategy=none
quarkus.flyway.schemas=base,mycompany
quarkus.flyway.locations=classpath:schema
quarkus.flyway.migrate-at-start=true
```

```java
@RequestScoped
@PersistenceUnitExtension
class TenantFromPath implements TenantResolver {
    @Override public String getDefaultTenantId() { return "base"; }
    @Override public String resolveTenantId() { return "mycompany"; }
}
```

### Database-based multitenancy

Each tenant gets a dedicated datasource. The list is fixed at build time:

```properties
quarkus.hibernate-orm.multitenant=DATABASE
quarkus.hibernate-orm.datasource=base
quarkus.hibernate-orm.schema-management.strategy=none

quarkus.datasource.base.db-kind=postgresql
quarkus.datasource.mycompany.db-kind=postgresql
```

```java
@RequestScoped
@PersistenceUnitExtension
class TenantFromHeader implements TenantResolver {
    @Override public String getDefaultTenantId() { return "base"; }
    @Override public String resolveTenantId() { return "mycompany"; }
}
```

Returned tenant IDs must match datasource names. Keep the same DB vendor/version family across all tenant datasources, or split into separate persistence units.

Discriminator multitenancy (`DISCRIMINATOR`) uses row-level isolation with `@TenantId` on entities -- no separate schemas or databases needed.

### Tenant resolution

Implement `TenantResolver` and annotate with `@PersistenceUnitExtension`:

```java
@RequestScoped
@PersistenceUnitExtension
class RequestTenantResolver implements TenantResolver {
    @Override
    public String getDefaultTenantId() {
        return "base";
    }

    @Override
    public String resolveTenantId() {
        return "acme";
    }
}
```

Use `CurrentVertxRequest` rather than directly injecting `RoutingContext` if resolution must also work outside HTTP request handling (jobs, async code).

For dynamic tenant JDBC details from a registry or onboarding database:

```java
@ApplicationScoped
@PersistenceUnitExtension
class DynamicConnections implements TenantConnectionResolver {
    @Override
    public ConnectionProvider resolve(String tenantId) {
        return buildProviderFromRegistry(tenantId);
    }
}
```

Choose programmatic resolution only when config-defined datasources are too static.

---

## Extension points (`@PersistenceUnitExtension`)

Bind advanced Hibernate components to a specific persistence unit:

```java
@PersistenceUnitExtension          // default unit
class DefaultUnitExtension { }

@PersistenceUnitExtension("users") // named unit
class UsersUnitExtension { }
```

Supported extension bean types:

- `org.hibernate.Interceptor` -- entity lifecycle hooks
- `org.hibernate.resource.jdbc.spi.StatementInspector` -- SQL tagging/tracing
- `org.hibernate.type.format.FormatMapper` -- JSON/XML format mappers
- `io.quarkus.hibernate.orm.runtime.tenant.TenantResolver`
- `io.quarkus.hibernate.orm.runtime.tenant.TenantConnectionResolver`
- `org.hibernate.boot.model.FunctionContributor`
- `org.hibernate.boot.model.TypeContributor`

Interceptor and statement inspector example:

```java
@PersistenceUnitExtension
class AuditInterceptor implements Interceptor, Serializable {
}

@PersistenceUnitExtension("users")
class TraceInspector implements StatementInspector {
    @Override
    public String inspect(String sql) {
        return sql + " /* users-pu */";
    }
}
```

`@ApplicationScoped` interceptors must be thread-safe. Use `@Dependent` only when you need one instance per entity manager.

For JSON format mappers, annotate with `@JsonFormat`; for XML, use `@XmlFormat`. Each persistence unit supports at most one of each.

---

## Second-level cache, Envers, metrics

### Second-level cache

```java
@Entity
@Cacheable
class Country {
    @OneToMany
    @org.hibernate.annotations.Cache(usage = CacheConcurrencyStrategy.READ_ONLY)
    List<City> cities;
}
```

Enable query cache via hint:

```java
query.setHint("org.hibernate.cacheable", Boolean.TRUE);
```

Cache region tuning:

```properties
quarkus.hibernate-orm.cache."org.acme.Country".memory.object-count=2000
quarkus.hibernate-orm.cache."org.acme.Country".expiration.max-idle=30M
quarkus.hibernate-orm.cache."default-query-results-region".expiration.max-idle=5M
```

Region names containing dots must be quoted. Entity regions use the FQCN; collection regions use `OwnerEntity#collectionField`.

The Quarkus second-level cache is local, not cluster-synchronized. Cache only immutable or stale-tolerant data.

### Envers, Spatial, metrics

- Add `io.quarkus:quarkus-hibernate-envers` for auditing.
- Add `org.hibernate.orm:hibernate-spatial` for spatial support.
- Enable ORM metrics with a Micrometer extension:

```properties
quarkus.hibernate-orm.metrics.enabled=true
```

JMX statistics are unavailable in native builds -- use Micrometer instead.

---

## Offline startup

```properties
quarkus.hibernate-orm.database.start-offline=true
quarkus.hibernate-orm.schema-management.strategy=none
```

With offline startup:

- Hibernate ORM skips connecting to the database during boot.
- Version checks against the live database do not run at startup.
- Automatic schema creation is not available; the schema must already exist.
- Run Flyway or another external migration tool before the app serves traffic.
- Set explicit dialect/version options when auto-detection cannot run.

---

## Configuration reference

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.hibernate-orm."name".datasource` | required | A named persistence unit must bind to a datasource |
| `quarkus.hibernate-orm."name".packages` | - | Entities attach to a named unit by package |
| `quarkus.hibernate-orm."name".active` | auto | A unit should be runtime-selectable or disabled by default |
| `quarkus.hibernate-orm.persistence-xml.ignore` | `false` | A transitive `persistence.xml` should be ignored |
| `quarkus.hibernate-orm.mapping-files` | auto-detect `META-INF/orm.xml` | XML mappings loaded explicitly or disabled with `no-file` |
| `quarkus.hibernate-orm.multitenant` | `NONE` | Unit uses `SCHEMA`, `DATABASE`, or `DISCRIMINATOR` multitenancy |
| `quarkus.hibernate-orm.datasource` | default datasource | Database multitenancy needs one datasource as dialect reference |
| `quarkus.hibernate-orm.database.start-offline` | `false` | App startup must not connect to the database |
| `quarkus.hibernate-orm.cache."region".memory.object-count` | `10000` | A cache region needs a tighter or larger entry bound |
| `quarkus.hibernate-orm.cache."region".expiration.max-idle` | `100S` | Cached data should expire sooner or stay warm longer |
| `quarkus.hibernate-orm.metrics.enabled` | `false` | Micrometer should expose Hibernate ORM metrics |
| `quarkus.hibernate-orm.request-scoped.enabled` | `true` | Disable read-only request-scoped session access outside transactions |
| `quarkus.hibernate-orm.schema-management.strategy` | varies | Control schema generation: `drop-and-create`, `update`, `validate`, `none` |
| `quarkus.hibernate-orm.sql-load-script` | auto | Seed data script path, or `no-file` to disable |

Notes:
- Quote named unit names in dotted property syntax.
- For named units, `datasource` is mandatory.
- Multiple persistence units can point at the same datasource.
- Do not mix `persistence.xml` with `quarkus.hibernate-orm.*` config.

---

## Gotchas

### Transactions and write paths

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `persist`, `remove`, or dirty updates fail or do not commit | Write method is not inside a transaction | Annotate the method with `@Transactional` |
| ORM behavior feels inconsistent across layers | Transaction boundary is buried deep or split awkwardly | Place transactional boundaries at clear entry methods (REST, service) |

### Persistence unit activation

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Startup fails after setting `active=false` on a unit | Code statically injects beans from that inactive unit | Replace direct injection with `InjectableInstance<T>` or a producer |
| Runtime selection works for datasource but not ORM | Datasource and persistence unit `active` flags are out of sync | Activate or deactivate both together |
| Another extension crashes startup when a unit is disabled | An extension consuming that unit remains enabled | Deactivate or reconfigure the dependent extension |

### Multiple persistence units

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Entities do not attach to the expected unit | `packages` config and `@PersistenceUnit` annotation are mixed | Pick one attachment strategy; prefer `packages` in config |
| Shared embeddables behave inconsistently | Dependent model types not attached to the same unit | Keep related model packages attached consistently |
| Panache model cannot be reused across multiple units | Panache entities are limited to one persistence unit | Use traditional Hibernate ORM entities for multi-unit reuse |

### Multitenancy

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Tenant schema is missing tables | Hibernate schema generation is unsuitable for multitenancy | Set `schema-management.strategy=none`; provision with Flyway |
| Database multitenancy behaves unpredictably | Tenant datasources differ in vendor/version | Keep same DB vendor/version or split into separate units |
| Tenant resolution works in REST but fails in jobs/async | Resolver depends on `RoutingContext` directly | Use `CurrentVertxRequest` or support non-HTTP paths |

### Caching and XML configuration

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Cached data goes stale across pods | Second-level cache is local, not clustered | Cache only immutable or stale-tolerant data |
| Cache tuning property does not apply | Region name with dots was not quoted | Quote region names: `cache."org.acme.Country".*` |
| Startup fails with both `persistence.xml` and config | Quarkus does not support mixing the two | Use one approach; set `persistence-xml.ignore=true` if needed |
| Unexpected mappings from `META-INF/orm.xml` | Quarkus auto-loads that file | Set `mapping-files=no-file` or manage explicitly |

### Schema and seed data

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Local dev data disappears after reload | `drop-and-create` rebuilds schema each startup | Use only for disposable data, or switch to `update`/`none` |
| Production schema changes unexpectedly | `drop-and-create` or `update` leaked into prod | Set `%prod.quarkus.hibernate-orm.schema-management.strategy=none` |
| `import.sql` partially loads or fails | Statements missing semicolons | Terminate every SQL statement with `;` |
| Seed data does not load in production | Default is `no-file` outside `dev`/`test` | Set property explicitly if production loading is intentional |

### Native image and Quarkus limits

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| JMX statistics disappear in native builds | JMX is disabled in GraalVM native | Use Micrometer metrics instead |
| `ThreadLocalSessionContext` does not work | Not implemented in Quarkus | Use CDI injection or programmatic CDI lookup |
| JNDI-based ORM wiring fails | Quarkus disables JNDI for Hibernate ORM | Inject datasources and transaction components directly |
