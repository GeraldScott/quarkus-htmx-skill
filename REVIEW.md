# Skill Review: htmx-quarkus

**Reviewer perspective:** Software Architect / Senior Developer
**Date:** 2026-03-21
**Scope:** Structure, logic, content accuracy, gap analysis against official docs and peer skills

---

## Executive Summary

This is a well-crafted, progressive-disclosure skill for Quarkus + HTMX development. It follows
the Anthropic guide's recommended patterns and covers the core stack thoroughly.

**Review v1 (2026-03-21)** identified critical bugs, redundancy, and content gaps. All P0/P1/P2
issues and selected P3 items have been resolved (see Fix Log below).

**Review v2 (2026-03-21)** compares against b6k-dev/quarkus-skill — a comprehensive, pure-Quarkus
skill with 13 reference modules. This comparison reveals architectural differences (HTMX-integrated
monolith vs. Quarkus-pure router) and specific content gaps in CDI, configuration, messaging,
and gotchas coverage.

**Verdict:** Production-ready for the Quarkus + HTMX stack. The HTMX integration and anti-patterns
document remain unique advantages no other skill offers. The main remaining gap is depth in
Quarkus-only domains (CDI patterns, messaging, advanced ORM) that b6k-dev covers well.

---

## 1. Structural Compliance (vs. Anthropic Best Practices Guide)

### What's correct

| Requirement | Status | Notes |
|---|---|---|
| File named exactly `SKILL.md` | PASS | Case-sensitive, correct |
| Folder name in kebab-case | PASS | `htmx-quarkus-skill` |
| YAML frontmatter with `---` delimiters | PASS | |
| `name` field in kebab-case | PASS | `htmx-quarkus` |
| `description` includes WHAT + WHEN | PASS | Excellent — lists technologies, annotations, file patterns, and trigger phrases |
| No XML angle brackets in frontmatter | PASS | |
| No `README.md` inside skill folder | PASS | |
| Progressive disclosure (3 levels) | PASS | Frontmatter -> SKILL.md body -> reference files |
| SKILL.md body length | PASS | ~135 lines — well under the 500-line warning threshold |
| Description under 1024 chars | PASS | ~580 chars |

### What needs fixing

| Issue | Severity | Detail |
|---|---|---|
| **Reference file paths are wrong** | CRITICAL | SKILL.md references `references/project-structure.md` etc., but files are at root level (`./project-structure.md`). Claude will fail to find them. Either move files into a `references/` directory or fix the paths in SKILL.md. |
| No `references/` directory | MEDIUM | The Anthropic guide recommends `references/` for supplementary docs. Files are at root level alongside SKILL.md, which is non-standard. |
| Missing `license` field | LOW | Optional, but recommended for open-source distribution |
| Missing `metadata` field | LOW | No `author`, `version`, or `mcp-server` metadata. Useful for discoverability. |
| No `compatibility` field | LOW | Should note: "Requires Java 21+, Maven, Docker (for DevServices)" |

### Structural recommendation

Move reference files into a `references/` subdirectory to match both the SKILL.md paths and the Anthropic-recommended structure:

```
htmx-quarkus-skill/
├── SKILL.md
├── references/
│   ├── project-structure.md
│   ├── rest-and-htmx.md
│   ├── database-postgresql.md
│   ├── testing.md
│   └── htmx-anti-patterns.md
└── tests/
    └── validate-skill.sh
```

---

## 2. Logic, Ordering, and Redundancy

### Logical flow — generally good

The SKILL.md body follows a sensible progression:
1. Reference file listing (progressive disclosure pointer)
2. HTMX enforcement rule (critical constraint upfront)
3. Core principles (architectural philosophy)
4. Quick-reference cheat sheet (actionable patterns)
5. Common gotchas (error prevention)
6. Health/observability (final concern)

Each reference file is internally well-ordered.

### Redundancy issues

| Duplicated content | Locations | Recommendation |
|---|---|---|
| **Datasource configuration** (3x) | SKILL.md:84-96, database-postgresql.md:7-36, project-structure.md:124-160 | Keep the full example in `database-postgresql.md` only. SKILL.md should have at most a 3-line summary pointing to the reference. Remove from `project-structure.md`. |
| **DevServices PostgreSQL config** (2x) | project-structure.md:106-120, database-postgresql.md:8-10 | Keep in `project-structure.md` (it's a DevServices concern, not a DB concern). Add a cross-reference from `database-postgresql.md`. |
| **Full application.properties example** (2x) | project-structure.md:122-160, database-postgresql.md:7-36 | Keep one canonical version in `project-structure.md`. The DB file should only show DB-specific properties. |
| **OOB swaps** (2x) | rest-and-htmx.md:448-460, htmx-anti-patterns.md:199-236 | Keep the pattern in `rest-and-htmx.md`, keep the anti-pattern (wrong vs. right) in `htmx-anti-patterns.md`. Currently both show the "right" way with code. |
| **HX-Request header detection** (2x) | rest-and-htmx.md:410-421, htmx-anti-patterns.md:79-105 | Same issue — both files show the correct pattern with full code examples. |
| **CSRF protection** (2x within same file) | rest-and-htmx.md:330-338 (global listener), rest-and-htmx.md:462-479 (dedicated section) | Consolidate into the dedicated CSRF section only. |

**Impact:** Redundancy wastes context tokens. At ~2,800 lines across all files, this skill is well within limits, but eliminating duplication would reduce total tokens by ~15-20% and reduce risk of contradictory edits over time.

### Ordering issues

- `rest-and-htmx.md` covers pure REST/JSON patterns (lines 1-95) before Qute and HTMX. This is logical but could confuse Claude into generating JSON endpoints for HTMX contexts. Consider renaming the file to `qute-and-htmx.md` and moving the pure REST/JSON section to `project-structure.md` or a separate reference, since the HTMX enforcement rule explicitly says "server returns HTML, not JSON."

---

## 3. Code Bugs and Accuracy Issues

### Bug: Infinite recursion in Panache example

**File:** `database-postgresql.md:108-110`

```java
public static Optional<Order> findByIdOptional(Long id) {
    return findByIdOptional(id);   // inherited; alias for clarity
}
```

This calls itself, causing a `StackOverflowError`. The method signature matches the inherited one exactly, so this override is both broken and unnecessary. **Delete this method entirely** — the inherited `findByIdOptional(Long id)` from `PanacheEntity` already does the right thing.

### Bug: Spring annotation in JAX-RS resource

**File:** `rest-and-htmx.md:53`

```java
@ResponseStatus(204)
public void delete(@PathParam("id") Long id) {
```

`@ResponseStatus` is a **Spring MVC** annotation, not JAX-RS. In Quarkus/JAX-RS, a `void` return from a `@DELETE` method returns 204 automatically with RESTEasy Reactive. Remove the annotation entirely or use `Response.noContent().build()` if an explicit status code is needed.

### Suspect: CSRF config properties

**File:** `rest-and-htmx.md:466-468`

```properties
quarkus.http.csrf.enabled=true
quarkus.http.csrf.token-header-name=X-CSRF-TOKEN
```

The Quarkus CSRF extension (`quarkus-csrf-reactive`) uses the config prefix `quarkus.csrf-reactive.*`, not `quarkus.http.csrf.*`. Verify against the current Quarkus docs and correct.

### Suspect: SSE example missing dependency note

**File:** `rest-and-htmx.md:484-501`

The SSE example uses `Multi<String>` (Mutiny reactive type) but the skill's recommended extensions don't include `quarkus-resteasy-reactive-jackson` or note that `Multi` requires Mutiny (included transitively by `resteasy-reactive`, but this should be explicit for clarity). Also, the SSE endpoint returns `Multi<String>` but should use `@RestSseElementType(MediaType.TEXT_HTML)` for HTMX fragment streaming, which is not shown.

---

## 4. Comparison with Equivalent Skills on GitHub

### Landscape

| Skill | Repo | Relevance |
|---|---|---|
| **ercan-er/htmx-claude-skill** | github.com/ercan-er/htmx-claude-skill | Direct HTMX competitor — modular, 10 reference files |
| **kjnez/claude-code-django** | github.com/kjnez/claude-code-django | Django + HTMX + PostgreSQL combined skill — closest architectural peer |
| **Jeffallan/claude-skills** | github.com/Jeffallan/claude-skills | 66 skills incl. `java-architect` and `spring-boot-engineer` — Java peer |
| **anthropics/skills** (17 official skills) | github.com/anthropics/skills | Reference implementations for skill structure |
| **getsentry/sentry-for-ai** | github.com/getsentry/sentry-for-ai | Best-practice MCP+skill architecture (router pattern) |
| **b6k-dev/quarkus-skill** | github.com/b6k-dev/quarkus-skill | Comprehensive pure-Quarkus skill — 13 modules, decision tree router (see Section 9) |

### Comparison: ercan-er/htmx-claude-skill (HTMX-only)

This is the closest peer — a standalone HTMX skill with:
- **10 dedicated reference files** (attributes, triggers, swap, events, server-patterns, validation, security, performance, headers, anti-patterns)
- **Enterprise variant** (`ENTERPRISE.SKILL.md`)
- **Separate activation logic** (`skill/activation.md`)
- **CI/CD tests** (`.github/workflows/`)
- **Express.js demo** in `examples/`

**Gaps in htmx-quarkus-skill compared to ercan-er:**

| Topic | ercan-er | htmx-quarkus | Gap |
|---|---|---|---|
| Dedicated attributes reference | Yes (full file) | Cheat-sheet table in rest-and-htmx.md | MINOR — table is sufficient |
| Dedicated trigger reference | Yes (full file) | Section in rest-and-htmx.md | MINOR — section is good |
| Security reference (CSRF, CSP, XSS) | Dedicated file | Partial (CSRF only) | **GAP** — no CSP, no XSS prevention |
| Performance guidance | Dedicated file | None | **GAP** — no lazy loading, preload, debounce strategy guidance |
| Validation patterns | Dedicated file | Anti-pattern #6 only | **GAP** — no multi-field validation, no progressive enhancement |
| Activation/trigger logic | Separate file | In YAML description | OK — YAML description is the standard approach |
| Enterprise patterns | Separate SKILL.md | None | LOW — not needed unless targeting enterprise |
| Express.js examples | Yes | Java/Quarkus examples | N/A — different stack, but demo project concept is transferable |

### Comparison: kjnez/claude-code-django (backend + HTMX peer)

This is the only other skill combining a backend framework with HTMX. It uses Django + PostgreSQL + HTMX — the closest architectural peer to this skill (different language, same pattern).

**Structure:** Uses `.claude/skills/` directory with ~15 separate skill modules (Django Models, Django Forms, HTMX Patterns, Celery Tasks, etc.), plus hooks for auto-formatting, auto-testing, and branch protection. HTMX is a dedicated skill module alongside framework-specific skills.

**Lessons for htmx-quarkus-skill:**
- Having HTMX as a separate module from the backend framework makes each independently testable
- Hooks for auto-linting/testing enforce quality beyond just instructions
- The skill integration with `.claude/settings.json` hooks is a pattern this skill could adopt

### Comparison: Jeffallan/claude-skills (Java peer)

Contains `java-architect` (~350 lines) and `spring-boot-engineer` skills for Spring Boot 3.x + Java 21. Key patterns:

- **MUST DO / MUST NOT DO constraint tables** — explicit, scannable rules rather than prose. This skill uses prose for constraints (e.g., "favour constructor injection"), which is less reliable for AI compliance.
- **Verification-driven workflow:** `./mvnw verify` after each phase. This skill mentions `./mvnw quarkus:dev` but doesn't enforce a verification step.
- **Quality gates:** 85%+ coverage targets, which this skill doesn't specify.
- **Workflow chains:** Skills reference each other ("Feature Forge -> Architecture Designer -> Test Master"). Not applicable for a standalone skill, but worth noting.

**No Quarkus or HTMX skills exist in this collection.**

### Comparison: getsentry/sentry-for-ai (architecture reference)

Sentry's skill architecture uses a **router pattern** — 3 always-visible router skills that load hidden sub-skills on demand. This is more complex than needed for this skill, but the `references/` subdirectory pattern is exactly what the Anthropic guide recommends and what this skill claims to use (but doesn't actually implement — see critical path bug above).

### Comparison: anthropics/skills official repo

The official `frontend-design` skill is the closest structural analog:
- Single SKILL.md with progressive disclosure
- References to bundled scripts/assets
- No separate reference files (everything in one SKILL.md)

This skill's modular approach (SKILL.md + 5 reference files) is actually **more sophisticated** than the official examples, which is good for a complex multi-technology stack. The official skills tend to be shorter and more focused (one concern per skill), while this skill covers an entire stack.

---

## 5. Gaps vs. Official Documentation (Context7)

### HTMX gaps (vs. bigskysoftware/htmx docs)

| Feature | In Skill? | Priority | Notes |
|---|---|---|---|
| `hx-select` / `hx-select-oob` | No | HIGH | Selects specific parts of a response — critical for fragment architecture |
| `hx-sync` | No | HIGH | Coordinates concurrent requests (abort, queue, drop) — essential for real apps |
| `hx-disable` / `hx-disabled-elt` | No | MEDIUM | Disables elements during requests — common UX pattern |
| `hx-preserve` | No | MEDIUM | Preserves elements (e.g., video players) across swaps |
| `hx-encoding="multipart/form-data"` | No | MEDIUM | Required for file uploads with HTMX |
| `hx-params` | No | LOW | Controls which params are submitted |
| Event filters (`click[ctrlKey]`) | No | LOW | Conditional triggering |
| `HX-Trigger-After-Swap` / `HX-Trigger-After-Settle` | No | MEDIUM | Server-triggered events at specific lifecycle points |
| `HX-Location` response header | No | MEDIUM | Client-side redirect without full page load |
| `HX-Reselect` response header | No | LOW | Server-side response selection |
| WebSocket extension (`hx-ext="ws"`) | No | MEDIUM | Alternative to SSE for bidirectional real-time |
| `hx-inherit` | No | LOW | Controls attribute inheritance |
| Preload extension | No | LOW | Predictive loading on hover |
| `htmx:load` event | No | MEDIUM | Initialize JS on newly swapped content |

### Qute gaps (vs. quarkus.io/guides/qute)

| Feature | In Skill? | Priority | Notes |
|---|---|---|---|
| `{#fragment}` inline fragments | No | HIGH | Modern alternative to `$` file-based fragments (Qute 3.x+) |
| `{#let}` local variables | No | MEDIUM | Reduces template verbosity |
| `{#when}` / `{#switch}` | No | LOW | Pattern matching in templates |
| `{#with}` scope narrowing | No | LOW | Simplifies nested object access |
| `?:` elvis operator | No | MEDIUM | Default values in expressions |
| `or` operator for defaults | No | LOW | Alternative to elvis |
| Record-based fragments | No | MEDIUM | `record items$item(Item item) implements TemplateInstance {}` — type-safe alternative |
| Extension methods | No | LOW | Custom template methods |
| `@TemplateGlobal` | No | LOW | Global template variables |

### Quarkus gaps (vs. quarkus.io/guides)

| Feature | In Skill? | Priority | Notes |
|---|---|---|---|
| `@ServerExceptionMapper` | No | HIGH | Modern replacement for `ExceptionMapper` interface (shown in skill) |
| `@ConfigMapping` | No | MEDIUM | Preferred over `@ConfigProperty` for config groups |
| `@TestSecurity` for auth testing | No | MEDIUM | Security testing patterns only listed as extension, not shown |
| REST Client (`@RegisterRestClient`) | No | LOW | External API consumption |
| `@Scheduled` for cron jobs | No | LOW | Scheduled tasks |
| `@QuarkusIntegrationTest` | Mentioned but not shown | LOW | Black-box test for packaged artifacts |
| Reactive Panache | No | LOW | Acceptable — skill correctly focuses on imperative |
| Container image builds (Jib, Buildpack) | No | LOW | Only Docker mentioned |

---

## 6. Validation Script Review

The `tests/validate-skill.sh` is a solid structural validator that checks:
- SKILL.md format and frontmatter
- Reference file existence
- HTMX attribute and swap strategy coverage
- Anti-pattern guide completeness
- Code example hygiene (no fetch/JSON in HTMX sections)

### Issues

1. **Path bug not caught:** The script checks that files exist at root level but doesn't validate that SKILL.md paths match actual file locations. It should check that `references/` paths referenced in SKILL.md resolve correctly.
2. **Reference path mismatch:** Script checks for `$SKILL_DIR/$ref` (root level) while SKILL.md references `references/$ref`. Either the script or the SKILL.md is wrong — they should be consistent.
3. **No content accuracy checks:** Doesn't verify code examples compile or that config property names are valid. (Acceptable limitation for a bash script.)

---

## 7. Prioritized Action Items

### P0 — Critical (breaks functionality)

1. **Fix reference file paths.** Either move files to `references/` or update SKILL.md paths. This is the single most impactful issue — Claude cannot follow the skill's own instructions with broken paths.
2. **Fix infinite recursion** in `database-postgresql.md:108-110`. Delete the `findByIdOptional` override.
3. **Remove `@ResponseStatus(204)`** Spring annotation from `rest-and-htmx.md:53`.

### P1 — High (content gaps)

4. **Add `hx-select` / `hx-select-oob`** coverage to rest-and-htmx.md. Essential for fragment-based architecture.
5. **Add `hx-sync`** coverage. Without it, Claude will generate UIs with race conditions on rapid clicks.
6. **Add `{#fragment}` inline Qute syntax.** This is the modern approach; the skill only covers `$`-based fragments.
7. **Add `@ServerExceptionMapper`** as the preferred pattern (it's simpler than implementing `ExceptionMapper`).
8. **Verify and fix CSRF config properties** (`quarkus.csrf-reactive.*` vs `quarkus.http.csrf.*`).
9. **Add `hx-encoding="multipart/form-data"`** for file upload patterns.

### P2 — Medium (completeness)

10. Eliminate the 6 redundancy areas identified in Section 2.
11. Add security guidance beyond CSRF: CSP headers, XSS prevention with Qute's auto-escaping, `@RolesAllowed` patterns.
12. Add `?:` elvis operator and `{#let}` to Qute syntax reference.
13. Add `HX-Trigger-After-Swap`, `HX-Trigger-After-Settle`, `HX-Location` response headers.
14. Add `htmx:load` event for initializing JS on swapped content.
15. Add `@ConfigMapping` as preferred config pattern.
16. Add `hx-disabled-elt` / `hx-indicator` loading state patterns (common UX requirement).
17. Add a `compatibility` field to frontmatter.

### P3 — Low (nice to have)

18. Add `license` and `metadata` to frontmatter.
19. Add WebSocket extension mention as SSE alternative.
20. Consider splitting `rest-and-htmx.md` — move pure REST/JSON patterns elsewhere.
21. Add a working example project or `examples/` directory (as ercan-er/htmx-claude-skill does).
22. Add `hx-preserve`, `hx-params`, event filters for completeness.

---

## 8. Fix Log

All P0, P1, P2, and selected P3 issues from the original review have been resolved.

### P0 — Critical (all fixed)

| # | Issue | Resolution | Commit |
|---|---|---|---|
| 1 | Reference file paths wrong | Moved files to `references/` directory | `81dfa59` |
| 2 | Infinite recursion in Panache `findByIdOptional` | Deleted broken override | `81dfa59` |
| 3 | Spring `@ResponseStatus(204)` in JAX-RS | Removed; void `@DELETE` returns 204 natively | `81dfa59` |
| - | CSRF config prefix wrong (`quarkus.http.csrf.*`) | Fixed to `quarkus.rest-csrf.*`; replaced JS injection with native Qute `{inject:csrf.*}` | `81dfa59` |

### P1 — High (all fixed)

| # | Issue | Resolution | Commit |
|---|---|---|---|
| 4 | Missing `hx-select` / `hx-select-oob` | Added to cheat sheet | `36886a1` |
| 5 | Missing `hx-sync` | Added strategy table + form/filter patterns | `36886a1` |
| 6 | Missing `{#fragment}` inline Qute | Added with template + Java examples | `36886a1` |
| 7 | Using old `ExceptionMapper` interface | Replaced with `@ServerExceptionMapper` + HTMX error fragment | `36886a1` |
| 8 | CSRF config wrong | Fixed in P0 pass | `81dfa59` |
| 9 | Missing `hx-encoding` file uploads | Added multipart pattern with `@MultipartForm` | `36886a1` |

### P2 — Medium (all fixed)

| # | Issue | Resolution | Commit |
|---|---|---|---|
| 10 | 6 redundancy areas | Replaced datasource block with pointer; cross-referenced DevServices | `2d2cc91` |
| 11 | No security beyond CSRF | Added XSS/Qute, CSP headers, `@RolesAllowed` | `2d2cc91` |
| 12 | Missing `?:` elvis and `{#let}` | Added to Qute syntax reference | `2d2cc91` |
| 13 | Missing response headers | Added `HX-Trigger-After-Swap/Settle`, `HX-Location`, JSON payload | `2d2cc91` |
| 14 | Missing `htmx:load` event | Added to lifecycle table | `2d2cc91` |
| 15 | Missing `@ConfigMapping` | Added with interface example to SKILL.md | `2d2cc91` |
| 16 | Missing `hx-disabled-elt` | Added in P1 pass (cheat sheet + file upload) | `36886a1` |
| 17 | No `compatibility` field | Added to frontmatter | `2d2cc91` |

### P3 — Low (selected items fixed)

| # | Issue | Resolution | Commit |
|---|---|---|---|
| 18 | No `license`/`metadata` | Added MIT + author/version | `9b07adb` |
| 19 | No WebSocket extension | Added `hx-ext="ws"` with SSE comparison | `9b07adb` |
| 22 | No `hx-preserve`/`hx-params`/event filters | Added all three | `9b07adb` |

### P3 — Remaining (not yet addressed)

| # | Issue | Status |
|---|---|---|
| 20 | Split `rest-and-htmx.md` (move pure REST/JSON elsewhere) | Open |
| 21 | Add working `examples/` directory | Open |

---

## 9. Comparison with b6k-dev/quarkus-skill

### Overview

[b6k-dev/quarkus-skill](https://github.com/b6k-dev/quarkus-skill) is a pure-Quarkus skill
(no HTMX) with 13 reference modules, a decision-tree SKILL.md, and a `/quarkus` slash command.
It is the most comprehensive Quarkus skill found in the public ecosystem.

### Architecture comparison

| Aspect | htmx-quarkus | b6k-dev/quarkus-skill |
|---|---|---|
| **Scope** | Quarkus + HTMX full-stack | Quarkus platform only (no frontend) |
| **SKILL.md style** | Cheat-sheet + principles + gotchas | Decision tree router to 13 modules |
| **Reference modules** | 5 files (flat) | 13 directories, each with README/api/patterns/gotchas |
| **Per-module structure** | Single markdown file per concern | 4 files per module (README, api.md, patterns.md, gotchas.md) |
| **Slash command** | None | `/quarkus <task>` loads context automatically |
| **Installation** | Manual (copy to skills dir) | `npx skills add` or `curl` installer |
| **HTMX coverage** | Comprehensive (cheat sheets, patterns, anti-patterns, SSE, WebSocket) | None |
| **Qute coverage** | Full (syntax, fragments, inheritance, type-safe, HTMX integration) | Templates module with fragments, extensions, i18n |
| **Testing** | Dedicated `testing.md` reference | Mentioned in module gotchas but no dedicated module |
| **Anti-patterns** | Dedicated document (7 anti-patterns) | Per-module gotchas tables |

### What b6k-dev does better

**1. Decision tree in SKILL.md** — The router pattern ("What do you need? -> module") is
superior progressive disclosure. Our flat reference list requires Claude to guess which file
is relevant. The decision tree makes routing deterministic.

**2. Gotchas as structured tables** — Every module has a `gotchas.md` with `Symptom | Cause | Fix`
tables. This is more actionable than our prose-based "Common gotchas" section. Example:

> | Symptom | Likely cause | Fix |
> | JSON body is empty in native executable | Serialized type cannot be inferred from raw Response | Prefer concrete return types or annotate with @RegisterForReflection |

**3. Deeper CDI/DI coverage** — 8 patterns including:
- Constructor injection with Lombok `@RequiredArgsConstructor`
- `@IfBuildProfile` + `@DefaultBean` for profile-based alternatives
- `@Inject @All List<T>` for collecting implementations
- `@Lock` for thread-safe `@ApplicationScoped` beans
- `@Decorator` for business-logic decoration
- `InterceptionProxy` for external library integration

Our skill covers CDI in ~4 lines of prose. This is a significant gap.

**4. Configuration module depth** — 8 patterns including:
- `@ConfigMapping` with nested interfaces (we added basic example)
- Property expression fallbacks (`${HOST:${remote.host}}`)
- Startup validation with `@Min`/`@Max` constraints
- Build-time drift tracking (`quarkus.config-tracking.enabled`)
- `.env` file patterns (we mention but don't detail)

**5. Messaging and event modules** — Three separate modules:
- `cdi-events` — in-process CDI events with `@Observes`
- `vertx-event-bus` — Vert.x event bus for clustered/non-blocking
- `messaging` — cross-service messaging (Kafka, AMQP, etc.)

We have zero coverage of any messaging/eventing patterns.

**6. Advanced ORM module** — Dedicated `data-orm-advanced` covering:
- Multiple persistence units
- Multitenancy
- Second-level caching
- Hibernate extension points

Our `database-postgresql.md` covers basic Panache only.

**7. OpenAPI as separate module** — Dedicated patterns for API contract documentation.
We mention `smallrye-openapi` in passing but show no annotation patterns.

**8. Multipart upload gotchas** — Documents HTTP 413 limits and temp file cleanup.
We added a multipart pattern but lack the gotchas.

### What htmx-quarkus does better

**1. HTMX — the entire frontend story.** b6k-dev has zero HTMX coverage. Our skill provides:
- Complete attribute cheat sheet (20+ attributes)
- Swap strategies with modifiers
- Trigger reference with event filters
- Event lifecycle table
- 7 anti-patterns with wrong/right examples
- SSE and WebSocket patterns
- OOB swaps, hx-sync, file uploads
- CSRF with Qute native integration

This is the single biggest differentiator and cannot be replicated by combining b6k-dev
with the ercan-er HTMX skill, because our patterns show HTMX + Qute + Quarkus wired
together (e.g., `@CheckedTemplate` fragments for HTMX, `HX-Request` header detection,
`@ServerExceptionMapper` returning error fragments).

**2. Qute + HTMX integration patterns.** Fragment-based HTMX responses, click-to-edit with
Qute templates, search/filter with debounce, infinite scroll — all with both the HTML
template and the Java endpoint shown together. b6k-dev's templates module covers Qute
in isolation.

**3. Anti-patterns document.** No other skill has this. The 7 anti-patterns (JSON instead
of HTML, SPA state, full layout in fragment, no history, polling abuse, validation redirect,
not using OOB) are the highest-value content in the skill.

**4. Testing reference.** Dedicated file covering `@QuarkusTest`, `@TestProfile`,
`@TestTransaction`, `@InjectMock`, DevServices, Testcontainers, and test fixtures.
b6k-dev mentions testing in gotchas but has no dedicated module.

**5. Flyway migrations.** Naming conventions, example migrations, config properties.
b6k-dev has a `data-migrations` module but our coverage is comparable.

### New gaps identified (vs. b6k-dev)

| Gap | b6k-dev coverage | Priority | Recommendation |
|---|---|---|---|
| **Decision tree in SKILL.md** | Full router pattern | HIGH | Add a decision tree to SKILL.md to route to reference files |
| **Gotchas as structured tables** | Per-module `Symptom/Cause/Fix` tables | HIGH | Convert prose gotchas to table format |
| **CDI/DI depth** | 8 patterns with code | HIGH | Expand CDI section — at minimum add constructor injection, `@All List<T>`, `@IfBuildProfile`, `@Lock` |
| **Messaging/events** | 3 modules (CDI events, Vert.x, Kafka) | MEDIUM | Add at least CDI `@Observes` events — common in Quarkus apps |
| **Configuration depth** | 8 patterns | MEDIUM | Already added `@ConfigMapping`; consider adding validation and expression fallbacks |
| **Advanced ORM** | Multitenancy, caching, multiple PUs | LOW | Out of scope for typical HTMX app; link to Quarkus docs if needed |
| **OpenAPI patterns** | Dedicated module | LOW | Add `@Operation`, `@Tag`, `@Schema` annotation examples to REST section |
| **Multipart gotchas** | HTTP 413, temp file cleanup | LOW | Add to rest-and-htmx.md alongside existing upload pattern |
| **Slash command** | `/quarkus <task>` | LOW | Would improve UX but requires Claude Code command integration |

---

## 10. Strengths Worth Preserving

- **Anti-patterns document is exceptional.** No other skill in the ecosystem has this — including b6k-dev. It's the single most valuable file in this skill.
- **HTMX + Qute + Quarkus wiring.** The integrated patterns (fragment responses, HX-Request detection, CSRF with Qute injection, error fragments via `@ServerExceptionMapper`) cannot be replicated by combining separate HTMX and Quarkus skills.
- **Progressive disclosure is textbook.** The SKILL.md is lean (~120 lines), reference files are loaded on-demand.
- **Dual Panache patterns.** Showing both Active Record and Repository with guidance on when to use each is valuable.
- **Validation script.** Having automated validation is rare in community skills. Extend it rather than replacing it.
- **HTMX reference tables.** Attribute cheat sheet (20+ attributes), swap strategies, trigger modifiers, event lifecycle, hx-sync strategies — reference-quality and match official HTMX docs.
- **Type-safe Qute templates.** `@CheckedTemplate` + `{#fragment}` coverage with build-time validation is a production pattern most tutorials skip.
- **Unique positioning.** b6k-dev covers Quarkus deeply but has no HTMX. ercan-er covers HTMX but has no Quarkus. This skill bridges both and is the only one doing so.
