# REST, Qute Templates & HTMX Reference

## JAX-RS Resource patterns

### Resource class conventions

```java
@Path("/api/products")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@ApplicationScoped
@Tag(name = "Products")                    // OpenAPI grouping
public class ProductResource {

    @Inject ProductService productService;

    @GET
    @Operation(summary = "List all products")
    public List<ProductDto> list(
        @QueryParam("page") @DefaultValue("0") int page,
        @QueryParam("size") @DefaultValue("20") int size
    ) {
        return productService.list(page, size);
    }

    @GET
    @Path("/{id}")
    public ProductDto get(@PathParam("id") Long id) {
        return productService.findById(id)
            .orElseThrow(() -> new NotFoundException("Product " + id + " not found"));
    }

    @POST
    @Transactional
    public Response create(@Valid CreateProductRequest req) {
        ProductDto created = productService.create(req);
        return Response
            .created(URI.create("/api/products/" + created.id()))
            .entity(created)
            .build();
    }

    @PUT
    @Path("/{id}")
    @Transactional
    public ProductDto update(@PathParam("id") Long id, @Valid UpdateProductRequest req) {
        return productService.update(id, req);
    }

    @DELETE
    @Path("/{id}")
    @Transactional
    public void delete(@PathParam("id") Long id) {
        productService.delete(id);
    }
}
```

### Exception mapping

Use `@ServerExceptionMapper` (Quarkus-native, simpler than the JAX-RS `ExceptionMapper` interface):

```java
@ApplicationScoped
public class ExceptionMappers {

    @ServerExceptionMapper
    public Response handleAppException(AppException ex) {
        return Response.status(ex.getStatus())
            .entity(new ErrorResponse(ex.getMessage()))
            .build();
    }

    @ServerExceptionMapper
    public Response handleConstraintViolation(ConstraintViolationException ex) {
        var errors = ex.getConstraintViolations().stream()
            .map(v -> v.getPropertyPath() + ": " + v.getMessage())
            .toList();
        return Response.status(400).entity(new ErrorResponse(errors)).build();
    }
}
```

Quarkus also automatically maps common exceptions without any mapper:
- `NotFoundException` → 404
- `BadRequestException` → 400

For HTMX endpoints, return an error fragment instead of JSON:

```java
@ServerExceptionMapper
public TemplateInstance handleNotFound(NotFoundException ex) {
    return error.data("message", ex.getMessage()).data("status", 404);
}
```

### DTO with Java Records (preferred)

```java
public record CreateProductRequest(
    @NotBlank String name,
    @NotNull @DecimalMin("0.01") BigDecimal price,
    @Positive int stock
) {}

public record ProductDto(Long id, String name, BigDecimal price, int stock) {
    public static ProductDto from(Product p) {
        return new ProductDto(p.id, p.name, p.price, p.stock);
    }
}
```

### Form data (for HTMX POST)

```java
@POST
@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
@Produces(MediaType.TEXT_HTML)
@Transactional
public TemplateInstance addToCart(
    @FormParam("productId") Long productId,
    @FormParam("quantity") int quantity
) {
    Cart cart = cartService.add(productId, quantity);
    return cartFragment.data("cart", cart);
}
```

---

## Qute Template Engine

### Template injection and naming

```java
@Inject Template products;            // → templates/products.html
@Inject Template products$row;        // → templates/products$row.html (fragment)
@Inject Template emails$welcome;      // → templates/emails/welcome.html
```

Convention: `$` in the Java field name maps to `/` in the template path for fragments,
and to a `$` in the filename for same-directory fragments.

### Qute syntax reference

```html
{! Comment — not rendered !}

{! Variable output — auto HTML-escaped !}
{product.name}

{! Raw (unescaped) output — use carefully !}
{product.description.raw}

{! Conditional !}
{#if product.stock > 0}
  <span class="in-stock">In Stock</span>
{#else}
  <span class="out-of-stock">Sold Out</span>
{/if}

{! Loop !}
{#for p in products}
  <tr data-id="{p.id}">
    <td>{p.name}</td>
    <td>{p.price}</td>
  </tr>
{#else}
  <tr><td colspan="2">No products found.</td></tr>
{/for}

{! Loop metadata !}
{#for p in products}
  {#if p_count == 0}first{/if}
  {p_index}: {p.name}   {! 0-based index !}
{/for}

{! Include another template !}
{#include partials/nav.html /}

{! Include with data injection !}
{#include products$row product=p /}

{! Elvis operator — default value if null !}
{product.category ?: 'Uncategorised'}

{! Local variables with #let — reduces repetition !}
{#let fullName=customer.firstName + ' ' + customer.lastName}
  <span>{fullName}</span>
  <a href="mailto:{customer.email}">{fullName}</a>
{/let}

{! Template inheritance — base.html defines {#insert content/} !}
{#include base.html}
{#content}
  <h1>Products</h1>
{/content}
```

### Base layout pattern

```html
<!-- templates/base.html -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{#insert title}My App{/insert}</title>
  <script src="https://unpkg.com/htmx.org@2"></script>
  <link rel="stylesheet" href="/css/app.css">
</head>
<body>
  {#include partials/nav.html /}
  <main>
    {#insert content /}
  </main>
</body>
</html>
```

```html
<!-- templates/products.html -->
{#include base.html}

{#title}Products — My App{/title}

{#content}
<h1>Products</h1>
<div id="product-list">
  {#for p in products}
    {#include products$row product=p /}
  {/for}
</div>
{/content}
```

### Inline fragments (Qute 3.x+ — preferred over file-based `$` fragments)

Define fragments directly inside a template with `{#fragment}`. This keeps the full
page and its HTMX partials in one file, avoiding fragment file sprawl.

```html
<!-- templates/products.html -->
{#include base.html}
{#content}
<h1>Products</h1>
<div id="product-list">
  {#for p in products}
    {#fragment id=row}
    <tr id="product-{p.id}">
      <td>{p.name}</td>
      <td>{p.price}</td>
    </tr>
    {/fragment}
  {/for}
</div>
{/content}
```

Reference the fragment from Java with `$` notation — Quarkus resolves it to the
`{#fragment id=row}` inside `products.html`:

```java
@CheckedTemplate
public class Templates {
    public static native TemplateInstance products(List<ProductDto> products);
    public static native TemplateInstance products$row(ProductDto p);   // the {#fragment id=row}
}
```

**When to use inline vs. file fragments:**
- **Inline `{#fragment}`** — default choice. Template and fragment live together, easier to maintain.
- **Separate `$` file** — use when the fragment is shared across multiple templates.

### Type-safe templates (recommended for production)

```java
@CheckedTemplate
public class Templates {
    public static native TemplateInstance products(List<ProductDto> products);
    public static native TemplateInstance products$row(ProductDto product);
}

// Usage in resource:
return Templates.products(productService.listAll());
```

Type-safe templates validate data bindings at build time — Quarkus will fail the build
if you access a property that doesn't exist on the data object.

---

## HTMX patterns with Qute

### Core HTMX attribute cheat sheet

| Attribute | Purpose |
|-----------|---------|
| `hx-get="/path"` | GET on trigger (default: click) |
| `hx-post="/path"` | POST on trigger |
| `hx-put/hx-patch/hx-delete` | Other HTTP methods |
| `hx-target="#element-id"` | Where to put the response |
| `hx-swap="innerHTML"` | How to swap (see swap strategy guide below) |
| `hx-trigger="click"` | Event to trigger on (see trigger reference below) |
| `hx-indicator="#spinner"` | Element to show/hide during request |
| `hx-push-url="true"` | Push URL to browser history |
| `hx-boost="true"` | Upgrade `<a>` and `<form>` to HTMX requests |
| `hx-confirm="Sure?"` | Confirmation dialog before request |
| `hx-vals='{"key":"val"}'` | Extra values to submit |
| `hx-headers='{"X-Key":"val"}'` | Extra request headers |
| `hx-select=".result"` | Pick a CSS selector from the response to swap (ignore the rest) |
| `hx-select-oob=".alert:afterbegin"` | Pick extra selectors from the response for OOB swap |
| `hx-sync="closest form:abort"` | Coordinate concurrent requests (abort, queue, drop, replace) |
| `hx-encoding="multipart/form-data"` | Required for file uploads |
| `hx-disabled-elt="this"` | Disable element(s) during the request (prevents double-submit) |
| `hx-preserve="true"` | Keep element unchanged across swaps (e.g., video player, scroll position) |
| `hx-params="*"` | Control which params are submitted (`*`, `none`, `not field1`, `field1,field2`) |

### Swap strategies

| Strategy | Effect | Use when |
|----------|--------|----------|
| `innerHTML` (default) | Replace inner content of target | Updating a list container, search results |
| `outerHTML` | Replace the entire target element | Replacing a row, click-to-edit, delete |
| `beforebegin` | Insert before the target element | Adding a sibling above |
| `afterbegin` | Insert as first child of target | Prepending to a list |
| `beforeend` | Insert as last child of target | Appending to a list |
| `afterend` | Insert after the target element | Adding a sibling below |
| `delete` | Remove the target element | Delete operations (no response body needed) |
| `none` | Don't swap, just process response headers | Fire `HX-Trigger` events without DOM changes |

**Swap modifiers** — append after the strategy, space-separated:
```html
hx-swap="innerHTML swap:300ms settle:100ms"
hx-swap="innerHTML show:top"              <!-- scroll target to top after swap -->
hx-swap="innerHTML transition:true"       <!-- use View Transition API -->
hx-swap="outerHTML scroll:#container:top" <!-- scroll a specific element -->
```

- `swap:<time>` — delay before old content is removed
- `settle:<time>` — delay before new content settles (for CSS transitions)
- `transition:true` — use the View Transition API for animated swaps
- `show:<target>:top|bottom` — scroll into view after swap

**Choose swap based on intent:** use `outerHTML` when replacing an item, `beforeend` when appending,
`innerHTML` when refreshing a container. Avoid replacing large containers when only a fragment changed.

### Trigger reference

| Trigger | Fires when | Example |
|---------|-----------|---------|
| `click` (default) | Element clicked | Buttons, links |
| `change` | Value changed | Select, checkbox, radio |
| `submit` | Form submitted | Forms |
| `keyup` | Key released | Text inputs |
| `load` | Element loaded into DOM | Lazy-load content on page render |
| `revealed` | Element scrolls into viewport | Infinite scroll sentinel |
| `intersect` | Element enters viewport (IntersectionObserver) | Like `revealed` with threshold control |
| `every <time>` | Polling interval | `every 30s` for periodic refresh |

**Trigger modifiers:**
```html
hx-trigger="keyup changed delay:400ms"   <!-- debounce: wait 400ms after last keyup, only if value changed -->
hx-trigger="click throttle:1s"            <!-- throttle: at most once per second -->
hx-trigger="load delay:200ms"             <!-- delay initial load -->
hx-trigger="intersect threshold:0.5"      <!-- fire when 50% visible -->
hx-trigger="click from:#other-element"    <!-- listen on a different element -->
hx-trigger="click target:#child"          <!-- only from a specific child -->
hx-trigger="click consume"                <!-- stop event propagation -->
hx-trigger="click once"                   <!-- fire only once -->
hx-trigger="click[ctrlKey]"              <!-- event filter: only on Ctrl+click -->
hx-trigger="keyup[key=='Enter']"         <!-- event filter: only on Enter key -->
```

**Event filters** use JS expressions in `[]` evaluated against the event object. Use for
keyboard shortcuts, modifier keys, or conditional triggers without extra JavaScript.

**Always debounce expensive triggers** (search, typeahead). Prefer `delay:` over `throttle:` for input fields.
Prefer SSE over `every` polling when real-time updates are needed.

### HTMX event lifecycle

Use these events in `hx-on::<event>` attributes or `document.addEventListener()` for cross-cutting concerns.

| Event | When | Common use |
|-------|------|------------|
| `htmx:configRequest` | Before request is sent | Add headers (CSRF tokens), modify params |
| `htmx:beforeRequest` | After config, before send | Show spinners, disable buttons |
| `htmx:afterRequest` | After response received | Reset forms, hide spinners |
| `htmx:beforeSwap` | Before DOM is updated | Modify/cancel swap, handle error status codes |
| `htmx:afterSwap` | After DOM is updated | Initialize third-party JS on new content |
| `htmx:afterSettle` | After settle delay completes | Trigger CSS animations |
| `htmx:responseError` | Server returned error status | Show error toasts |
| `htmx:sendError` | Network failure | Show offline warning |
| `htmx:timeout` | Request timed out | Retry or show timeout message |
| `htmx:load` | New content loaded into DOM | Initialize third-party JS (datepickers, charts) on swapped content |

```html
<!-- Inline event handler — reset form after successful POST -->
<form hx-post="/ui/items"
      hx-target="#item-list"
      hx-swap="beforeend"
      hx-on::after-request="this.reset()">
```

**Rule: prefer `hx-on::` attributes over `<script>` blocks. Use global event listeners only for
cross-cutting concerns (error handling). For CSRF, use `hx-headers` with Qute injection
(see CSRF section below). Never use events to manually rebuild DOM.**

### Common patterns

**Inline list with add-item form:**
```html
<ul id="todo-list">
  {#for item in items}
    {#include todo$item item=item /}
  {/for}
</ul>

<form hx-post="/ui/todos"
      hx-target="#todo-list"
      hx-swap="beforeend"
      hx-on::after-request="this.reset()">
  <input name="text" placeholder="New task" required>
  <button type="submit">Add</button>
</form>
```

**Delete with row removal:**
```html
<!-- In todo$item.html -->
<li id="todo-{item.id}">
  {item.text}
  <button hx-delete="/ui/todos/{item.id}"
          hx-target="#todo-{item.id}"
          hx-swap="outerHTML"
          hx-confirm="Delete this task?">✕</button>
</li>
```

```java
@DELETE
@Path("/{id}")
@Transactional
@Produces(MediaType.TEXT_HTML)
public Response delete(@PathParam("id") Long id) {
    todoService.delete(id);
    return Response.ok("").build();   // Empty response + outerHTML swap removes the row
}
```

**Click-to-edit:**
```html
<!-- todo$item.html — view mode -->
<li id="todo-{item.id}">
  <span hx-get="/ui/todos/{item.id}/edit"
        hx-target="#todo-{item.id}"
        hx-swap="outerHTML"
        hx-trigger="click">{item.text}</span>
</li>

<!-- todo$item$edit.html — edit mode -->
<li id="todo-{item.id}">
  <form hx-put="/ui/todos/{item.id}"
        hx-target="#todo-{item.id}"
        hx-swap="outerHTML">
    <input name="text" value="{item.text}">
    <button type="submit">Save</button>
    <button type="button"
            hx-get="/ui/todos/{item.id}"
            hx-target="#todo-{item.id}"
            hx-swap="outerHTML">Cancel</button>
  </form>
</li>
```

**Fragment vs full page (HX-Request detection):**
```java
@GET
@Produces(MediaType.TEXT_HTML)
public TemplateInstance list(@HeaderParam("HX-Request") boolean htmx) {
    List<ItemDto> items = itemService.listAll();
    if (htmx) {
        return items$list.data("items", items);    // Fragment only
    }
    return items.data("items", items);              // Full page with layout
}
```

**Search / filter with debounce:**
```html
<input type="search"
       name="q"
       placeholder="Search products…"
       hx-get="/ui/products"
       hx-trigger="keyup changed delay:400ms, search"
       hx-target="#product-list"
       hx-swap="innerHTML"
       hx-push-url="true">
```

**Infinite scroll / load more:**
```html
<!-- Last item in the list triggers the next page load -->
{#if items_hasNext}
  <div hx-get="/ui/items?page={page + 1}"
       hx-trigger="revealed"
       hx-target="this"
       hx-swap="outerHTML">
    <span class="loading">Loading…</span>
  </div>
{/if}
```

**Request synchronisation (hx-sync) — prevent race conditions:**
```html
<!-- Abort in-flight request when a new one starts (e.g., rapid filter clicks) -->
<select hx-get="/ui/products"
        hx-target="#product-list"
        hx-sync="this:replace">

<!-- Queue form submissions so none are lost -->
<form hx-post="/ui/orders"
      hx-sync="this:queue first">
```

| Strategy | Effect |
|----------|--------|
| `drop` | Ignore new request while one is in flight |
| `abort` | Abort in-flight request, send new one |
| `replace` | Abort in-flight, send new (alias for abort) |
| `queue first` | Queue the first new request only |
| `queue last` | Queue only the most recent request (default queue) |
| `queue all` | Queue every request |

**Always add `hx-sync` to forms and filters** to prevent duplicate submissions and stale responses.

**File upload with hx-encoding:**
```html
<form hx-post="/ui/uploads"
      hx-encoding="multipart/form-data"
      hx-target="#upload-result">
  <input type="file" name="file">
  <button type="submit" hx-disabled-elt="this">Upload</button>
</form>
```

```java
@POST
@Path("/uploads")
@Consumes(MediaType.MULTIPART_FORM_DATA)
@Produces(MediaType.TEXT_HTML)
@Transactional
public TemplateInstance upload(@MultipartForm FileUploadForm form) {
    // form.file is a FileUpload from quarkus-resteasy-reactive
    String path = storageService.store(form.file);
    return uploadResult.data("path", path);
}
```

**Out-of-band swaps (OOB) — update multiple parts of the page from one response:**
```html
<!-- Server returns this; HTMX updates both #cart-count AND the main target -->
<span id="cart-count" hx-swap-oob="true">{cartCount}</span>
```

```java
// Resource returns a fragment that includes OOB element
return cartRow
    .data("item", newItem)
    .data("cartCount", cart.size());
// Template includes both the row and the OOB badge
```

### CSRF protection with HTMX

Add the `quarkus-rest-csrf` extension (formerly `quarkus-csrf-reactive`):

```properties
# Config prefix is quarkus.rest-csrf.*
quarkus.rest-csrf.form-field-name=csrf-token
# Custom header name (default is X-CSRF-TOKEN)
quarkus.rest-csrf.token-header-name=X-CSRF-TOKEN
```

For HTMX requests that are not standard form submissions, inject the token via
the `hx-headers` attribute using Qute's `{inject:csrf.*}` namespace — this is
the Quarkus-native approach and avoids manual JavaScript:

```html
<!-- In base.html — applies CSRF header to all HTMX requests in the body -->
<body hx-headers='{"{inject:csrf.headerName}":"{inject:csrf.token}"}'>
```

For forms submitted normally (not via HTMX), Qute automatically injects a hidden
`csrf-token` field when using `{inject:csrf.token}` inside a `<form>`.

### Security beyond CSRF

**XSS prevention:** Qute auto-escapes all `{expressions}` by default. Only `{value.raw}`
bypasses escaping — never use `.raw` on user-supplied content. This makes Qute inherently
safer than most template engines for HTMX fragment responses.

**Content Security Policy (CSP):** Add via Quarkus HTTP headers to prevent inline script
injection. HTMX works without `unsafe-inline` because it uses attributes, not script blocks:

```properties
quarkus.http.header."Content-Security-Policy".value=default-src 'self'; script-src 'self' https://unpkg.com; style-src 'self' 'unsafe-inline'
```

**Endpoint-level authorisation with `@RolesAllowed`:**

```java
@GET
@Path("/admin/users")
@RolesAllowed("admin")
@Produces(MediaType.TEXT_HTML)
public TemplateInstance adminUsers() {
    return adminUsers.data("users", userService.listAll());
}
```

Requires `quarkus-security` + an identity provider (`quarkus-oidc`, `quarkus-smallrye-jwt`,
or `quarkus-security-jpa`). For HTMX requests hitting a 403, return an error fragment via
`@ServerExceptionMapper` rather than a redirect.

### Server-Sent Events with HTMX (real-time updates)

```java
@GET
@Path("/stream")
@Produces(MediaType.SERVER_SENT_EVENTS)
public Multi<String> stream() {
    return eventBus.<String>publisher("updates")
        .onItem().transform(msg -> "data: " + msg + "\n\n");
}
```

```html
<div hx-ext="sse"
     sse-connect="/api/updates/stream"
     sse-swap="message"
     hx-target="#notifications"
     hx-swap="beforeend">
</div>
```

Add `htmx-ext-sse` script after HTMX.

**WebSocket alternative** — use `hx-ext="ws"` when bidirectional communication is needed
(e.g., chat). SSE is simpler and sufficient for server-to-client push (notifications,
live dashboards). Prefer SSE unless clients need to send messages over the same connection.

```html
<div hx-ext="ws" ws-connect="/ws/chat">
  <div id="messages"></div>
  <form ws-send>
    <input name="message">
    <button type="submit">Send</button>
  </form>
</div>
```

Add `htmx-ext-ws` script after HTMX.

---

## Response helpers

```java
// Redirect after POST (Post/Redirect/Get pattern)
return Response.seeOther(URI.create("/ui/products")).build();

// Trigger HTMX events from the server
return Response.ok(fragment.render())
    .header("HX-Trigger", "itemAdded")
    .header("HX-Redirect", "/ui/items")
    .build();

// Useful HX-* response headers:
// HX-Trigger              — fire a client-side event immediately
// HX-Trigger-After-Swap   — fire event after swap completes
// HX-Trigger-After-Settle — fire event after settle completes (CSS transitions done)
// HX-Redirect             — redirect (full page)
// HX-Location             — client-side redirect without full page reload (like hx-boost)
// HX-Push-Url             — update browser URL without redirect
// HX-Reswap               — override the hx-swap on the request
// HX-Retarget             — override the hx-target on the request
// HX-Refresh              — force a full page reload (true)

// HX-Trigger with JSON payload (pass data to client-side event listeners):
// .header("HX-Trigger", "{\"showToast\":{\"level\":\"success\",\"message\":\"Saved!\"}}")
```
