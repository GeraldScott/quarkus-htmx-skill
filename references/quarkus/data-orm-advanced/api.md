# Advanced ORM Reference

Use this module when Hibernate ORM work in Quarkus goes beyond normal entity mapping and transactions.

## Overview

This module is intentionally opt-in and advanced.

- Focus on architecture choices such as multiple persistence units, multitenancy, runtime activation, and custom ORM extension points.
- Cover migration-oriented features such as `persistence.xml` and XML mappings.
- Highlight operational concerns such as offline startup, cache tuning, metrics, and Quarkus-specific limitations.

## Use This Module For

- `@PersistenceUnit` injection, package attachment, and named persistence units
- `@PersistenceUnitExtension` customizations such as interceptors, statement inspectors, function/type contributors, and format mappers
- Runtime activation or deactivation of persistence units and datasource switching
- Schema, database, or discriminator multitenancy
- `persistence.xml`, `orm.xml`, or `hbm.xml` integration
- Offline startup when the database is not reachable during application boot
- Second-level cache, Envers, Spatial, metrics, Jakarta Data, and static metamodel setup

## Do Not Start Here For

- Basic entity mapping, transactions, and single-datasource ORM setup
- Panache-first CRUD usage
- Migration tooling except where it is required by multitenancy or offline startup

---

## Advanced ORM API

### `@PersistenceUnit` injection

```java
@Inject
@io.quarkus.hibernate.orm.PersistenceUnit("users")
EntityManager em;
```

The same qualifier works for `Session`, `SessionFactory`, `EntityManagerFactory`, `CriteriaBuilder`, `Metamodel`, and cache entry points.

### Package attachment for named units

```properties
quarkus.hibernate-orm."users".datasource=users
quarkus.hibernate-orm."users".packages=org.acme.user,org.acme.shared
```

Alternative package-level attachment:

```java
@io.quarkus.hibernate.orm.PersistenceUnit("users")
package org.acme.user;
```

Do not mix `packages` and package-level `@PersistenceUnit`.

### Dynamic lookup for inactive units

```java
@Inject
@Any
InjectableInstance<Session> sessions;

Session activeSession() {
    return sessions.getActive();
}
```

Use this instead of static injection when `quarkus.hibernate-orm."name".active` may be `false`.

### `@PersistenceUnitExtension`

Bind advanced Hibernate components to one persistence unit:

```java
@PersistenceUnitExtension
class DefaultUnitExtension {
}

@PersistenceUnitExtension("users")
class UsersUnitExtension {
}
```

Supported Quarkus-registered extension bean types include:

- `org.hibernate.Interceptor`
- `org.hibernate.resource.jdbc.spi.StatementInspector`
- `org.hibernate.type.format.FormatMapper`
- `io.quarkus.hibernate.orm.runtime.tenant.TenantResolver`
- `io.quarkus.hibernate.orm.runtime.tenant.TenantConnectionResolver`
- `org.hibernate.boot.model.FunctionContributor`
- `org.hibernate.boot.model.TypeContributor`

### Tenant resolution

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

Use `CurrentVertxRequest` rather than directly injecting `RoutingContext` if resolution must also work outside HTTP request handling.

### Programmatic tenant connections

```java
@ApplicationScoped
@PersistenceUnitExtension
class DynamicTenantConnections implements TenantConnectionResolver {
    @Override
    public ConnectionProvider resolve(String tenantId) {
        return createProviderFor(tenantId);
    }
}
```

Use this when tenant JDBC details are not fixed at build time.

### Interceptor and statement inspector

```java
@PersistenceUnitExtension
class AuditInterceptor implements Interceptor, Serializable {
}

@PersistenceUnitExtension
class SqlTagInspector implements StatementInspector {
    @Override
    public String inspect(String sql) {
        return sql + " /* users */";
    }
}
```

`@ApplicationScoped` interceptors must be thread-safe. Use `@Dependent` only when you need one instance per entity manager.

### Functions, types, and format mappers

```java
@ApplicationScoped
@PersistenceUnitExtension
class CustomFunctions implements FunctionContributor {
    @Override
    public void contributeFunctions(FunctionContributions fc) {
    }
}

@ApplicationScoped
@PersistenceUnitExtension
class CustomTypes implements TypeContributor {
    @Override
    public void contribute(TypeContributions tc, ServiceRegistry sr) {
    }
}

@JsonFormat
@PersistenceUnitExtension
class CustomJsonMapper implements FormatMapper {
}
```

For XML use `@XmlFormat`. Each persistence unit can have at most one JSON mapper and one XML mapper.

### `persistence.xml` and XML mappings

Use `META-INF/persistence.xml` mainly for migration:

```xml
<persistence-unit name="default">
    <mapping-file>META-INF/orm.xml</mapping-file>
</persistence-unit>
```

Or register mappings in Quarkus config:

```properties
quarkus.hibernate-orm.mapping-files=META-INF/orm.xml,META-INF/legacy/user.hbm.xml
```

`META-INF/orm.xml` is auto-included unless disabled with `no-file`.

### Cache entry points

```java
@Entity
@Cacheable
class Country {
    @OneToMany
    @org.hibernate.annotations.Cache(usage = CacheConcurrencyStrategy.READ_ONLY)
    List<City> cities;
}
```

```java
query.setHint("org.hibernate.cacheable", Boolean.TRUE);
```

Use `@Cacheable` for entities and query hints for query cache.

### Static metamodel and Jakarta Data

Both require the `org.hibernate.orm:hibernate-processor` annotation processor.

```java
var cb = session.getCriteriaBuilder();
var q = cb.createQuery(MyEntity.class);
var root = q.from(MyEntity.class);
q.where(cb.equal(root.get(MyEntity_.name), name));
```

```java
@Repository(dataStore = "users")
interface UserRepository extends CrudRepository<User, Long> {
}
```

Use `dataStore` for non-default persistence units.

### Envers, Spatial, and metrics

- Add `io.quarkus:quarkus-hibernate-envers` for auditing.
- Add `org.hibernate.orm:hibernate-spatial` for spatial support.
- Enable `quarkus.hibernate-orm.metrics.enabled=true` with a metrics extension for ORM metrics.

---

## Configuration Reference

### High-value properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.hibernate-orm."name".datasource` | required for named unit | A named persistence unit must bind to a datasource |
| `quarkus.hibernate-orm."name".packages` | - | Entities should be attached to a specific named unit by package |
| `quarkus.hibernate-orm."name".active` | auto | A configured unit should be runtime-selectable or disabled by default |
| `quarkus.hibernate-orm.persistence-xml.ignore` | `false` | A transitive `persistence.xml` is present but should be ignored |
| `quarkus.hibernate-orm.mapping-files` | auto-detect `META-INF/orm.xml` | XML mappings should be loaded explicitly or disabled with `no-file` |
| `quarkus.hibernate-orm.multitenant` | `NONE` | A persistence unit uses `SCHEMA`, `DATABASE`, or `DISCRIMINATOR` multitenancy |
| `quarkus.hibernate-orm.datasource` | default datasource | Database multitenancy needs one datasource as the dialect/version reference |
| `quarkus.hibernate-orm.database.start-offline` | `false` | App startup must not connect to the database |
| `quarkus.hibernate-orm.cache."region".memory.object-count` | `10000` | A cache region needs a tighter or larger entry bound |
| `quarkus.hibernate-orm.cache."region".expiration.max-idle` | `100S` | Cached data should expire sooner or remain warm longer |
| `quarkus.hibernate-orm.metrics.enabled` | `false` | Micrometer should expose Hibernate ORM metrics |
| `quarkus.hibernate-orm.request-scoped.enabled` | `true` | Read-only request-scoped session access without transactions should be disabled |

### Named persistence units

```properties
quarkus.datasource."users".db-kind=postgresql
quarkus.datasource."users".jdbc.url=jdbc:postgresql://localhost:5432/users

quarkus.hibernate-orm."users".datasource=users
quarkus.hibernate-orm."users".packages=org.acme.user,org.acme.shared
quarkus.hibernate-orm."users".schema-management.strategy=validate
```

Notes:

- Quote the unit name when using dotted property syntax.
- For named units, `datasource` is mandatory.
- You can point multiple persistence units at the same datasource.
- You can target the default datasource with `<default>` when needed.

### Runtime activation flags

```properties
quarkus.hibernate-orm."pg".active=false
quarkus.datasource."pg".active=false

quarkus.hibernate-orm."oracle".active=false
quarkus.datasource."oracle".active=false
```

Enable exactly one at runtime with config profiles, environment variables, or deployment-specific config.

```properties
%pg.quarkus.hibernate-orm."pg".active=true
%pg.quarkus.datasource."pg".active=true

%oracle.quarkus.hibernate-orm."oracle".active=true
%oracle.quarkus.datasource."oracle".active=true
```

Keep datasource and persistence unit activation in sync.

### `persistence.xml` and XML mapping

Ignore an unwanted `persistence.xml`:

```properties
quarkus.hibernate-orm.persistence-xml.ignore=true
```

Register mapping files explicitly:

```properties
quarkus.hibernate-orm.mapping-files=META-INF/orm.xml,META-INF/legacy/order.hbm.xml
```

Disable the implicit `META-INF/orm.xml` pickup:

```properties
quarkus.hibernate-orm.mapping-files=no-file
```

Do not mix `persistence.xml` with `quarkus.hibernate-orm.*` runtime configuration for the same app.

### Multitenancy modes

Schema multitenancy:

```properties
quarkus.hibernate-orm.multitenant=SCHEMA
quarkus.hibernate-orm.schema-management.strategy=none
```

Database multitenancy:

```properties
quarkus.hibernate-orm.multitenant=DATABASE
quarkus.hibernate-orm.datasource=base
quarkus.hibernate-orm.schema-management.strategy=none
```

Discriminator multitenancy:

```properties
quarkus.hibernate-orm.multitenant=DISCRIMINATOR
```

Guidance:

- Use `SCHEMA` when tenants share one database but isolate data by schema.
- Use `DATABASE` when each tenant has a dedicated datasource/database.
- Use `DISCRIMINATOR` when isolation is row-level and entities can carry `@TenantId`.
- For `SCHEMA` and `DATABASE`, plan on external schema management such as Flyway.

### Offline startup

```properties
quarkus.hibernate-orm.database.start-offline=true
```

With offline startup:

- Hibernate ORM skips connecting to the database during boot.
- Version checks against the live database do not run at startup.
- Automatic schema creation is not available; the schema must already exist.

Dialect-specific tuning can still be set per persistence unit when boot is offline.

### Cache region tuning

```properties
quarkus.hibernate-orm.cache."org.acme.Country".memory.object-count=2000
quarkus.hibernate-orm.cache."org.acme.Country".expiration.max-idle=30M
quarkus.hibernate-orm.cache."default-query-results-region".expiration.max-idle=5M
```

Notes:

- Region names containing dots must stay quoted.
- Entity regions use the entity FQCN.
- Collection regions use `OwnerEntity#collectionField`.
- Query cache uses `default-query-results-region` unless customized by Hibernate.

### Metrics and diagnostics

```properties
quarkus.hibernate-orm.metrics.enabled=true
```

This exposes Hibernate ORM metrics when a metrics extension such as Micrometer is present.

### Transaction interaction reminder

```properties
quarkus.hibernate-orm.request-scoped.enabled=false
```

Set this when you want to forbid convenience read access to request-scoped sessions outside explicit transactions.

## See Also

- `../data-orm/` - Base ORM lifecycle rules
- `../data-migrations/` - Migration tooling for multitenancy and offline startup
- `../dependency-injection/` - CDI lookup and qualifier patterns
