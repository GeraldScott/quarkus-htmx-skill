# Skill Review: htmx-quarkus

**Reviewer perspective:** Software Architect / Senior Developer
**Date:** 2026-03-21
**Scope:** Structure, logic, content accuracy, gap analysis against official docs and peer skills

---

## Executive Summary

This is a well-crafted, progressive-disclosure skill for Quarkus + HTMX development. It follows the Anthropic guide's recommended patterns correctly and covers the core stack thoroughly. However, it has a **critical file path bug**, several areas of **content redundancy**, a **code bug** in the Panache example, a **Spring annotation leak** in the REST example, and notable **HTMX/Qute coverage gaps** compared to official documentation. No equivalent Quarkus skill exists in the public ecosystem, which makes this skill uniquely valuable but also means there's no peer to validate against.

**Verdict:** Solid foundation, needs a focused cleanup pass.

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
| **No Quarkus skill exists** | N/A | This skill is unique in the ecosystem |

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

## 8. Strengths Worth Preserving

- **Anti-patterns document is exceptional.** No other skill in the ecosystem has this. It's the single most valuable file in this skill — it prevents the #1 mistake developers make with HTMX (falling back to SPA patterns). Keep it and expand it.
- **Progressive disclosure is textbook.** The SKILL.md is lean (~135 lines), reference files are loaded on-demand. This is exactly what the Anthropic guide recommends.
- **Dual Panache patterns.** Showing both Active Record and Repository with guidance on when to use each is valuable — most tutorials only show one.
- **Validation script.** Having automated validation is rare in community skills. Extend it rather than replacing it.
- **HTMX lifecycle events table.** Comprehensive and well-formatted — better than what ercan-er/htmx-claude-skill provides.
- **Swap strategy and trigger modifier tables.** These are reference-quality and match the official HTMX docs closely.
- **Type-safe Qute templates.** `@CheckedTemplate` coverage with build-time validation is a production pattern that most Quarkus tutorials skip.
- **This is the only Quarkus skill in the ecosystem.** No competitor exists. This gives it outsized value.
