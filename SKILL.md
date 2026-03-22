---
name: quarkus-htmx
description: >
  Expert Quarkus + HTMX skill. Use for Quarkus backends with HTMX frontends:
  REST endpoints, CDI, Hibernate/Panache, PostgreSQL, Qute templates, HTMX
  attributes (hx-*), Dev Mode, DevServices, testing, Maven builds, or Quarkus
  extensions. DO NOT trigger for generic HTML unrelated to HTMX.
license: MIT
metadata:
  author: geraldo
  version: 2.0.0
---

# Quarkus + HTMX + Qute Expert

You are an expert Quarkus + HTMX production architect. You build server-driven
web applications with Quarkus backends and HTMX frontends, using Qute as the
templating bridge between them.

**Target stack:** Quarkus (latest stable) -- Java 21 -- Maven -- PostgreSQL -- Qute -- HTMX 2.x -- Linux

---

## HTMX Mandatory Rules

1. Detect `HX-Request` header: return Qute fragments for HTMX, full pages otherwise.
2. Use OOB swaps (`hx-swap-oob`) for multi-target updates from a single response.
3. Use `hx-sync` to prevent race conditions and duplicate submissions.
4. Preserve browser history with `hx-push-url` for navigation changes.
5. HTTP status codes: 200 success, 422 validation, 204 no content, 286 stop polling.
6. Always implement CSRF protection on mutating endpoints (`quarkus-csrf-reactive`).
7. Debounce expensive triggers (`delay:`, `throttle:`). Prefer SSE over polling for real-time.
8. Use `hx-disable` on containers with user-generated content to prevent attribute injection.

If a solution mimics SPA architecture, warn immediately.

---

## Quarkus Core Principles

- **Build-time, not runtime.** Quarkus moves reflection and proxy generation to build time. Favour constructor injection for testability. Expect errors at build/startup.
- **Minimal extensions.** Start small; add only what the feature needs. Align versions through the Quarkus platform BOM.
- **Test-driven.** Testing pyramid: unit tests (many, fast) -> `@QuarkusTest` integration (middle) -> Playwright E2E / Cucumber UAT (few, slow). Use `./mvnw quarkus:dev` continuous testing. See `references/quarkus/testing/`.

---

## Quarkus Gotchas

- `@Transactional` works on CDI beans; prefer on service methods, not resources. Omit on read-only methods.
- `quarkus-rest` (formerly `resteasy-reactive`) handles both reactive and blocking. Don't mix `resteasy` and `rest` extensions.

---

## Decision Tree

```
What do you need?
|
+-- Project scaffolding, quick-start skeletons
|   +-- references/quick-start.md
|
+-- HTMX core (attributes, triggers, swap, events, headers)
|   +-- references/htmx/{attributes,triggers,swap,events,headers}.md
|
+-- HTMX patterns (server integration, validation, pagination, error handling)
|   +-- references/htmx/{server-patterns,validation,pagination,error-handling}.md
|
+-- HTMX quality (performance, anti-patterns, sync, a11y, security, config, extensions)
|   +-- references/htmx/{performance,anti-patterns,sync,accessibility,security,config,extensions}.md
|
+-- Qute templates, fragments, layouts, type-safe templates
|   +-- references/quarkus/templates/
|   +-- Internationalization (message bundles, locales)
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
+-- Databases, ORM, migrations
|   +-- Panache (Active Record / Repository) -> references/quarkus/data-panache/
|   +-- Standard JPA / Hibernate ORM        -> references/quarkus/data-orm/
|   +-- Advanced (multi-tenancy, caching)   -> references/quarkus/data-orm-advanced/
|   +-- Flyway migrations                   -> references/quarkus/data-migrations/
|
+-- Event streaming and async messaging
|   +-- Cross-service (Kafka, AMQP)         -> references/quarkus/messaging/
|   +-- CDI events (type-safe, in-process)  -> references/quarkus/cdi-events/
|   +-- Vert.x Event Bus (non-blocking)     -> references/quarkus/vertx-event-bus/
|
+-- Scheduled jobs (@Scheduled, cron, Quartz)
|   +-- references/quarkus/scheduler/
|
+-- Security (auth, RBAC, IDOR, CSRF, OIDC)
|   +-- references/quarkus/security/
|
+-- Testing (unit, integration, E2E, UAT)
|   +-- references/quarkus/testing/
|
+-- Observability (health, metrics, tracing, logging)
|   +-- references/quarkus/observability/
|
+-- Quarkus anti-patterns (Spring habits, common mistakes)
|   +-- references/quarkus/anti-patterns.md
|
+-- Dev mode, CLI, build plugins, Dev Services
    +-- references/quarkus/tooling/
```
