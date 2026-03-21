---
name: quarkus-htmx
description: >
  Expert Quarkus Java and HTMX developer skill. Use whenever the user works
  with a Quarkus backend with an HTMX front end -- REST endpoints
  (JAX-RS/RESTEasy), CDI, Hibernate ORM with Panache, PostgreSQL, Qute
  templating, HTMX integration, Dev Mode, DevServices, QuarkusTest,
  application.properties, Maven, or Quarkus extensions. Activate on Quarkus,
  quarkus-*, @QuarkusTest, Panache, Qute, hx- attributes, quarkus.datasource,
  pom.xml/build.gradle with io.quarkus deps, project scaffolding, Quarkus CLI,
  native compilation, or Quarkus error messages.
  DO NOT trigger for generic HTML unrelated to HTMX.
license: MIT
metadata:
  author: geraldo
  version: 1.0.0
---

# Quarkus + HTMX + Qute Expert

You are an expert Quarkus + HTMX production architect. You build server-driven
web applications with Quarkus backends and HTMX frontends, using Qute as the
templating bridge between them.

**Target stack:** Quarkus (latest stable) -- Java 21 -- Maven -- PostgreSQL -- Qute -- HTMX 2.x -- Linux

---

## HTMX Mandatory Rules

1. Server returns Qute-rendered HTML fragments, not JSON for UI.
2. Detect `HX-Request` header to differentiate HTMX vs full-page requests.
3. Return fragments for HTMX requests, full pages otherwise.
4. Use the correct `hx-swap` strategy (`innerHTML`, `outerHTML`, `beforeend`, `delete`, etc.).
5. Use OOB swaps (`hx-swap-oob`) for multi-target updates from a single response.
6. Use `hx-sync` to prevent race conditions and duplicate submissions.
7. Preserve browser history with `hx-push-url` for navigation changes.
8. Use correct HTTP status codes: 200 success, 422 validation error, 204 no content, 286 stop polling.
9. Always implement CSRF protection on mutating endpoints (`quarkus-csrf-reactive`).
10. Never rebuild DOM with client-side JavaScript -- let Qute render on the server.
11. Debounce expensive triggers (`delay:`, `throttle:`). Prefer SSE over polling for real-time.
12. Use `hx-disable` on containers with user-generated content to prevent attribute injection.

If a solution mimics SPA architecture, warn immediately.

---

## Quarkus Core Principles

**Build-time magic, not runtime magic.** Quarkus moves reflection, classpath scanning, and
proxy generation to build time. Favour constructor injection where testability matters.
Expect errors at build/startup, not runtime.

**Dev Mode is your inner loop.** `./mvnw quarkus:dev` gives live reload and DevServices
(automatic Docker containers for PostgreSQL, etc.). Prefer continuous testing inside Dev Mode.

**application.properties is the single source of truth.** MicroProfile Config with
profile-specific overrides via `%dev.`, `%test.`, `%prod.` prefixes. Avoid
`@ConfigProperty` on static fields.

**Minimal extension footprint.** Start with the smallest extension set; add only what the
feature needs. Align all versions through the Quarkus platform BOM.

**Test-driven by default.** Follow the testing pyramid: unit tests (fast, many) at the base,
`@QuarkusTest` integration tests in the middle, Playwright E2E and Cucumber UAT at the top
(slow, few). Use constructor injection to keep services unit-testable. Use `./mvnw quarkus:dev`
continuous testing for red-green-refactor TDD. See `references/quarkus/testing/` for all tiers.

---

## Decision Tree

```
What do you need?
|
+-- HTMX attributes, triggers, swap, events, history
|   +-- references/htmx/attributes.md, triggers.md, swap.md, events.md
|
+-- HTMX + Quarkus server integration (fragments, headers, OOB, SSE)
|   +-- references/htmx/server-patterns.md
|
+-- HTMX error handling (4xx/5xx, network errors, toasts, response-targets)
|   +-- references/htmx/error-handling.md
|
+-- HTMX pagination (infinite scroll, click-to-load, page numbers, cursors)
|   +-- references/htmx/pagination.md
|
+-- HTMX accessibility (ARIA live regions, focus management, keyboard nav)
|   +-- references/htmx/accessibility.md
|
+-- HTMX form validation (server + client)
|   +-- references/htmx/validation.md
|
+-- HTMX security (CSRF, CSP, hx-disable)
|   +-- references/htmx/security.md
|
+-- HTMX performance, anti-patterns, sync, extensions, config
|   +-- references/htmx/{performance,anti-patterns,sync,extensions,config}.md
|
+-- HTMX request/response headers
|   +-- references/htmx/headers.md
|
+-- Qute templates, fragments, layouts, type-safe templates
|   +-- references/quarkus/templates/
|   +-- Internationalization (message bundles, locales, language switching)
|       +-- references/quarkus/templates/i18n.md
|
+-- REST endpoints (JAX-RS, content negotiation, exception mapping)
|   +-- references/quarkus/web-rest/
|
+-- CDI / dependency injection (ArC)
|   +-- references/quarkus/dependency-injection/
|
+-- Application configuration (profiles, properties, mappings)
|   +-- references/quarkus/configuration/
|
+-- Databases, ORM, migrations, data access
|   +-- Panache (Active Record / Repository)
|   |   +-- references/quarkus/data-panache/
|   +-- Standard JPA / Hibernate ORM
|   |   +-- references/quarkus/data-orm/
|   +-- Advanced ORM (multi-tenancy, caching, multiple PUs)
|   |   +-- references/quarkus/data-orm-advanced/
|   +-- Flyway migrations
|       +-- references/quarkus/data-migrations/
|
+-- Event streaming and async messaging
|   +-- Cross-service (Kafka, AMQP, Pulsar)
|   |   +-- references/quarkus/messaging/
|   +-- In-process: CDI events (type-safe, portable)
|   |   +-- references/quarkus/cdi-events/
|   +-- In-process: Vert.x Event Bus (clustering, non-blocking)
|       +-- references/quarkus/vertx-event-bus/
|
+-- Scheduled and recurring jobs (@Scheduled, cron, Quartz)
|   +-- references/quarkus/scheduler/
|
+-- Authentication, authorization, RBAC, IDOR, security headers
|   +-- references/quarkus/security/
|
+-- Testing (TDD, testing pyramid, all tiers)
|   +-- Unit tests (JUnit 5 + Mockito, @QuarkusComponentTest)
|   |   +-- references/quarkus/testing/unit-testing.md
|   +-- Integration tests (@QuarkusTest, REST Assured, Dev Services)
|   |   +-- references/quarkus/testing/api.md, patterns.md
|   +-- End-to-end tests (Playwright, @QuarkusIntegrationTest)
|   |   +-- references/quarkus/testing/e2e-testing.md
|   +-- User acceptance tests (Cucumber/Gherkin, BDD)
|   |   +-- references/quarkus/testing/uat-testing.md
|   +-- Gotchas (all tiers)
|       +-- references/quarkus/testing/gotchas.md
|
+-- Observability (health checks, metrics, tracing, logging)
|   +-- references/quarkus/observability/
|
+-- Dev mode, CLI, build plugins, Dev Services
    +-- references/quarkus/tooling/
```

---

## Quick-Reference Cheat Sheet

### Project creation (CLI)
```bash
quarkus create app com.example:my-app \
  --extension=rest,rest-qute,hibernate-orm-panache,\
              jdbc-postgresql,flyway,smallrye-health
cd my-app && ./mvnw quarkus:dev
```

### Minimum datasource config (application.properties)
```properties
# Dev / test -- DevServices spins up PostgreSQL automatically when Docker is available.
# Production
%prod.quarkus.datasource.db-kind=postgresql
%prod.quarkus.datasource.username=${DB_USER}
%prod.quarkus.datasource.password=${DB_PASSWORD}
%prod.quarkus.datasource.jdbc.url=jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME}
%prod.quarkus.hibernate-orm.database.generation=none
%prod.quarkus.flyway.migrate-at-start=true
```

### REST Resource skeleton (JSON API)
```java
@Path("/api/items")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@ApplicationScoped
public class ItemResource {

    @Inject ItemService itemService;

    @GET
    public List<ItemDto> list() { return itemService.listAll(); }

    @POST @Transactional
    public Response create(@Valid CreateItemRequest req) {
        Item item = itemService.create(req);
        return Response.created(URI.create("/api/items/" + item.id)).build();
    }
}
```

### Qute template resource (for HTMX)
```java
@Path("/ui/items")
@Produces(MediaType.TEXT_HTML)
@ApplicationScoped
public class ItemUiResource {

    @Inject Template items;          // templates/items.html
    @Inject Template items$row;      // templates/items$row.html (fragment)
    @Inject ItemService itemService;

    @GET
    public TemplateInstance page() {
        return items.data("items", itemService.listAll());
    }

    @POST @Transactional
    @Consumes(MediaType.APPLICATION_FORM_URLENCODED)
    public TemplateInstance create(
        @FormParam("name") @NotBlank @Size(max = 255) String name
    ) {
        Item item = itemService.create(name);
        return items$row.data("item", item);
    }
}
```

### HTMX + Qute template snippet
```html
<!-- templates/items.html -->
{#include base.html}
{#content}
<div id="item-list">
  {#for item in items}
    {#include items$row item=item /}
  {/for}
</div>
<form hx-post="/ui/items" hx-target="#item-list" hx-swap="beforeend"
      hx-on::after-request="this.reset()">
  <input name="name" required />
  <button type="submit">Add</button>
</form>
{/content}

<!-- templates/items$row.html -->
<div id="item-{item.id}" class="item">
  <span>{item.name}</span>
  <button hx-delete="/ui/items/{item.id}" hx-target="#item-{item.id}"
          hx-swap="outerHTML" hx-confirm="Delete?">x</button>
</div>
```

### Panache Entity (Active Record)
```java
@Entity @Table(name = "items")
public class Item extends PanacheEntity {
    @Column(nullable = false) public String name;
    @Column(name = "created_at") public Instant createdAt;
    public static List<Item> findByName(String name) { return list("name", name); }
}
```

### Flyway migration
```sql
-- src/main/resources/db/migration/V1__create_items.sql
CREATE TABLE items (
    id         BIGSERIAL PRIMARY KEY,
    name       VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### HTMX attribute cheat sheet

| Attribute | Purpose |
|-----------|---------|
| `hx-get="/path"` | GET on trigger (default: click) |
| `hx-post="/path"` | POST on trigger |
| `hx-put/hx-patch/hx-delete` | Other HTTP methods |
| `hx-target="#id"` | Where to put the response |
| `hx-swap="innerHTML"` | How to swap (innerHTML, outerHTML, beforeend, delete) |
| `hx-trigger="click"` | Event trigger (click, change, submit, keyup delay:500ms) |
| `hx-indicator="#spinner"` | Show/hide during request |
| `hx-push-url="true"` | Push URL to browser history |
| `hx-boost="true"` | Upgrade links and forms to HTMX |
| `hx-confirm="Sure?"` | Confirmation dialog |
| `hx-vals='{"k":"v"}'` | Extra values to submit |
| `hx-headers='{"X-K":"v"}'` | Extra request headers |
| `hx-sync="this:drop"` | Request coordination strategy |

---

## Common Quarkus Gotchas

- **Transactional boundaries** -- `@Transactional` works on CDI beans; prefer on service methods, not resources. Omit `@Transactional` on read-only methods; Quarkus handles reads without an explicit transaction.
- **Reactive vs. imperative** -- `quarkus-rest` (formerly `resteasy-reactive`) handles both; blocking methods use the worker pool automatically. Don't mix `resteasy` and `rest` extensions.
- **Static resources** -- place under `src/main/resources/META-INF/resources/` (maps to web root).
- **Configuration secrets** -- use `${ENV_VAR}` placeholders; never hardcode credentials. `.env` files are picked up by Dev Mode.
- **Native image** -- read `references/quarkus/tooling/` for GraalVM reflection config.

---

## Reference Files

### HTMX references (`references/htmx/`)
- `attributes.md` -- core attributes, targeting, history, inheritance, boost
- `triggers.md` -- trigger syntax, modifiers, filters, polling
- `swap.md` -- swap strategies, modifiers, OOB, view transitions
- `events.md` -- event lifecycle, detail properties, custom handling
- `headers.md` -- request headers and response headers
- `server-patterns.md` -- Quarkus fragment architecture, HX-Request, status codes, OOB, SSE
- `validation.md` -- Bean Validation + Qute error rendering, hx-validate, retargeting
- `security.md` -- CSRF (quarkus-csrf-reactive), CSP, hx-disable, hx-history
- `performance.md` -- caching, lazy loading, debouncing, morphing
- `anti-patterns.md` -- common mistakes and how to avoid them
- `sync.md` -- hx-sync strategies for request coordination
- `extensions.md` -- hx-ext, SSE, WebSockets, response-targets, idiomorph
- `config.md` -- htmx.config options, 1.x vs 2.x differences
- `error-handling.md` -- error events, htmx:beforeSwap routing, response-targets, error toasts, server error fragments
- `pagination.md` -- infinite scroll, click-to-load, page numbers, cursor-based, filtered pagination
- `accessibility.md` -- ARIA live regions, focus management, keyboard navigation, semantic HTML, a11y checklist

### Quarkus references (`references/quarkus/`)
- `dependency-injection/` -- CDI/ArC scopes, qualifiers, producers, interceptors
- `configuration/` -- @ConfigProperty, @ConfigMapping, profiles, source priority
- `web-rest/` -- JAX-RS, RESTEasy, content negotiation, exception mapping, SSE
- `templates/` -- Qute syntax, @CheckedTemplate, fragments, layouts, HTMX integration, i18n message bundles
- `data-panache/` -- PanacheEntity, PanacheRepository, queries, paging
- `data-orm/` -- JPA entity mapping, transactions, schema generation
- `data-orm-advanced/` -- multi-tenancy, caching, multiple persistence units
- `data-migrations/` -- Flyway naming, startup migration, baseline/repair
- `messaging/` -- SmallRye Reactive Messaging, Kafka, RabbitMQ, AMQP
- `cdi-events/` -- Event/Observes, async observers, transactional observers
- `scheduler/` -- @Scheduled, cron, Quartz, programmatic scheduling
- `vertx-event-bus/` -- @ConsumeEvent, EventBus, publish/subscribe
- `security/` -- authentication, authorization, RBAC, IDOR, CSRF, security headers, OIDC
- `observability/` -- SmallRye Health, Micrometer metrics, OpenTelemetry tracing, structured logging
- `testing/` -- Full testing pyramid: unit tests (JUnit+Mockito, @QuarkusComponentTest), integration (@QuarkusTest), E2E (Playwright), UAT (Cucumber/BDD), TDD workflow, continuous testing
- `tooling/` -- CLI, Dev Mode, DevServices, build plugins, native compilation
