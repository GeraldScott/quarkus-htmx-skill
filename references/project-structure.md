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

## Configuration

### Config source priority

Higher-priority sources override lower ones for the same key.

| Source | Typical location | Ordinal |
|--------|------------------|---------|
| System properties | `-Dkey=value` | `400` |
| Environment variables | shell/container env | `300` |
| Dotenv file | `$PWD/.env` | `295` |
| Working directory config | `$PWD/config/application.properties` | `260` |
| Classpath app config | `src/main/resources/application.properties` | `250` |
| MicroProfile default file | `META-INF/microprofile-config.properties` | `100` |

If the same key exists in multiple sources, the highest-priority source wins.
Use `quarkus.config.locations` to add extra sources:

```properties
quarkus.config.locations=file:/etc/acme/app.properties,classpath:tenant-defaults.properties
```

Supported URI schemes: `file:`, `classpath:`, `jar:`, `http:`.

### @ConfigProperty injection

```java
import org.eclipse.microprofile.config.inject.ConfigProperty;
import java.util.Optional;

@ApplicationScoped
class GreetingConfig {
    @ConfigProperty(name = "greeting.message")
    String message;                                    // required — missing fails startup

    @ConfigProperty(name = "greeting.suffix", defaultValue = "!")
    String suffix;                                     // default when key is absent

    @ConfigProperty(name = "greeting.name")
    Optional<String> name;                             // optional — missing is OK
}
```

### Programmatic access

When injection is not available (e.g., utility classes, static methods):

```java
import io.smallrye.config.SmallRyeConfig;
import org.eclipse.microprofile.config.ConfigProvider;

SmallRyeConfig cfg = ConfigProvider.getConfig().unwrap(SmallRyeConfig.class);
String db = cfg.getValue("database.name", String.class);
ServerConfig server = cfg.getConfigMapping(ServerConfig.class);
```

### @ConfigMapping (recommended for groups)

Prefer `@ConfigMapping` over scattered `@ConfigProperty` fields when multiple related keys
belong to one domain concept.

```java
import io.smallrye.config.ConfigMapping;
import io.smallrye.config.WithDefault;
import io.smallrye.config.WithName;

@ConfigMapping(prefix = "server")
interface ServerConfig {
    String host();                          // server.host (required)
    int port();                             // server.port (required)
    Log log();                              // nested group

    interface Log {
        @WithDefault("false")
        boolean enabled();                  // server.log.enabled

        @WithName("file-suffix")
        @WithDefault(".log")
        String suffix();                    // server.log.file-suffix
    }
}
```

```java
@Inject ServerConfig server;
// server.host() / server.log().suffix()
```

Collections and maps are also supported:

```java
@ConfigMapping(prefix = "app")
interface AppConfig {
    List<String> origins();                 // app.origins[0]=https://a.example
    Map<String, String> labels();           // app.labels.team=payments
}
```

Validation (requires `quarkus-hibernate-validator`):

```java
@ConfigMapping(prefix = "server")
interface ValidatedServerConfig {
    @Size(min = 2, max = 20) String host();
    @Max(10000) int port();
}
```

### Profiles

```properties
quarkus.http.port=9090
%dev.quarkus.http.port=8181
%test.quarkus.http.port=8182

# Activate custom profiles
quarkus.profile=staging,tenant-a
quarkus.config.profile.parent=common
```

Profile-aware files (override inline `%profile.` entries in `application.properties`):
- `application-dev.properties`
- `application-staging.properties`

Rules:
- For multiple active profiles, the last profile listed has highest priority.
- Do not set `quarkus.profile` inside profile-aware files.
- In `.env`, profile keys use `_PROFILE_` prefixes: `_DEV_QUARKUS_HTTP_PORT=8181`.

### Property expressions and fallbacks

```properties
remote.host=quarkus.io
application.host=${HOST:${remote.host}}
application.url=https://${application.host}
```

Supported forms: `${key}`, `${key:default}`, `${outer${inner}}`.
This keeps defaults in one place while allowing external override via env vars.

### Environment variable naming

For a property like `foo.BAR.baz`, SmallRye Config checks these env names:

1. `foo.BAR.baz` (exact)
2. `foo_BAR_baz` (replace non-alphanumeric with `_`)
3. `FOO_BAR_BAZ` (uppercase)

Double underscores handle quoted segments:

| Property name | Env var name |
|---------------|--------------|
| `foo."bar".baz` | `FOO__BAR__BAZ` |
| `foo.bar-baz` | `FOO_BAR_BAZ` |
| `foo.bar[0]` | `FOO_BAR_0_` |
| `foo.bar[0].baz` | `FOO_BAR_0__BAZ` |

For dynamic path segments (e.g., named datasources), supply the dotted key in another
source to disambiguate:

```properties
quarkus.datasource."datasource-name".jdbc.url=
```

```bash
export QUARKUS_DATASOURCE__DATASOURCE_NAME__JDBC_URL=jdbc:postgresql://localhost:5432/db
```

### Local secrets with .env

```properties
# .env (project root, gitignored)
ACME_API_KEY=dev-secret
QUARKUS_DATASOURCE_PASSWORD=dev-password
```

Add `.env` to `.gitignore`. Use real secret stores (Vault, K8s secrets) in production.

Layered runtime overrides for deployments:

```bash
# System property (ordinal 400 — highest)
java -Dacme.api.host=api.internal -jar target/quarkus-app/quarkus-run.jar

# Environment variable (ordinal 300)
export ACME_API_HOST=api.internal
./target/myapp-runner
```

### Startup validation

Annotate `@ConfigMapping` methods with Bean Validation constraints to fail fast on bad config:

```java
import io.smallrye.config.ConfigMapping;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

@ConfigMapping(prefix = "api")
interface ApiConfig {
    @Min(500) @Max(3000) int requestTimeoutMillis();
}
```

Requires `quarkus-hibernate-validator`. Invalid values cause startup failure.

### Build-time drift tracking

```properties
quarkus.config-tracking.enabled=true
```

```bash
./mvnw quarkus:track-config-changes
```

Use this to detect build-time config changes between CI builds.

### Reserved prefixes and lifecycle

- The `quarkus.` prefix is reserved for Quarkus core/extensions.
- Use your own namespace (e.g., `acme.*`) for application keys.
- Build-time-fixed properties require rebuild to take effect; runtime properties can be
  overridden via env vars or system properties at startup.

### High-value Quarkus configuration keys

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.profile` | `prod` (outside dev/test) | Activate custom profiles |
| `quarkus.config.profile.parent` | - | Profile values should fall back to a parent profile |
| `quarkus.config.locations` | - | Config must be loaded from extra files/URIs |
| `quarkus.config.log.values` | - | You need diagnostics for resolved config values |
| `quarkus.config-tracking.enabled` | `false` | You want build-time config tracking artifacts |

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

### Essential commands

| Task | Quarkus CLI | Maven fallback |
|------|-------------|----------------|
| Create app | `quarkus create app org.acme:my-app` | Quarkus Maven plugin create flow |
| Run dev mode | `quarkus dev` | `./mvnw quarkus:dev` |
| Run tests | `quarkus test` | `./mvnw test` |
| Build package | `quarkus build` | `./mvnw package` |
| Build native | `quarkus build --native` | `./mvnw package -Dnative` |
| Add extension | `quarkus ext add rest` | `./mvnw quarkus:add-extension -Dextension=rest` |
| Remove extension | `quarkus ext remove rest` | Edit `pom.xml` manually |
| List extensions | `quarkus ext list` | `./mvnw quarkus:list-extensions` |
| Build container image | `quarkus image build <builder>` | Build-tool-specific container-image flow |
| Deploy | `quarkus deploy <target>` | Build-tool-specific deploy flow |

Use `quarkus --help` and `quarkus <command> --help` as the authoritative source for the
installed CLI version. Prefer the CLI for local dev speed; use Maven directly in CI.

### CLI availability

Check CLI availability before use:

```bash
quarkus --version
```

If unavailable, detect the project build tool and use the wrapper:
- Maven: look for `pom.xml` or `mvnw` and use `./mvnw`
- Gradle: look for `build.gradle(.kts)` or `gradlew` and use `./gradlew`

Install the CLI via SDKMAN (recommended), Homebrew, Chocolatey, Scoop, or JBang.

### Configuration gotchas

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Value in `application.properties` appears ignored | Higher-priority source (`-D`, env var, `.env`) overrides it | Check effective value by reviewing higher-priority sources first |
| Env var override does not work | Env key name does not match expected conversion | Use canonical env naming (e.g., `QUARKUS_HTTP_PORT`) |
| Profile-specific `.env` value is ignored | Profile key not prefixed with `_PROFILE_` style | Use `_DEV_...`, `_TEST_...` for profile-scoped dotenv keys |
| `%dev` values do not apply | Application not running in `dev` profile | Start with dev mode or set `quarkus.profile=dev` |
| Startup fails with missing config mapping value | Required `@ConfigMapping` member has no value and no default | Add key, switch to optional type, or add `@WithDefault` |
| Validation annotations are ignored | Hibernate Validator extension missing | Add `quarkus-hibernate-validator` |
| Property change has no effect until rebuild | Property is build-time-fixed | Rebuild/repackage after changing the key |
| App settings conflict with framework behavior | Application keys use reserved `quarkus.` prefix | Move app keys to your own namespace (e.g., `acme.*`) |
| Runtime value differs from local dev expectation | Dev run picks up `.env` or shell vars unexpectedly | Inspect and clean local `.env`/env vars, then rerun |
| Quoted/dynamic datasource env var is ignored | Reverse mapping from env var to dotted key is ambiguous | Add dotted key in another source (can be empty) to disambiguate |
| Profile file values "win" over inline profile keys | `application-{profile}.properties` has higher precedence than `%profile.` entries | Keep one source of truth per key per profile |
| `@InjectMock` fails for config mapping | Mapping implementation is not a normal CDI proxy bean | Mock via producer methods (e.g., `@io.quarkus.test.Mock`) |
| `${key:default}` default is not used | Key exists but is explicitly empty | Decide whether empty should be valid; avoid setting empty value if not |
| Hard to detect why artifact behavior changed | Build-time config drift not tracked | Enable `quarkus.config-tracking.enabled` and compare builds |

### Tooling gotchas

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `quarkus: command not found` | CLI not installed or not on `PATH` | Install via SDKMAN/Homebrew/JBang, then re-check `quarkus --version` |
| Command/flag from docs fails locally | Docs and local CLI versions differ | Use `quarkus --help` and `quarkus <command> --help` for installed version truth |
| `quarkus dev` fails unexpectedly | Not running from project root | Run from directory containing `pom.xml` or `build.gradle(.kts)` |
| Extension not found | Search too broad or wrong ID guess | Use `quarkus ext list --concise -i -s <term>` before `ext add` |
| Unexpected extensions added with wildcard | Wildcard expansion too broad | Prefer exact extension IDs in automated scripts |
| Build tool mismatch confusion | CLI delegates based on project type | Verify project files and use matching wrapper (`./mvnw` or `./gradlew`) |
| `quarkus image push` auth errors | Missing/invalid registry credentials | Use `--registry`, `--registry-username`, and `--registry-password-stdin` |
| Plugin works in one project but not another | Plugin installed project-scoped | Check `<project>/.quarkus/cli/plugins/quarkus-cli-catalog.json` |
| Completion works only in current terminal | Completion not persisted | Add `source <(quarkus completion)` to shell profile |
