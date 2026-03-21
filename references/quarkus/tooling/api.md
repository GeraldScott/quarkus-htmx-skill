# Quarkus Tooling Reference

## Overview

There are two ways to work with Quarkus projects from the command line:
- Quarkus CLI
- Build system (Maven/Gradle)

Treat them as complementary layers, not competing choices. Keep command intent aligned across both layers (same extensions, profiles, and build goals).

### General guidelines

- Use Quarkus CLI for local development speed and consistency.
- Use Maven/Gradle as a local fallback, directly in CI, automation scripts, and environments where reproducibility and zero extra-tool assumptions matter.
- For new projects, default to Maven unless the user explicitly asks for Gradle.
- For new projects, default to latest LTS version of Quarkus and Java unless the user explicitly asks for specific versions.
- Prefer explicit coordinates for new projects instead of relying on defaults in team scripts.
- For reproducible automation, avoid wildcard extension adds unless intentionally broad.

### Essential commands

| Task | Quarkus CLI | Maven fallback | Gradle fallback |
|------|-------------|----------------|-----------------|
| Create app | `quarkus create app org.acme:my-app` | Quarkus Maven plugin create flow | Prefer installing CLI, then use `quarkus create ... --gradle` |
| Run dev mode | `quarkus dev` | `./mvnw quarkus:dev` | `./gradlew quarkusDev` |
| Run tests | `quarkus test` | `./mvnw test` | `./gradlew test` |
| Build package | `quarkus build` | `./mvnw package` | `./gradlew build` |
| Add extension | `quarkus ext add rest` | `./mvnw quarkus:add-extension -Dextension=rest` | `./gradlew addExtension --extensions="rest"` |
| Build image | `quarkus image build <builder>` | Build-tool-specific container-image flow | Build-tool-specific container-image flow |
| Deploy | `quarkus deploy <target>` | Build-tool-specific deploy flow | Build-tool-specific deploy flow |

## CLI model

- `quarkus` is a command-line facade over Quarkus build tooling.
- It can execute workflows for Maven, Gradle, and JBang-backed projects.
- Primary value: one stable command style across build systems.

```text
quarkus [global-options] [command] [subcommand] [args]
```

If in doubt, inspect the behavior with:

```bash
quarkus --help
quarkus <command> --help
```

## Commands reference

```bash
quarkus --help
Usage: quarkus [-ehv] [--refresh] [--verbose] [--config=CONFIG]
               [-D=<String=String>]... [COMMAND]
Options:
      --refresh         Refresh the local Quarkus extension registry cache
      --config=CONFIG   Configuration file
  -h, --help            Display this help message.
  -v, --version         Print CLI version information and exit.
  -e, --errors          Display error messages.
      --verbose         Verbose mode.
  -D=<String=String>    Java properties

Commands:
  create                  Create a new project.
    app                   Create a Quarkus application project.
    cli                   Create a Quarkus command-line project.
    extension             Create a Quarkus extension project
  build                   Build the current project.
  dev                     Run the current project in dev (live coding) mode.
  test                    Run the current project in continuous testing mode.
  extension, ext          Configure extensions of an existing project.
    list, ls              List platforms and extensions.
    categories, cat       List extension categories.
    add                   Add extension(s) to this project.
    remove, rm            Remove extension(s) from this project.
  image                   Build or push project container image.
    build                 Build a container image.
      docker              Build a container image using Docker.
      podman              Build a container image using Podman.
      buildpack           Build a container image using Buildpack.
      jib                 Build a container image using Jib.
      openshift           Build a container image using OpenShift.
    push                  Push a container image.
  deploy                  Deploy application.
    kubernetes            Perform the deploy action on Kubernetes.
    openshift             Perform the deploy action on OpenShift.
    knative               Perform the deploy action on Knative.
    kind                  Perform the deploy action on Kind.
    minikube              Perform the deploy action on minikube.
  registry                Configure Quarkus registry client
    list                  List enabled Quarkus registries
    add                   Add a Quarkus extension registry
    remove                Remove a Quarkus extension registry
  info                    Display project information and verify versions
                            health (platform and extensions).
  update, up, upgrade     Suggest recommended project updates with the
                            possibility to apply them.
  version                 Display CLI version information.
  plugin, plug            Configure plugins of the Quarkus CLI.
    list, ls              List CLI plugins.
    add                   Add plugin(s) to the Quarkus CLI.
    remove                Remove plugin(s) to the Quarkus CLI.
    sync                  Sync (discover / purge) CLI Plugins.
  completion              bash/zsh completion:  source <(quarkus completion)
```

## Project creation

```bash
quarkus create app
quarkus create app org.acme:my-app
quarkus create app org.acme:my-app:1.0.0
quarkus create app org.acme:my-app --gradle
```

Defaults:

- `groupId=org.acme`
- `artifactId=code-with-quarkus`
- `version=1.0.0-SNAPSHOT`

Version targeting options:

- `-P <groupId:artifactId:version>` for platform BOM
- `-S <platformKey:streamId>` for platform stream

## Extension API

List and search:

```bash
quarkus ext ls
quarkus ext list --concise -i -s jdbc
```

Add/remove:

```bash
quarkus ext add rest
quarkus ext add smallrye-*
quarkus ext rm kubernetes
```

Useful list flags:

- `--name` - display the name (artifactId) only
- `--concise` - display the name (artifactId) and description
- `--full` - display concise information
- `--origins` - display concise information along with the Quarkus platform release origin
- `-i` - show currently installable only
- `-s <search>` - filter the list

## Dev/Test/Build API

You can run the commands with `--clean` to perform clean as part of the build:

```bash
quarkus dev --clean
```

## Plugin API

Discover/manage plugins:

```bash
quarkus plugin list
quarkus plugin list --installable
quarkus plugin add <name-or-location>
quarkus plugin remove <name>
quarkus plugin sync
```

Supported plugin sources include:

- local executables prefixed with `quarkus-`
- runnable JARs
- JBang aliases prefixed with `quarkus-`
- Maven coordinates to runnable JARs

## Dev UI

In dev mode, Quarkus exposes a developer console at `http://localhost:8080/q/dev-ui`:

```bash
quarkus dev
# then open http://localhost:8080/q/dev-ui
```

Key Dev UI capabilities:

- Browse and manage extensions, configuration, and beans
- View and test REST endpoints
- Inspect Flyway migration status and generate initial migrations from Hibernate schema
- Monitor ArC beans, observers, and interceptors
- View and manage scheduled tasks
- Access Swagger UI for OpenAPI exploration
- Inspect Dev Services containers and their connection details

Dev UI is available only in dev mode and is not packaged into production builds.

## Recommended project directory layout

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
│   │           └── resources/   # Static web assets (JS, CSS, images -- served at /)
│   └── test/
│       ├── java/com/example/
│       └── resources/
│           └── application.properties  # Test overrides (or use %test. prefix)
├── pom.xml
└── .env                         # Local secrets for Dev Mode (gitignored)
```

## Recommended extensions for HTMX + Qute projects

### Always include
```
io.quarkus:quarkus-arc                     # CDI (included transitively by most others)
io.quarkus:quarkus-rest                    # JAX-RS (formerly resteasy-reactive)
io.quarkus:quarkus-rest-jackson            # JSON marshalling
```

### Templates + HTMX
```
io.quarkus:quarkus-rest-qute               # Qute template engine for JAX-RS
```

### Database (PostgreSQL)
```
io.quarkus:quarkus-hibernate-orm-panache   # ORM with Active Record + Repository
io.quarkus:quarkus-jdbc-postgresql         # JDBC driver + DevServices
io.quarkus:quarkus-flyway                  # Schema migrations
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

## Configuration

### Installation matrix

| Method | Platforms | Install | Update |
|--------|-----------|---------|--------|
| SDKMAN! | Linux, macOS | `sdk install quarkus` | `sdk upgrade quarkus` |
| Homebrew | Linux, macOS | `brew install quarkusio/tap/quarkus` | `brew update && brew upgrade quarkus` |
| Chocolatey | Windows | `choco install quarkus` | `choco upgrade quarkus` |
| Scoop | Windows | `scoop install quarkus-cli` | `scoop update quarkus-cli` |
| JBang | Linux, macOS, Windows | `jbang app install --fresh --force quarkus@quarkusio` | same command |

Verification:

```bash
quarkus --version
```

### Shell configuration

Enable completion for current shell session:

```bash
source <(quarkus completion)
```

Optional alias:

```bash
alias q=quarkus
complete -F _complete_quarkus q
```

Persist these in shell profile files if needed.

### Plugin catalog configuration

Plugin metadata catalogs:

- User scope: `~/.quarkus/cli/plugins/quarkus-cli-catalog.json`
- Project scope: `<project>/.quarkus/cli/plugins/quarkus-cli-catalog.json`

Precedence rule:

- Project catalog overrides user catalog for that project.
- Use `--user` when an operation must target user scope explicitly.

### Dev Services configuration

Dev Services automatically starts backing services (databases, brokers, etc.) in dev and test mode using Testcontainers. No manual Docker setup required.

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.datasource.devservices.enabled` | `true` | Dev Services must be explicitly disabled |
| `quarkus.datasource.devservices.image-name` | extension default | A specific container image version is required |
| `quarkus.datasource.devservices.port` | random | A fixed port is needed for external tool access |
| `quarkus.datasource.devservices.db-name` | `quarkus` | The dev database name should differ from the default |
| `quarkus.datasource.devservices.username` | `quarkus` | Custom credentials are needed (dev/test only) |
| `quarkus.datasource.devservices.password` | `quarkus` | Custom credentials are needed (dev/test only) |
| `quarkus.datasource.devservices.init-script-path` | - | A SQL script should seed the dev database on startup |
| `quarkus.datasource.devservices.volumes` | - | Host paths should be mounted into the container |
| `quarkus.datasource.devservices.container-env` | - | Extra environment variables should be passed to the container |
| `quarkus.datasource.devservices.container-properties` | - | Database-specific container properties are needed |

Named datasources use the same pattern:

```properties
quarkus.datasource."inventory".devservices.image-name=postgres:16
quarkus.datasource."inventory".devservices.db-name=inventory
```

Dev Services for other extensions (Kafka, Redis, Keycloak, etc.) follow the same `quarkus.<extension>.devservices.*` pattern.

DevServices PostgreSQL example:

```properties
# Override the DevServices image (e.g., to match production version)
quarkus.datasource.devservices.image-name=postgres:16-alpine

# Reuse the same container across restarts (faster startup)
quarkus.datasource.devservices.reuse=true

# Give it a fixed port so external tools (DBeaver, psql) can connect
quarkus.datasource.devservices.port=15432
```

### Continuous testing configuration

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.test.continuous-testing` | `paused` | Continuous testing should start enabled or disabled by default |
| `quarkus.test.include-pattern` | - | Only specific test classes should run |
| `quarkus.test.exclude-pattern` | - | Specific test classes should be skipped |
| `quarkus.test.type` | `unit` | Integration tests (`@QuarkusIntegrationTest`) should also run |

### Registry credentials for image push

Example flags:

```bash
quarkus image push --registry=<registry> --registry-username=<username> --registry-password-stdin
```

Prefer stdin-driven secrets to avoid exposing passwords in command history.

## Dependency Vulnerability Scanning

Check dependencies for known CVEs. Run in CI to catch vulnerable transitive
dependencies before they reach production.

### OWASP Dependency-Check (Maven)

Add to `pom.xml`:

```xml
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <version>10.0.3</version>
    <executions>
        <execution>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
    <configuration>
        <!-- Fail the build on CVSS >= 7 (high severity) -->
        <failBuildOnCVSS>7</failBuildOnCVSS>
    </configuration>
</plugin>
```

Run manually:

```bash
./mvnw org.owasp:dependency-check-maven:check
```

DevServices credentials (`quarkus.datasource.devservices.username/password`)
are only active in dev and test mode. For production, always use environment
variable placeholders (`${DB_USER}`, `${DB_PASSWORD}`) and never commit
credentials to version control.
