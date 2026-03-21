# Data Migrations Reference

Use this module when the task is about schema evolution in Quarkus with Flyway: migration setup, versioned SQL files, startup migration, baseline and repair, or moving from Hibernate-managed schema creation to managed migrations.

## Overview

Quarkus integrates Flyway as a first-class extension and wires it to the configured datasource.

- Flyway tracks applied migrations in a schema history table.
- Migrations normally live under `src/main/resources/db/migration`.
- Quarkus can run migrations automatically at startup or you can inject `Flyway` and call it directly.
- Named datasources use the same Flyway model with datasource-specific prefixes.

## General guidelines

- Treat migration files as append-only once applied anywhere shared.
- Prefer versioned SQL migrations for schema evolution; review repeatable migrations carefully.
- Keep Hibernate schema generation for prototyping, then switch production-facing environments to Flyway-managed changes.
- Use profiles to separate dev conveniences such as `clean-at-start` from production behavior.

---

## Flyway API

### Extension entry points

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-flyway</artifactId>
</dependency>

<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-jdbc-postgresql</artifactId>
</dependency>
```

Add a database-specific Flyway module when your database requires it, for example:

- `org.flywaydb:flyway-database-postgresql`
- `org.flywaydb:flyway-mysql`
- `org.flywaydb:flyway-database-oracle`

### Default migration location

Place migrations in:

```text
src/main/resources/db/migration
```

Quarkus scans `db/migration` by default.

### Versioned SQL naming

Flyway versioned SQL migrations use this structure:

```text
V1__create_tables.sql
V1.1__add_status_column.sql
V20260310_1200__backfill_reference_data.sql
```

Pattern:

```text
<prefix><version><separator><description><suffix>
```

Default pieces:

- Prefix: `V`
- Separator: `__`
- Suffix: `.sql`

Repeatable migrations use `R__description.sql`.

### Minimal setup

```properties
quarkus.datasource.db-kind=postgresql
quarkus.datasource.jdbc.url=jdbc:postgresql://localhost:5432/app
quarkus.datasource.username=app
quarkus.datasource.password=app

quarkus.flyway.migrate-at-start=true
```

With `V1__init.sql` in `db/migration`, Quarkus runs Flyway during startup.

### Inject `Flyway`

```java
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.flywaydb.core.Flyway;

@ApplicationScoped
public class MigrationService {
    @Inject
    Flyway flyway;

    public String currentVersion() {
        return flyway.info().current().getVersion().toString();
    }
}
```

Inject the default datasource Flyway instance with plain `@Inject Flyway`.

### Run migrations programmatically

```java
void migrateNow() {
    flyway.migrate();
}
```

Use this when migration timing is controlled by application logic instead of `migrate-at-start`.

### Repair programmatically

```java
void repairHistory() {
    flyway.repair();
}
```

`repair()` is useful after failed migrations on databases without transactional DDL or when checksums need history cleanup.

### Inspect migration state

```java
import org.flywaydb.core.api.MigrationInfo;

MigrationInfo current = flyway.info().current();
MigrationInfo[] pending = flyway.info().pending();
```

Use `info()` to report current version, pending scripts, and validation state.

### Named datasource injection

```java
import jakarta.inject.Inject;
import io.quarkus.flyway.FlywayDataSource;
import org.flywaydb.core.Flyway;

class MultiDatasourceMigrations {
    @Inject
    @FlywayDataSource("inventory")
    Flyway inventoryFlyway;
}
```

Quarkus also exposes named Flyway beans such as `@Named("flyway_inventory")`, but `@FlywayDataSource` is clearer.

### Customize Flyway configuration

```java
import jakarta.inject.Singleton;
import io.quarkus.flyway.FlywayConfigurationCustomizer;
import org.flywaydb.core.api.configuration.FluentConfiguration;

@Singleton
public class MigrationCustomizer implements FlywayConfigurationCustomizer {
    @Override
    public void customize(FluentConfiguration configuration) {
        configuration.connectRetries(10);
    }
}
```

Use a customizer when Quarkus does not expose the exact Flyway option you need.

### Customizer for a named datasource

```java
import jakarta.inject.Singleton;
import io.quarkus.flyway.FlywayConfigurationCustomizer;
import io.quarkus.flyway.FlywayDataSource;
import org.flywaydb.core.api.configuration.FluentConfiguration;

@Singleton
@FlywayDataSource("users")
public class UsersFlywayCustomizer implements FlywayConfigurationCustomizer {
    @Override
    public void customize(FluentConfiguration configuration) {
        configuration.defaultSchema("users_app");
    }
}
```

---

## Configuration Reference

### High-value properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.flyway.migrate-at-start` | `false` | The app should apply pending migrations during startup |
| `quarkus.flyway.validate-at-start` | `false` | Startup should fail fast when migration history does not match scripts |
| `quarkus.flyway.repair-at-start` | `false` | History metadata must be repaired before migrate runs |
| `quarkus.flyway.baseline-on-migrate` | `false` | You are onboarding an existing non-empty schema into Flyway |
| `quarkus.flyway.baseline-at-start` | `false` | Startup should create a baseline even before an explicit migrate call |
| `quarkus.flyway.baseline-version` | - | The first tracked version must be something other than `1` |
| `quarkus.flyway.baseline-description` | - | The baseline row should use an explicit label |
| `quarkus.flyway.locations` | `db/migration` | Migrations live outside the default classpath folder |
| `quarkus.flyway.schemas` | datasource default | Flyway should manage one or more explicit schemas |
| `quarkus.flyway.table` | `flyway_schema_history` | The schema history table needs a custom name |
| `quarkus.flyway.clean-at-start` | `false` | Dev/test should rebuild schema from migrations on every restart |
| `quarkus.flyway.clean-disabled` | `false` | Clean operations must be blocked for safety |

### Automatic startup migration

```properties
quarkus.flyway.migrate-at-start=true
quarkus.flyway.validate-at-start=true
```

This is the simplest Quarkus-first setup for local development and many small services.

### Baseline existing schemas

```properties
quarkus.flyway.baseline-on-migrate=true
quarkus.flyway.baseline-version=1.0.0
quarkus.flyway.baseline-description=Initial production baseline
```

`baseline-on-migrate` only matters when the schema is non-empty and history is not initialized.

If you need Quarkus startup itself to perform the baseline step, add:

```properties
quarkus.flyway.baseline-at-start=true
```

### Repair and validation on startup

```properties
quarkus.flyway.repair-at-start=true
quarkus.flyway.validate-at-start=true
```

Use `repair-at-start` sparingly. It is a recovery tool, not a normal steady-state setting.

### Custom locations and schemas

```properties
quarkus.flyway.locations=db/migration,db/common
quarkus.flyway.schemas=app,app_audit
quarkus.flyway.table=app_flyway_history
```

When `schemas` is set, the first schema becomes the default managed schema and holds the history table.

### Named datasource configuration

Flyway keys follow the datasource name:

```properties
quarkus.datasource.users.db-kind=postgresql
quarkus.datasource.users.jdbc.url=jdbc:postgresql://localhost:5432/users
quarkus.datasource.users.username=users
quarkus.datasource.users.password=users

quarkus.flyway.users.locations=db/users
quarkus.flyway.users.migrate-at-start=true
quarkus.flyway.users.schemas=users_app
```

The general shape is:

```text
quarkus.flyway.<datasource-name>.<property>
```

### Dev/test cleanup profile

```properties
%dev.quarkus.flyway.clean-at-start=true
%test.quarkus.flyway.clean-at-start=true
%prod.quarkus.flyway.clean-at-start=false
```

Use profiles so destructive cleanup never leaks into production.

### Reactive datasource note

Flyway uses JDBC internally.

If the application otherwise uses reactive SQL clients, configure the same datasource for JDBC as well and include the JDBC driver extension needed by Flyway.

### Kubernetes init-job note

When generating Kubernetes or OpenShift manifests, Quarkus can externalize Flyway startup into an initialization `Job` so every replica does not run migrations itself.

Disable the default behavior only when your rollout process already handles migrations elsewhere:

```properties
quarkus.kubernetes.init-task-defaults.enabled=false
quarkus.openshift.init-task-defaults.enabled=false
```

## See Also

- `../data-orm/` - ORM schema-management context and the handoff to managed migrations
- `../configuration/` - Profiles and deployment-specific property organization
