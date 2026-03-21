# Skill Review: quarkus-htmx (v1.0.0)

**Reviewer posture:** Software architect / senior developer
**Date:** 2026-03-21
**Scope:** Structure, logic, completeness, gap analysis against official docs and competing skills

---

## Executive Summary

This is an exceptionally well-crafted Claude Code skill. It covers the Quarkus + HTMX + Qute stack with a depth and organization that surpasses every competing skill found on GitHub, cursor.directory, and the Mindrally/skills repository. The modular `references/` architecture with api/patterns/gotchas triads is a textbook example of progressive disclosure. However, there are identifiable gaps -- primarily in missing HTMX attributes, absent Quarkus security/observability modules, and a few Qute features omitted from the templates reference.

**Overall rating: 8.5/10** -- production-grade, with targeted gaps that can be closed.

---

## 1. Structural Alignment with Claude Code Skill Best Practices

### What the best practices say

Based on the official Anthropic skills documentation, the `skill-creator` reference skill, and community analysis:

| Guideline | Recommendation | This Skill |
|-----------|---------------|------------|
| Frontmatter | `name` + `description` required; description drives trigger matching | Present and well-written |
| SKILL.md body | <500 lines ideal; acts as the "level 2" prompt | **306 lines** -- well within budget |
| Progressive disclosure | 3 levels: metadata (~100 words), SKILL.md body, bundled references | Fully implemented |
| Reference files | Unlimited size, loaded on demand via decision tree | 55 reference files, well-organized |
| Description budget | ~15,000 chars total across all skills; must include trigger keywords | Description is 450 chars -- efficient |
| Decision tree | Route Claude to the right reference file | Excellent ASCII tree in SKILL.md |

### Structural verdict: EXCELLENT

The skill follows the canonical 3-level progressive disclosure model precisely:

1. **Level 1 (always loaded):** The YAML frontmatter description (450 chars) with rich trigger keywords
2. **Level 2 (on trigger):** The SKILL.md body (306 lines) with mandatory rules, core principles, decision tree, cheat sheet, and gotchas
3. **Level 3 (on demand):** 55 reference files in `references/` organized by domain

The `references/` directory uses a clean `{domain}/{topic}/{api,patterns,gotchas}.md` structure that mirrors how developers think about problems: "What API do I use?" -> "What patterns work?" -> "What can go wrong?"

### Minor structural issues

1. **No `allowed-tools` in frontmatter.** The skill doesn't declare tool permissions. For a skill that may need to run Maven commands, create files, or read templates, explicitly declaring `allowed-tools` (e.g., `Bash(./mvnw:*), Read, Write, Glob`) would be more secure and explicit.

2. **No `user-invocable` field.** If this skill should appear in the `/` menu, it needs `user-invocable: true` in frontmatter. Currently it's only model-invocable.

3. **The `license` and `metadata` fields** in frontmatter are non-standard. While harmless, they aren't part of the official schema (`name`, `description`, `allowed-tools`, `user-invocable`, `disable-model-invocation`, `context`, `agent`, `model`, `effort`, `argument-hint`, `hooks`). Some validators may warn on these.

4. **Description style.** Anthropic recommends writing descriptions in **third person** ("Expert Quarkus + HTMX production architect" is fine) and making them "slightly pushy" since Claude tends to under-trigger skills. The current description is well-keyworded but could be more assertive about when to activate. Consider adding explicit negative triggers (the "DO NOT trigger for generic HTML" is good practice already present).

5. **Reference file depth.** Anthropic warns that deeply nested references (file A links to file B links to file C) cause Claude to only partially read files. This skill correctly keeps all references one level deep from SKILL.md -- no chaining issues found.

---

## 2. Logical Ordering and Redundancy Analysis

### Ordering: STRONG

The SKILL.md follows a logical top-down flow:

```
Persona/Identity -> Mandatory Rules -> Core Principles -> Decision Tree -> Cheat Sheet -> Gotchas -> Reference Index
```

This is the correct order: identity first (who am I?), constraints second (what must I always do?), then navigation (where do I find details?), then quick reference (common patterns), then pitfalls (what to watch out for), and finally the full reference map.

### Redundancy analysis

| Concern | Severity | Details |
|---------|----------|---------|
| Cheat sheet duplicates reference content | Low | The HTMX attribute cheat sheet in SKILL.md overlaps with `references/htmx/attributes.md`. This is **intentional and correct** -- the cheat sheet is quick-reference for common cases while the reference is exhaustive. |
| Server-patterns.md overlaps with web-rest/patterns.md | Low | Both cover HTMX response headers and fragment patterns. The overlap is acceptable because they approach from different angles (HTMX-first vs REST-first). |
| OOB swaps documented in 3 places | Medium | OOB swaps appear in `swap.md`, `server-patterns.md`, and `templates/patterns.md`. Consider consolidating to one canonical location with cross-references. |
| CSRF documented in 2 places | Low | Covered in both `security.md` and `templates/patterns.md`. Acceptable as they serve different contexts (security review vs implementation recipe). |

### Redundancy verdict: ACCEPTABLE

The redundancy is largely intentional progressive disclosure. Each layer provides the right level of detail for its context. The OOB-swaps triple-coverage is the only case that could benefit from consolidation.

---

## 3. HTMX Content: Gap Analysis

### Comparison sources
- **Official htmx docs** (htmx.org)
- **Context7 htmx documentation**
- **ercan-er/htmx-claude-skill** (GitHub) -- the closest competitor, a production-grade modular HTMX skill
- **awesome-cursorrules** HTMX variants (basic, Flask, Django, Go)
- **htmx 2.0 release notes and migration guide**

### Coverage assessment

| HTMX Feature | Covered? | Notes |
|---------------|----------|-------|
| Core request attributes (get/post/put/patch/delete) | YES | Complete |
| hx-target (extended selectors) | YES | Complete including closest/find/next/previous |
| hx-swap (all strategies) | YES | All 9 strategies documented |
| hx-trigger (modifiers, filters, polling) | YES | Comprehensive |
| hx-sync | YES | Dedicated file with all strategies |
| hx-boost | YES | With head-support note |
| hx-push-url / hx-replace-url | YES | In attributes.md |
| hx-history / hx-history-elt | YES | In attributes.md |
| hx-confirm | YES | |
| hx-include | YES | |
| hx-vals | YES | |
| hx-headers | YES | |
| hx-indicator / hx-disabled-elt | YES | |
| hx-preserve | YES | |
| hx-ext | YES | Dedicated extensions.md |
| hx-validate | YES | In validation.md |
| hx-encoding | YES | Brief mention |
| hx-on:event (2.x syntax) | YES | |
| hx-select / hx-select-oob | YES | In attributes.md |
| hx-swap-oob | YES | In swap.md |
| View transitions | YES | In swap.md |
| Events lifecycle | YES | Complete lifecycle table |
| Request/response headers | YES | Dedicated headers.md |
| htmx.config options | YES | Dedicated config.md |
| 1.x vs 2.x migration | YES | In config.md |
| Extensions (SSE, WS, idiomorph, etc.) | YES | Dedicated extensions.md |
| Security (CSRF, CSP, hx-disable) | YES | Dedicated security.md |
| Anti-patterns | YES | Dedicated file |
| Performance | YES | Dedicated file |
| Accessibility | YES | In anti-patterns.md |

### GAPS IDENTIFIED

| Missing Feature | Severity | Details |
|----------------|----------|---------|
| **`hx-params`** | **HIGH** | Controls which parameters are submitted with a request. Supports `*` (all), `none`, `not <list>`, `<list>`. Essential for form control. Not mentioned anywhere in the skill. |
| **`hx-disinherit`** | **MEDIUM** | Allows child elements to opt out of inherited attributes. Important for complex layouts. Not documented. |
| **`hx-inherit`** | **LOW** | Explicit inheritance control (2.x). Not documented but rarely needed since inheritance is the default. |
| **`hx-request`** | **LOW** | Configure request behavior (timeout, credentials, noHeaders). Not documented. |
| **`hx-prompt`** | **LOW** | Mentioned only as a header value in headers.md, but the attribute itself isn't documented in attributes.md. |
| **Web Components / Shadow DOM** | **MEDIUM** | HTMX 2.x added improved Shadow DOM support. Not mentioned in the skill. This is a significant 2.x feature. |
| **`htmx.ajax()` API** | **LOW** | Programmatic HTMX request API. Not documented. Useful for edge cases. |
| **`htmx:beforeProcessNode` event** | **LOW** | Event for intercepting htmx processing. Missing from events.md. |
| **Multi-swap extension** | **LOW** | Alternative to OOB for multi-target swaps. Not mentioned in extensions.md. |
| **`restored` extension** | **LOW** | Detects history restoration. Not mentioned. |
| **DELETE request body change in 2.x** | **MEDIUM** | HTMX 2.x changed DELETE to use URL parameters instead of form-encoded body. This breaking change is not documented in config.md's 1.x vs 2.x table. |
| **`htmx.config.scrollBehavior` change** | **LOW** | Changed from 'smooth' to 'instant' in 2.x. Not in the migration table. |
| **`htmx:confirm` event** | **MEDIUM** | Fires before element is triggered, enables async confirmation dialogs (e.g., SweetAlert) via `evt.detail.issueRequest()`. Key pattern for custom confirmation UIs. Missing from events.md. |
| **`htmx-1-compat` extension** | **MEDIUM** | Restores 1.x behaviors (deprecated `hx-sse`/`hx-ws`, old `hx-on`, smooth scroll, form-encoded DELETE). Critical migration tool not mentioned. |
| **`ignoreTitle` swap modifier** | **LOW** | `hx-swap="outerHTML ignoreTitle:true"` prevents title updates from response. Missing from swap.md. |
| **`HX-Location` JSON format** | **LOW** | `HX-Location` accepts a JSON object with `path`, `target`, `swap`, `values`, `headers` for full client-side navigation control. Skill only shows simple string usage. |
| **XHR progress events** | **LOW** | `htmx:xhr:loadstart`, `htmx:xhr:progress`, `htmx:xhr:loadend` for upload progress bars. Missing from events.md. |
| **Missing extensions** | **LOW** | `class-tools` (CSS class timing), `remove-me` (auto-remove after delay), `path-deps` (path-based refresh), `event-header`, `method-override`. |
| **WS/SSE event lifecycle** | **LOW** | WebSocket events (`htmx:wsOpen`, `htmx:wsClose`, etc.) and SSE events (`htmx:sseOpen`, `htmx:sseError`) not documented in extensions.md. |

### Competitor comparison

vs **ercan-er/htmx-claude-skill**: Similar modular structure with nearly identical reference file names. This skill adds Quarkus/Qute integration that the competitor lacks entirely. The competitor is HTMX-only with Express.js examples. **This skill wins on integration depth.**

vs **awesome-cursorrules HTMX variants**: The cursorrules are superficial (10-20 lines of bullet points). This skill is orders of magnitude more detailed. **No contest.**

vs **Mindrally/skills java-quarkus-development**: A shallow 150-line bullet-point skill with no reference files, no HTMX content, no Qute content. **This skill is dramatically more comprehensive.**

---

## 4. Quarkus Content: Gap Analysis

### Comparison sources
- **Context7 Quarkus documentation**
- **cursor.directory Quarkus rules** (by Xinhua Gu)
- **Mindrally/skills java-quarkus-development**
- **Official Quarkus guides**

### Module coverage assessment

| Quarkus Domain | Module | api.md | patterns.md | gotchas.md | Quality |
|---------------|--------|--------|-------------|------------|---------|
| CDI / ArC | dependency-injection/ | YES | YES | YES | Excellent -- covers ArC-specific features like @DefaultBean, @IfBuildProfile, @Lock, @All, InterceptionProxy |
| Configuration | configuration/ | YES | YES | YES | Excellent -- includes env var naming rules, secret expressions, config tracking |
| REST | web-rest/ | YES | YES | YES | Excellent -- covers REST Client, form handling, multipart, SSE |
| Qute Templates | templates/ | YES | YES | YES | Very good -- see Qute-specific gaps below |
| Panache | data-panache/ | YES | YES | YES | Excellent -- active record + repository, projections, paging, locking |
| Hibernate ORM | data-orm/ | YES | YES | YES | Good -- basic JPA coverage, schema strategies |
| Advanced ORM | data-orm-advanced/ | YES (only) | - | - | Good -- multi-tenancy, caching, named PUs, Jakarta Data |
| Flyway | data-migrations/ | YES (only) | - | - | Good -- baseline, repair, named datasources |
| Messaging | messaging/ | YES (only) | - | - | Good -- Kafka, channel model, pausable channels |
| CDI Events | cdi-events/ | YES (only) | - | - | Good -- transactional observers, qualified events |
| Scheduler | scheduler/ | YES (only) | - | - | Good -- @Scheduled, cron, Quartz, programmatic |
| Vert.x Event Bus | vertx-event-bus/ | YES (only) | - | - | Good -- @ConsumeEvent, clustering |
| Testing | testing/ | YES (only) | - | - | Good -- @QuarkusTest, @InjectMock, test profiles |
| Tooling | tooling/ | YES (only) | - | - | Good -- CLI, Dev UI, project layout, extensions |

### GAPS IDENTIFIED

| Missing Topic | Severity | Details |
|--------------|----------|---------|
| **Quarkus Security (authentication/authorization)** | **CRITICAL** | No `references/quarkus/security/` module exists. Missing: `@RolesAllowed`, `@Authenticated`, `@PermissionsAllowed`, `SecurityIdentity`, HTTP Security Policy, form-based auth, basic auth. The SKILL.md mentions CSRF but not application-level security. Every competing Quarkus skill (cursor.directory, Mindrally) covers security. |
| **OIDC / OAuth2 / JWT** | **HIGH** | No coverage of `quarkus-oidc`, `quarkus-smallrye-jwt`, Keycloak integration, token verification, or OIDC Dev Services. Critical for any production web app. |
| **Health checks (SmallRye Health)** | **HIGH** | Listed in tooling's recommended extensions but no reference module. Missing: `@Liveness`, `@Readiness`, `@Startup`, custom health checks, Kubernetes probe integration. |
| **Metrics (Micrometer)** | **MEDIUM** | Listed in tooling's recommended extensions but no reference module. Missing: Micrometer registry setup, custom metrics, Prometheus endpoint. |
| **OpenTelemetry / Tracing** | **MEDIUM** | Not mentioned at all. Modern Quarkus uses OpenTelemetry (not SmallRye OpenTracing). |
| **Logging** | **MEDIUM** | Scattered log config hints in various gotchas files but no dedicated logging reference. Missing: structured logging, JSON logging, log categories, centralized log configuration patterns. |
| **Native image compilation** | **MEDIUM** | Mentioned in SKILL.md gotchas ("read references/quarkus/tooling/") and tooling lists GraalVM, but no dedicated native-image reference covering `@RegisterForReflection`, reflection-config.json, common native build failures, multi-stage Docker builds. |
| **Docker / Containerization** | **LOW** | No container-image extension coverage. The Mindrally skill covers multi-stage Dockerfiles and distroless images. |
| **Error handling patterns** | **LOW** | Exception mappers are in web-rest but there's no unified error-handling strategy for HTMX (toast notifications, error boundaries, retry patterns). |
| **Liquibase alternative** | **LOW** | Only Flyway is covered. Some teams prefer Liquibase. |
| **Reactive SQL clients** | **LOW** | Only JDBC/Panache blocking model covered. No `quarkus-reactive-pg-client` or reactive Panache coverage. |
| **Fault Tolerance** | **MEDIUM** | No coverage of `quarkus-smallrye-fault-tolerance`: `@Retry`, `@Timeout`, `@CircuitBreaker`, `@Fallback`, `@Bulkhead`, `@RateLimit`. Essential for microservice resilience and REST Client calls. |
| **WebSockets (quarkus-websockets-next)** | **MEDIUM** | The modern Quarkus WebSocket API (`@WebSocket`, `@OnTextMessage`) is not covered. Relevant since HTMX supports WebSockets via `hx-ext="ws"` and the skill's extensions.md documents the client side. |
| **Application Caching (quarkus-cache)** | **MEDIUM** | `@CacheResult`, `@CacheInvalidate`, `@CacheKey`, Caffeine config. Different from Hibernate 2nd-level cache (which is covered). Performance.md mentions `@CacheResult` in a Qute context but no dedicated coverage. |
| **OpenAPI / Swagger** | **LOW** | `quarkus-smallrye-openapi` is listed in tooling's recommended extensions but no module covers `@Operation`, `@Tag`, `@Schema`, Swagger UI, or API-first development. |
| **Kubernetes / Deployment** | **LOW** | No coverage of `quarkus-kubernetes` auto-generated manifests, container image extensions, health probe wiring, or Knative serverless deployment. |
| **Patterns/gotchas files for modules 5-13** | **MEDIUM** | The last 9 modules (data-orm-advanced through tooling) only have api.md, missing patterns.md and gotchas.md. This creates an inconsistency with the first 4 modules which have all three. |

### Positive differentiators vs competitors

1. **Decision trees** for messaging (CDI events vs Vert.x event bus vs Reactive Messaging) are unique and excellent.
2. **Gotchas tables** with symptom/cause/fix columns are more actionable than any competitor.
3. **Configuration reference tables** with "Use when" columns provide excellent guidance.
4. **Cross-references** between modules ("See Also" sections) help navigation.

---

## 5. Qute Content: Gap Analysis

### Comparison sources
- **Context7 Qute documentation** (quarkus.io/guides/qute, qute-reference)
- **Official Qute reference guide**

### GAPS IDENTIFIED

| Missing Feature | Severity | Details |
|----------------|----------|---------|
| **`{#when}` / `{#switch}` section** | **HIGH** | Qute's conditional matching section (like Java's switch) with `{#is}`, `{#case}`, operator-based comparisons, and enum matching. Not documented anywhere in the skill. |
| **`@TemplateGlobal`** | **HIGH** | Defines global variables accessible in any template via the `global:` namespace. Extremely useful for things like current user, app name, feature flags. Not mentioned. |
| **`{#eval}` section** | **MEDIUM** | Dynamic template evaluation. Allows parsing and evaluating template strings at runtime. Not documented. |
| **`{#cache}` section** | **LOW** | Built-in template fragment caching. Not documented. |
| **`{#let}` section** | **MEDIUM** | Local variable binding in templates. Mentioned briefly in gotchas as an alternative to `with`, but not documented as a feature. |
| **`orEmpty` virtual method** | **LOW** | Returns empty collection instead of null. Documented in official docs, missing from skill. |
| **`{#when}` operators** | **MEDIUM** | `gt`, `ge`, `lt`, `le`, `ne`, `eq`, `in`, `!in` operators for the when section. |
| **`{#if}` full operator set** | **LOW** | Skill shows basic `>` comparison but doesn't document `&&`, `||`, `eq`, `ne`, `!`, `>=`, `<=`, `instanceof` operators. |
| **`{#with}` section** | **LOW** | Not documented. While `{#let}` is preferred, `{#with}` exists and developers encounter it. |
| **`{#each}` alias** | **LOW** | `{#each}` is an alias for `{#for}`. Not mentioned; developers may encounter it in examples. |
| **`fmt`/`format` built-in resolvers** | **LOW** | Number and date formatting built-ins. Not mentioned. |
| **`@Locate` custom locators** | **LOW** | Custom template locators via CDI beans. Mentioned in gotchas but not in api.md. |
| **Template content negotiation** | **LOW** | Serving different template variants based on Accept header. Mentioned briefly in gotchas but not as a pattern. |
| **`RenderedResults` for testing** | **LOW** | Qute's test helper for asserting rendered template output. Not in testing reference. |
| **Qute standalone (without Quarkus)** | **LOW** | Using Qute engine independently. Niche but documented officially. |

### What's done well

The Qute coverage excels in the **HTMX integration patterns** -- click-to-edit, infinite scroll, OOB swaps, search/filter with debounce, CSRF protection. These are the patterns developers actually need when building HTMX+Qute apps, and no other skill covers them.

---

## 6. Cross-Cutting Concerns

### Accuracy check

| Location | Issue | Severity |
|----------|-------|----------|
| SKILL.md:266 | `@Transactional(readOnly = true)` -- Jakarta Transactions has no `readOnly` attribute. This is a Spring-ism. | ~~ERROR~~ **FIXED** |
| templates/api.md:194-196 | Loop metadata `{#if p_count == 0}` -- `count` is total items, not current index. Should be `p_index == 0`. | ~~ERROR~~ **FIXED** |
| templates/patterns.md:308-314 | CSRF config used `quarkus.http.csrf.*` instead of `quarkus.csrf-reactive.*`. | ~~ERROR~~ **FIXED** |
| templates/api.md:71-74 | Fragment `$` naming conflates two behaviors: in `@Inject Template`, `$` maps to a file path separator; in `@CheckedTemplate`, `$` separates template name from fragment ID. The comment on `emails$welcome` ("templates/emails/welcome.html") may not be accurate for all contexts. | **MISLEADING** |
| attributes.md:74 | `hx-history-elt` was removed/reworked in HTMX 2.x. If the skill targets 2.x, this should be noted as deprecated or 1.x-only. | **OUTDATED** |

### Version currency

- HTMX: Targets 2.x correctly. References extension URLs at `htmx-ext-*` packages (correct for 2.x).
- Quarkus: Targets "latest stable" without pinning a version. Extension names use current naming (`quarkus-rest` not `quarkus-resteasy-reactive`). Current.
- Java: Targets Java 21, which is the current LTS. Correct.

### Token efficiency

| Component | Lines | Assessment |
|-----------|-------|------------|
| SKILL.md | 306 | Well within 500-line budget |
| Reference files (total) | ~4,800 | Large but loaded on-demand; no concern |
| Average reference file | ~87 lines | Reasonable per-file size |
| Largest reference file | templates/api.md (~540 lines) | Could benefit from splitting |

---

## 7. Prioritized Recommendations

### P0 -- Critical (should fix before production use)

1. ~~**Add a `security/` module** under `references/quarkus/`~~ -- **DONE.** Added `references/quarkus/security/` with api.md (OIDC, form auth, `SecurityIdentity`, `@RolesAllowed`, HTTP policy, security headers, CORS, `@TestSecurity`), patterns.md, and gotchas.md.

2. ~~**Add `hx-params` to attributes.md**~~ -- **DONE.** Added with all four modes (`*`, `none`, include list, `not` exclude).

3. ~~**Fix `@Transactional(readOnly = true)`** in SKILL.md~~ -- **DONE.** Replaced with correct Quarkus guidance: omit `@Transactional` on read-only methods.

4. ~~**Fix loop metadata error** in templates/api.md~~ -- **DONE.** Changed `p_count == 0` to `p_index == 0`; clarified `p_count` = total items.

5. ~~**Fix CSRF config property names** in templates/patterns.md~~ -- **DONE.** Changed to `quarkus.csrf-reactive.*`.

### P1 -- High (significant value add)

6. ~~**Add `{#when}`/`{#switch}` and `@TemplateGlobal` to templates/api.md**~~ -- **DONE.** Added `{#when}`/`{#switch}` section with enum matching examples, `@TemplateGlobal` with `global:` namespace, and `orEmpty` built-in.

7. ~~**Add an `observability/` module**~~ -- **DONE.** Created `references/quarkus/observability/api.md` covering SmallRye Health (`@Liveness`, `@Readiness`, `@Startup`), Micrometer metrics (programmatic + annotation-based), OpenTelemetry tracing (`@WithSpan`, OTLP config), structured JSON logging, correlation IDs, and Kubernetes probe integration.

8. ~~**Add patterns.md and gotchas.md to the 9 modules that only have api.md**~~ -- **ALREADY DONE.** Review error: all modules already had all three files.

9. ~~**Document the HTMX 2.x DELETE body change**~~ -- **DONE.** Added to config.md migration table along with `scrollBehavior` change and `htmx-1-compat` extension note.

10. ~~**Add Web Components/Shadow DOM note**~~ -- **DONE.** Added to config.md 1.x vs 2.x table.

### P2 -- Medium (nice to have)

9. **Add `hx-disinherit`, `hx-request`** to attributes.md.
10. ~~**Add `{#let}`, `{#eval}`, `orEmpty`** to templates/api.md~~ -- **DONE.** `orEmpty` added in P1; `{#let}` and `{#eval}` added.
11. ~~**Add logging patterns**~~ -- **DONE.** Covered in observability/api.md (JSON logging, log categories, correlation IDs).
12. **Add native-image reference** (common failures, `@RegisterForReflection`, multi-stage Docker).
13. **Consolidate OOB swap documentation** -- pick one canonical location and cross-reference from others.
14. **Add `allowed-tools` to frontmatter** for explicit tool permissions.

### P3 -- Low (completionist)

15. Add `hx-prompt`, `htmx.ajax()`, multi-swap extension.
16. Add `@Locate`, `RenderedResults`, template content negotiation to Qute docs.
17. Add Liquibase as an alternative to Flyway.
18. Add reactive SQL client coverage.
19. Add containerization/Docker reference.

---

## 8. Comparison Summary Matrix

| Dimension | This Skill | ercan-er/htmx-claude-skill | cursor.directory Quarkus | Mindrally java-quarkus |
|-----------|-----------|---------------------------|------------------------|----------------------|
| Stack coverage | Quarkus + HTMX + Qute | HTMX only (Express.js) | Quarkus only (broad) | Quarkus only (broad) |
| Structure | Modular references/ | Modular skill/reference/ | Single flat file | Single flat file |
| Depth | Deep (api/patterns/gotchas) | Medium (reference docs) | Shallow (bullet points) | Shallow (bullet points) |
| Code examples | Extensive, runnable | Moderate | None | None |
| HTMX coverage | 13 reference files | 10 reference files | None | None |
| Quarkus coverage | 13 modules | None | 15 bullet sections | 12 bullet sections |
| Qute coverage | Full module | None | None | None |
| Decision trees | Yes (messaging, main) | No | No | No |
| Gotchas tables | Yes (symptom/cause/fix) | No | No | No |
| Security module | **Missing** | Basic (CSRF) | Yes (bullet points) | Yes (bullet points) |
| Observability | **Missing** | No | Yes (bullet points) | Yes (bullet points) |
| Total reference files | 55 | ~12 | 1 | 1 |
| Estimated tokens | ~60K (full load) | ~15K | ~2K | ~2K |

---

## Conclusion

This skill represents the most comprehensive Quarkus + HTMX + Qute reference available in the Claude Code ecosystem. Its modular architecture, decision trees, and gotchas tables set a standard that no competitor approaches. The primary gaps -- security/auth and observability modules -- are the most important to address, as they represent table-stakes requirements for any production Quarkus application. The HTMX gaps (mainly `hx-params` and a few 2.x migration details) and Qute gaps (`{#when}`, `@TemplateGlobal`) are secondary but would bring the skill to near-complete coverage of its target stack.
