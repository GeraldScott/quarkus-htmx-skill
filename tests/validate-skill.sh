#!/usr/bin/env bash
# Skill Validation Tests
# Validates that the skill pack follows correct format and contains no HTMX anti-patterns.
# Run: bash tests/validate-skill.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

# ── 1. SKILL.md format validation ──────────────────────────────────────

echo "=== SKILL.md Format ==="

SKILL_FILE="$SKILL_DIR/SKILL.md"

if [[ ! -f "$SKILL_FILE" ]]; then
    fail "SKILL.md does not exist"
else
    pass "SKILL.md exists"

    # Extract frontmatter (between first and second ---)
    FRONTMATTER=$(awk 'BEGIN{n=0} /^---$/{n++; if(n==2) exit; next} n==1{print}' "$SKILL_FILE")

    # Check frontmatter exists
    if [[ -n "$FRONTMATTER" ]]; then
        pass "SKILL.md has frontmatter"
    else
        fail "SKILL.md missing frontmatter (must start and end with ---)"
    fi

    # Check frontmatter has name field
    if echo "$FRONTMATTER" | grep -q '^name:'; then
        pass "SKILL.md has 'name' field"
    else
        fail "SKILL.md missing 'name' field in frontmatter"
    fi

    # Check frontmatter has description field
    if echo "$FRONTMATTER" | grep -q '^description:'; then
        pass "SKILL.md has 'description' field"
    else
        fail "SKILL.md missing 'description' field in frontmatter"
    fi

    # Check body length (warn if over 500 lines)
    BODY_LINES=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$SKILL_FILE" | wc -l)
    if (( BODY_LINES > 500 )); then
        warn "SKILL.md body is $BODY_LINES lines (>500 may hurt AI performance)"
    else
        pass "SKILL.md body length OK ($BODY_LINES lines)"
    fi
fi

# ── 2. Reference files exist ──────────────────────────────────────────

echo ""
echo "=== Reference Files ==="

REQUIRED_REFS=(
    "references/rest-and-htmx.md"
    "references/database-postgresql.md"
    "references/project-structure.md"
    "references/testing.md"
    "references/htmx-anti-patterns.md"
)

for ref in "${REQUIRED_REFS[@]}"; do
    if [[ -f "$SKILL_DIR/$ref" ]]; then
        pass "$ref exists"
    else
        fail "$ref is missing"
    fi
done

# Check SKILL.md references all required files
for ref in "${REQUIRED_REFS[@]}"; do
    if grep -q "$ref" "$SKILL_FILE" 2>/dev/null; then
        pass "SKILL.md references $ref"
    else
        warn "SKILL.md does not reference $ref"
    fi
done

# ── 3. HTMX content validation ────────────────────────────────────────

echo ""
echo "=== HTMX Content ==="

HTMX_FILE="$SKILL_DIR/references/rest-and-htmx.md"

if [[ -f "$HTMX_FILE" ]]; then
    # Must contain core HTMX attributes
    for attr in hx-get hx-post hx-swap hx-target hx-trigger; do
        if grep -q "$attr" "$HTMX_FILE"; then
            pass "rest-and-htmx.md covers $attr"
        else
            fail "rest-and-htmx.md missing $attr coverage"
        fi
    done

    # Must cover swap strategies
    for strategy in innerHTML outerHTML beforeend afterbegin delete; do
        if grep -q "$strategy" "$HTMX_FILE"; then
            pass "Swap strategy '$strategy' documented"
        else
            fail "Swap strategy '$strategy' not documented"
        fi
    done

    # Must cover key trigger types
    for trigger in "delay:" revealed intersect "every "; do
        if grep -q "$trigger" "$HTMX_FILE"; then
            pass "Trigger '$trigger' documented"
        else
            warn "Trigger '$trigger' not documented"
        fi
    done

    # Must cover HTMX event lifecycle
    for event in htmx:configRequest htmx:beforeRequest htmx:afterRequest htmx:beforeSwap htmx:afterSwap; do
        if grep -q "$event" "$HTMX_FILE"; then
            pass "Event '$event' documented"
        else
            warn "Event '$event' not documented"
        fi
    done

    # Must cover OOB swaps
    if grep -q "hx-swap-oob" "$HTMX_FILE"; then
        pass "OOB swaps documented"
    else
        fail "OOB swaps not documented"
    fi

    # Must cover HX-Request header detection
    if grep -q "HX-Request" "$HTMX_FILE"; then
        pass "HX-Request header detection documented"
    else
        warn "HX-Request header detection not documented"
    fi

    # Must cover CSRF
    if grep -q "CSRF" "$HTMX_FILE"; then
        pass "CSRF protection documented"
    else
        fail "CSRF protection not documented"
    fi
fi

# ── 4. Anti-pattern validation ─────────────────────────────────────────

echo ""
echo "=== Anti-Patterns Guide ==="

AP_FILE="$SKILL_DIR/references/htmx-anti-patterns.md"

if [[ -f "$AP_FILE" ]]; then
    EXPECTED_PATTERNS=(
        "JSON instead of HTML"
        "SPA state"
        "Full layout in"
        "history"
        "Polling"
        "Validation redirect"
        "OOB"
    )

    for pat in "${EXPECTED_PATTERNS[@]}"; do
        if grep -qi "$pat" "$AP_FILE"; then
            pass "Anti-pattern covered: $pat"
        else
            fail "Anti-pattern missing: $pat"
        fi
    done

    # Each anti-pattern should have a Wrong and Right example
    WRONG_COUNT=$(grep -c '^\*\*Wrong\*\*' "$AP_FILE" || true)
    RIGHT_COUNT=$(grep -c '^\*\*Right\*\*' "$AP_FILE" || true)

    if (( WRONG_COUNT >= 5 )); then
        pass "Has $WRONG_COUNT 'Wrong' examples"
    else
        warn "Only $WRONG_COUNT 'Wrong' examples (expected 5+)"
    fi

    if (( RIGHT_COUNT >= 5 )); then
        pass "Has $RIGHT_COUNT 'Right' examples"
    else
        warn "Only $RIGHT_COUNT 'Right' examples (expected 5+)"
    fi
fi

# ── 5. Quarkus/Qute content validation ────────────────────────────────

echo ""
echo "=== Quarkus + Qute Content ==="

# SKILL.md must mention Quarkus stack essentials
for keyword in Quarkus Qute Panache HTMX "application.properties" Flyway; do
    if grep -rq "$keyword" "$SKILL_DIR"/*.md "$SKILL_DIR"/references/*.md 2>/dev/null; then
        pass "Skill pack covers '$keyword'"
    else
        fail "Skill pack missing '$keyword' coverage"
    fi
done

# rest-and-htmx.md should have Qute template examples
if grep -q "TemplateInstance" "$HTMX_FILE"; then
    pass "Qute TemplateInstance usage shown"
else
    fail "Qute TemplateInstance usage missing"
fi

if grep -q '@Inject Template' "$HTMX_FILE" || grep -q '@Inject.*Template' "$HTMX_FILE"; then
    pass "Qute @Inject Template pattern shown"
else
    fail "Qute @Inject Template pattern missing"
fi

# Endpoints should return TEXT_HTML for HTMX
if grep -q "TEXT_HTML" "$HTMX_FILE"; then
    pass "Endpoints produce TEXT_HTML for HTMX"
else
    fail "No TEXT_HTML endpoints shown"
fi

# ── 6. No-anti-pattern check in code examples ─────────────────────────

echo ""
echo "=== Code Example Hygiene ==="

# rest-and-htmx.md should not show fetch() + JSON in HTMX sections
# (allowed in the REST/JSON section, but not in HTMX patterns section)
HTMX_SECTION=$(sed -n '/## HTMX patterns/,$p' "$HTMX_FILE")

if echo "$HTMX_SECTION" | grep -q 'fetch('; then
    warn "HTMX section contains fetch() call — may confuse AI"
else
    pass "HTMX section has no fetch() calls"
fi

if echo "$HTMX_SECTION" | grep -q '\.json()'; then
    warn "HTMX section contains .json() call — may confuse AI"
else
    pass "HTMX section has no .json() calls"
fi

if echo "$HTMX_SECTION" | grep -q 'APPLICATION_JSON'; then
    warn "HTMX section references APPLICATION_JSON — may confuse AI"
else
    pass "HTMX section has no APPLICATION_JSON references"
fi

# ── Summary ────────────────────────────────────────────────────────────

echo ""
echo "=== Summary ==="
echo "  PASS: $PASS"
echo "  WARN: $WARN"
echo "  FAIL: $FAIL"

if (( FAIL > 0 )); then
    echo ""
    echo "Validation FAILED with $FAIL error(s)."
    exit 1
else
    echo ""
    echo "Validation PASSED."
    exit 0
fi
