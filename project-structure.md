# Quarkus Project Structure Reference

## Standard directory layout

```
my-app/
├── src/
│   ├── main/
│   │   ├── java/com/example/
│   │   │   ├── domain/          # Entities, value objects
│   │   │   ├── repository/      # Panache repositories
│   │   │   ├── service/         # Business logic (@ApplicationScoped)
│   │   │   ├── resource/        # JAX-RS endpoints
│   │   │   ├── dto/             # Request/response DTOs (Java Records preferred)
│   │   │   └── mapper/          # Entity <-> DTO mappers (MapStruct or manual)
│   │   └── resources/
│   │       ├── application.properties
│   │       ├── db/migration/    # Flyway SQL scripts
│   │       ├── templates/       # Qute templates (.html)
│   │       └── META-INF/
│   │           └── resources/   # Static web assets (JS, CSS, images → served at /)
│   └── test/
│       ├── java/com/example/
│       └── resources/
│           └── application.properties  # Test overrides (or use %test. prefix)
├── pom.xml
└── .env                         # Local secrets for Dev Mode (gitignored)
```

## Recommended extensions by concern

### Always include
```
io.quarkus:quarkus-arc                     # CDI (included transitively by most others)
io.quarkus:quarkus-resteasy-reactive       # JAX-RS (imperative + reactive unified)
io.quarkus:quarkus-resteasy-reactive-jackson  # JSON marshalling
```

### Database (PostgreSQL)
```
io.quarkus:quarkus-hibernate-orm-panache   # ORM with Active Record + Repository
io.quarkus:quarkus-jdbc-postgresql         # JDBC driver + DevServices
io.quarkus:quarkus-flyway                  # Schema migrations
```

### Templates + HTMX
```
io.quarkus:quarkus-resteasy-reactive-qute  # Qute template engine for JAX-RS
```

### Validation
```
io.quarkus:quarkus-hibernate-validator     # Bean Validation (@Valid, @NotNull, etc.)
```

### Observability
```
io.quarkus:quarkus-smallrye-health         # /q/health endpoints
io.quarkus:quarkus-smallrye-openapi        # /q/openapi + Swagger UI
io.quarkus:quarkus-micrometer-registry-prometheus  # /q/metrics (Prometheus)
```

### Security
```
io.quarkus:quarkus-security                # Core security model
io.quarkus:quarkus-oidc                    # OIDC / OAuth2 (Keycloak, Auth0, etc.)
io.quarkus:quarkus-smallrye-jwt            # JWT token verification
```

### Testing
```
io.quarkus:quarkus-junit5                  # @QuarkusTest
io.rest-assured:rest-assured               # HTTP assertions
io.quarkus:quarkus-test-security           # @TestSecurity for mocked principals
```

## Adding extensions

```bash
# Quarkus CLI (recommended)
quarkus ext add flyway hibernate-orm-panache jdbc-postgresql

# Maven plugin
./mvnw quarkus:add-extension -Dextensions="flyway,hibernate-orm-panache,jdbc-postgresql"

# List available extensions
quarkus ext list --installable
```

## Dev Mode

```bash
./mvnw quarkus:dev          # Start with live reload + DevServices + continuous testing
./mvnw quarkus:dev -Ddebug  # Attach debugger on port 5005
```

Dev Mode features:
- **Live reload**: code changes recompile and reload on the next request
- **DevServices**: auto-starts Docker containers for PostgreSQL, Kafka, Redis, etc.
  when no connection URL is configured for `%dev` profile
- **Dev UI**: available at http://localhost:8080/q/dev — shows config, beans, routes,
  SQL queries, flyway state, health, etc.
- **Continuous testing**: press `r` in the Dev Mode console to run tests; press `o` to
  toggle continuous testing

## DevServices PostgreSQL configuration

DevServices launches a real PostgreSQL container using Testcontainers under the hood.
You don't need to configure anything for `%dev` or `%test` profiles when Docker is running.

```properties
# Override the DevServices image (e.g., to match production version)
quarkus.datasource.devservices.image-name=postgres:16-alpine

# Reuse the same container across restarts (faster startup)
quarkus.datasource.devservices.reuse=true

# Give it a fixed port so external tools (DBeaver, psql) can connect
quarkus.datasource.devservices.port=15432
```

## Full application.properties example

```properties
# App metadata
quarkus.application.name=my-app
quarkus.application.version=1.0.0

# HTTP
quarkus.http.port=8080
%dev.quarkus.http.port=8080

# Database — DevServices handles dev/test automatically
%prod.quarkus.datasource.db-kind=postgresql
%prod.quarkus.datasource.username=${DB_USER}
%prod.quarkus.datasource.password=${DB_PASSWORD}
%prod.quarkus.datasource.jdbc.url=jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME}
%prod.quarkus.datasource.jdbc.max-size=20

# Hibernate
quarkus.hibernate-orm.log.sql=false
%dev.quarkus.hibernate-orm.log.sql=true
%prod.quarkus.hibernate-orm.database.generation=none

# Flyway
quarkus.flyway.migrate-at-start=true
%test.quarkus.flyway.migrate-at-start=true

# Logging
quarkus.log.level=INFO
quarkus.log.category."com.example".level=DEBUG

# CORS (if needed for HTMX from a different origin)
quarkus.http.cors=true
quarkus.http.cors.origins=http://localhost:3000

# Health / OpenAPI
quarkus.smallrye-openapi.info-title=My App API
quarkus.swagger-ui.always-include=true
```

## Native image compilation (GraalVM / Mandrel)

```bash
# Requires Mandrel or GraalVM installed, or Docker
./mvnw package -Dnative                           # Local GraalVM/Mandrel
./mvnw package -Dnative -Dquarkus.native.container-build=true  # Docker build
```

If a third-party library uses reflection at runtime and breaks native compilation:

```java
// Register for reflection in a Quarkus build-time class
@RegisterForReflection(targets = {SomeExternalClass.class})
public class NativeConfig {}
```

Or use `src/main/resources/reflect-config.json` for bulk registration.

## Quarkus CLI reference

```bash
quarkus create app groupId:artifactId     # Scaffold new project
quarkus dev                               # Start dev mode (same as ./mvnw quarkus:dev)
quarkus build                             # Package (JAR)
quarkus build --native                    # Native binary
quarkus ext list                          # Show installed extensions
quarkus ext add <name>                    # Add extension
quarkus ext remove <name>                 # Remove extension
quarkus image build --docker             # Build container image with Docker
```
