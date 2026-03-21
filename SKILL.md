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
license: MIT
metadata:
  author: Archton
  version: 2.0.0
---

# Quarkus + HTMX Expert Skill

You are an expert Quarkus developer. This skill covers the full Quarkus development
workflow: project setup, REST, CDI, Panache ORM, PostgreSQL, Qute + HTMX, testing,
configuration, messaging, OpenAPI, and the build/run lifecycle.

**Target stack**: Quarkus (latest stable) · Java 21 · Maven · PostgreSQL · Qute · HTMX

## Decision tree — find the right reference

```
What do you need?
├─ REST endpoints, Qute templates, HTMX patterns
│  └─ references/rest-and-htmx.md
├─ HTMX anti-patterns check
│  └─ references/htmx-anti-patterns.md
├─ Dependency injection (CDI / ArC)
│  └─ references/dependency-injection.md
├─ Application configuration (.properties, profiles, @ConfigMapping)
│  └─ references/project-structure.md  (Configuration section)
├─ Databases, ORM, Panache, Flyway
│  ├─ Panache entities/repos, datasource, migrations
│  │  └─ references/database-postgresql.md
│  └─ Advanced: multi-PU, multitenancy, caching, plain Hibernate
│     └─ references/advanced-orm.md
├─ OpenAPI and Swagger UI
│  └─ references/openapi.md
├─ Messaging and events (CDI events, Vert.x bus, Kafka/AMQP)
│  └─ references/messaging-and-events.md
├─ Testing
│  └─ references/testing.md
└─ Project structure, tooling, Dev Mode, CLI
   └─ references/project-structure.md
```

## Reference files — quick scan

- `references/rest-and-htmx.md` — JAX-RS, Qute templates, HTMX patterns, SSE, WebSocket, CSRF
- `references/htmx-anti-patterns.md` — HTMX anti-patterns to avoid (JSON responses, SPA state, polling abuse)
- `references/dependency-injection.md` — CDI/ArC: scopes, qualifiers, producers, interceptors, lifecycle
- `references/project-structure.md` — scaffolding, extensions, Dev Mode, configuration, CLI, tooling
- `references/database-postgresql.md` — datasource, Panache entities & repos, Flyway migrations
- `references/advanced-orm.md` — plain Hibernate ORM, multiple persistence units, multitenancy, caching
- `references/openapi.md` — @Operation, @Schema, Swagger UI, filters, multi-doc, CI artifacts
- `references/messaging-and-events.md` — CDI events, Vert.x event bus, Reactive Messaging (Kafka/AMQP)
- `references/testing.md` — @QuarkusTest, @TestProfile, RestAssured, Mockito, Testcontainers

Read only the reference file(s) relevant to the current task, not all of them.

**HTMX enforcement**: When generating HTMX code, always check `htmx-anti-patterns.md` first.
Server returns HTML, not JSON. Never rebuild DOM with client-side JavaScript. Detect `HX-Request`
header to return fragments vs full pages. If a solution mimics SPA architecture, restructure it.

---

## Core Principles

**Build-time magic, not runtime magic.** Quarkus moves reflection, classpath scanning, and
proxy generation to build time. Favour constructor injection over field injection where
testability matters. Don't rely on classpath scanning tricks that bypass the build-time processor.

**Dev Mode is your inner loop.** `./mvnw quarkus:dev` gives live reload and DevServices
(automatic Docker containers for PostgreSQL, etc.). Prefer running tests inside Dev Mode
(`quarkus.test.continuous-testing=enabled`) rather than separate `mvn test` runs during
development.

**application.properties is the single source of truth.** Profile-specific overrides live in
`%dev.`, `%test.`, `%prod.` prefixes. For groups of related properties, prefer `@ConfigMapping`
over individual `@ConfigProperty` fields — see `references/project-structure.md` Configuration section.

**Align extensions through the BOM.** Start with the smallest extension set, then add only
what the feature needs. Never mix `resteasy` and `resteasy-reactive` in the same project.

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

---

## Common gotchas

### Transactions and threading

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Writes don't persist | No `@Transactional` on service method | Add `@Transactional` at the service layer, not the resource |
| Event-loop blocked warning | Blocking code on IO thread | Use `@Blocking` or reactive APIs |
| `resteasy` + `resteasy-reactive` conflict | Both on classpath | Remove `resteasy`; use `resteasy-reactive` for everything |

### Configuration and resources

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Static files not served | Wrong directory | Place under `src/main/resources/META-INF/resources/` |
| Credentials in repo | Hardcoded secrets | Use `${ENV_VAR}` placeholders + `.env` file (gitignored) |
| Config change has no effect | Build-time-fixed property | Rebuild/repackage after changing |
| CDI ambiguity at startup | Multiple beans match | Use `@Qualifier` or `@Identifier`; Quarkus resolves at build time |

---

## Health and observability

`smallrye-health` → `/q/health`, `/q/health/live`, `/q/health/ready`
`smallrye-openapi` → `/q/openapi`, `/q/swagger-ui`

---

When you need more depth on any topic, read the relevant reference file listed above
before generating code.
