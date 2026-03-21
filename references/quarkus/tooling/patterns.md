# Quarkus CLI Usage Patterns

Use these patterns for repeatable command-line workflows.

## Pattern: Daily Dev Loop

When to use:

- Active feature work on an existing service.

Commands:

```bash
quarkus dev
quarkus test
quarkus build
```

## Pattern: Create a New Service with Explicit Coordinates

When to use:

- Bootstrap a new app and keep metadata explicit in terminal history.

Commands:

```bash
quarkus create app com.acme:orders-service:1.0.0-SNAPSHOT
```

Gradle variant:

```bash
quarkus create app com.acme:orders-service --gradle
```

## Pattern: Scaffold an HTMX + Qute Project

When to use:

- You are starting a new server-rendered web application with HTMX and Qute.

Commands:

```bash
quarkus create app com.acme:my-app --extension='rest,rest-qute,hibernate-orm-panache,jdbc-postgresql,flyway'
```

This gives you Qute templating with REST integration, database access with Panache, and Flyway migrations. Dev Services will automatically provision a PostgreSQL container.

## Pattern: Discover Then Add Extensions

When to use:

- You know capability area (for example JDBC or messaging) but not exact extension IDs.

Commands:

```bash
quarkus ext list --concise -i -s jdbc
quarkus ext add jdbc-postgresql
```

## Pattern: Zero-Config Dev with Dev Services

When to use:

- You want a database, Kafka, Redis, or other backing service available in dev mode without manual Docker setup.

Setup:

```bash
quarkus ext add jdbc-postgresql
quarkus dev
```

Dev Services detects the extension, starts a Testcontainer for PostgreSQL, and injects the connection properties automatically. No `quarkus.datasource.jdbc.url` needed for dev/test.

To pin a specific database version:

```properties
%dev.quarkus.datasource.devservices.image-name=postgres:16
```

To seed dev data on startup:

```properties
%dev.quarkus.datasource.devservices.init-script-path=dev-seed.sql
```

Dev Services works for many extensions: PostgreSQL, MySQL, MariaDB, MongoDB, Kafka, RabbitMQ, Redis, Keycloak, Elasticsearch, and more.

## Pattern: Continuous Testing During Development

When to use:

- You want tests to re-run automatically as you change code.

Commands:

```bash
quarkus dev
# Press 'r' in the dev mode console to trigger tests
# Press 'o' to toggle test output
```

Or enable continuous testing by default:

```properties
quarkus.test.continuous-testing=enabled
```

## Pattern: Build Container Images Without Editing Build Files

When to use:

- Need quick image production with minimal project churn.

Commands:

```bash
quarkus image build docker
quarkus image build jib
quarkus image push --registry=<registry> --registry-username=<username> --registry-password-stdin
```

## Pattern: Switch Deployment Targets Quickly

When to use:

- Same application must be deployed to different local or cluster environments.

Commands:

```bash
quarkus deploy kind
quarkus deploy minikube
quarkus deploy kubernetes
```

## Pattern: Team Automation with Plugins

When to use:

- Team wants reusable custom commands (scaffolding, validation, operational routines).

Commands:

```bash
quarkus plugin list --installable
quarkus plugin add <name-or-location>
quarkus plugin sync
```
