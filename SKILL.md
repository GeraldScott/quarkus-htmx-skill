---
name: htmx-quarkus
description: >
  Expert Quarkus Java developer skill. Use this skill whenever the user is working with
  Quarkus — including REST endpoints (JAX-RS/RESTEasy), CDI dependency injection,
  Hibernate ORM with Panache, PostgreSQL datasources, Qute templating, HTMX integration,
  Dev Mode, DevServices, QuarkusTest, application.properties configuration, Maven build,
  or Quarkus extensions. Activate automatically when the user mentions Quarkus,
  quarkus-*, @QuarkusTest, Panache, Qute, quarkus.datasource, or shows pom.xml/build.gradle
  files with io.quarkus dependencies. Also use for project scaffolding, extension management
  with the Quarkus CLI, native compilation questions, or any Quarkus-specific error messages.
compatibility: >
  Requires Java 21+, Maven 3.9+, Docker (for DevServices/Testcontainers).
  Works with Claude Code and Claude.ai.
---

# Quarkus Expert Skill

You are an expert Quarkus developer. This skill covers the full Quarkus development
workflow: project setup, REST, CDI, Panache ORM, PostgreSQL, Qute + HTMX, testing,
configuration, and the build/run lifecycle.

**Target stack**: Quarkus (latest stable) · Java 21 · Maven · PostgreSQL · Qute · HTMX 

## Reference files — read as needed

- `references/project-structure.md` — scaffolding, Maven BOM, extension list, directory layout
- `references/rest-and-htmx.md` — JAX-RS resources, Qute templates, HTMX patterns, SSE
- `references/database-postgresql.md` — datasource config, Panache entities & repositories, migrations
- `references/testing.md` — QuarkusTest, @TestProfile, RestAssured, Mockito, Testcontainers
- `references/htmx-anti-patterns.md` — HTMX anti-patterns to avoid (JSON responses, SPA state, polling abuse, etc.)

Read only the reference file(s) relevant to the current task, not all of them.

**HTMX enforcement**: When generating HTMX code, always check `htmx-anti-patterns.md` first.
Server returns HTML, not JSON. Never rebuild DOM with client-side JavaScript. Detect `HX-Request`
header to return fragments vs full pages. If a solution mimics SPA architecture, restructure it.

---

## Core Principles

**Build-time magic, not runtime magic.** Quarkus moves reflection, classpath scanning, and
proxy generation to build time. This means: favour constructor injection over field injection
where testability matters, annotate third-party classes in a `QuarkusMain` or extension if
they need reflection, and don't rely on classpath scanning tricks that bypass the Quarkus
build-time processor.

**Dev Mode is your inner loop.** `./mvnw quarkus:dev` gives live reload and DevServices
(automatic Docker containers for PostgreSQL, etc.). Prefer running tests inside Dev Mode
(`quarkus.test.continuous-testing=enabled`) rather than separate `mvn test` runs during
development.

**application.properties is the single source of truth.** Quarkus uses MicroProfile Config;
profile-specific overrides live in `%dev.`, `%test.`, `%prod.` prefixes. For groups of
related properties, prefer `@ConfigMapping` over individual `@ConfigProperty` fields:

```java
@ConfigMapping(prefix = "app.mail")
public interface MailConfig {
    String from();
    Optional<String> replyTo();
    @WithDefault("25") int port();
}
// Inject as: @Inject MailConfig mailConfig;
// Maps: app.mail.from, app.mail.reply-to, app.mail.port
```

---

## Quick-reference cheat sheet

### Project creation (CLI)
```bash
quarkus create app com.example:my-app \
  --extension=resteasy-reactive,resteasy-reactive-qute,hibernate-orm-panache,\
              jdbc-postgresql,flyway,smallrye-health,smallrye-openapi
cd my-app && ./mvnw quarkus:dev
```

### Typical pom.xml BOM block
```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>io.quarkus.platform</groupId>
      <artifactId>quarkus-bom</artifactId>
      <version>${quarkus.platform.version}</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>
```
Use `quarkus.platform.version` in `<properties>`. Check https://quarkus.io/blog/ for the
latest stable version when creating new projects.

### Datasource config
DevServices auto-starts PostgreSQL for `%dev`/`%test` when Docker is running — no config
needed. For production datasource, pool tuning, and Flyway setup, see `references/database-postgresql.md`.

## Common Quarkus gotchas

**Transactional boundaries** — `@Transactional` works on CDI beans, not on JAX-RS resources
directly in all edge cases. Prefer putting `@Transactional` on service methods rather than
resource methods. For read-only operations, `@Transactional(readOnly = true)` improves
connection pool efficiency.

**Reactive vs. imperative** — `resteasy-reactive` is the current recommended extension even
for blocking (imperative) code; it uses the blocking thread pool for non-async methods.
Don't mix `resteasy` and `resteasy-reactive` in the same project.

**CDI alternatives** — use `@Named` + `@Qualifier` rather than conditional beans where
possible; Quarkus's build-time CDI resolves ambiguity at compile time, not runtime, so
unsatisfied injection points are caught early (a feature, not a bug).

**Static resources** — place under `src/main/resources/META-INF/resources/`. The path
`/META-INF/resources/` maps to the web root automatically.

**Configuration secrets** — use `${ENV_VAR}` placeholders in `application.properties`; never
hardcode credentials. For local dev, an `.env` file in the project root is picked up
automatically by Quarkus Dev Mode (add to `.gitignore`).

**Native image** — if native compilation is needed, read the `references/project-structure.md`
file for GraalVM reflection config and Mandrel notes.

---

## Health and observability 

Adding `smallrye-health` gives `/q/health`, `/q/health/live`, `/q/health/ready` endpoints
automatically, with database readiness included when a datasource is configured.

Adding `smallrye-openapi` gives `/q/openapi` and `/q/swagger-ui` with zero configuration.

---

When you need more depth on any of these topics, read the relevant reference file listed
at the top before generating code.
