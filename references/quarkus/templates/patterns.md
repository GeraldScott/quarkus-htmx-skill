# Quarkus Templates Usage Patterns (Qute)

Use these patterns for repeatable Qute and server-side rendering workflows.

## Pattern: Bootstrap server-side HTML with REST + Qute

When to use:

- You are building HTML endpoints rendered on the server.

Command:

```bash
quarkus create app com.acme:catalog-ui --extension='rest,qute,rest-qute' --no-code
```

If pages should be served directly from `templates/pub`, add `io.quarkiverse.qute.web:quarkus-qute-web`.

## Pattern: Prefer type-safe templates per resource

When to use:

- A resource owns one or more views and you want build-time validation.

Example:

```java
@Path("/orders")
class OrderResource {
    @CheckedTemplate
    static class Templates {
        static native TemplateInstance list(List<OrderView> orders);
        static native TemplateInstance detail(OrderView order);
    }

    @GET
    TemplateInstance list() {
        return Templates.list(service.list());
    }
}
```

Place templates under `src/main/resources/templates/OrderResource/`.

## Pattern: Keep templates declarative with extensions

When to use:

- A view needs computed properties or lightweight formatting.

Example:

```java
@TemplateExtension
class MoneyExtensions {
    static String currency(BigDecimal value) {
        return "$" + value.setScale(2, RoundingMode.HALF_UP);
    }
}
```

```html
{order.total.currency}
```

Prefer this over embedding formatting logic into template sections.

## Pattern: Share layouts with `include` and tags

When to use:

- Multiple pages reuse the same shell, header, or repeated component.

Example:

```html
{#include layout/base}
  {#title}Orders{/title}
  <main>
    {#orderTable orders=orders /}
  </main>
{/include}
```

Use `include` for page layout inheritance and `templates/tags/*` for reusable components.

## Pattern: Render partial updates with fragments

When to use:

- You need a reusable subtree for htmx/AJAX responses or repeated server-side partials.

Example:

```html
{#fragment row}
<tr>
  <td>{order.id}</td>
  <td>{order.status}</td>
</tr>
{/fragment}
```

```java
String html = ordersTemplate.getFragment("row")
        .data("order", order)
        .render();
```

## Pattern: Render emails, reports, and exports outside HTTP

When to use:

- Output is generated in schedulers, jobs, messaging consumers, or services.

Example:

```java
@ApplicationScoped
class ReportService {
    @Inject
    @Location("reports/daily")
    Template daily;

    String render(List<LineItem> items) {
        return daily.data("items", items).render();
    }
}
```

Return `String` when you need to persist, email, or attach the rendered output.

## Pattern: Localize copy with message bundles

When to use:

- UI strings must support more than one locale.

Example:

```java
@MessageBundle
interface Messages {
    @Message("Hello {name}!")
    String hello(String name);
}
```

```html
{msg:hello(user.name)}
```

Add `src/main/resources/messages/msg_<locale>.properties` files for localized variants.

## Pattern: Inline list with add-item form (HTMX)

When to use:

- A list should allow adding items without full page reload.

Example:

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

## Pattern: Delete with row removal (HTMX)

When to use:

- Deleting an item should remove its row from the DOM without a page reload.

Example template (`todo$item.html`):

```html
<li id="todo-{item.id}">
  {item.text}
  <button hx-delete="/ui/todos/{item.id}"
          hx-target="#todo-{item.id}"
          hx-swap="outerHTML"
          hx-confirm="Delete this task?">X</button>
</li>
```

Resource:

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

## Pattern: Click-to-edit (HTMX)

When to use:

- An item should switch between view and edit modes inline.

View mode (`todo$item.html`):

```html
<li id="todo-{item.id}">
  <span hx-get="/ui/todos/{item.id}/edit"
        hx-target="#todo-{item.id}"
        hx-swap="outerHTML"
        hx-trigger="click">{item.text}</span>
</li>
```

Edit mode (`todo$item$edit.html`):

```html
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

## Pattern: Search and filter with debounce (HTMX)

When to use:

- A search input should filter results as the user types, with a debounce delay.

Example:

```html
<input type="search"
       name="q"
       placeholder="Search products..."
       hx-get="/ui/products"
       hx-trigger="keyup changed delay:400ms, search"
       hx-target="#product-list"
       hx-swap="innerHTML"
       hx-push-url="true">
```

## Pattern: Infinite scroll (HTMX)

When to use:

- Content should load incrementally as the user scrolls down.

Example:

```html
{#if items_hasNext}
  <div hx-get="/ui/items?page={page + 1}"
       hx-trigger="revealed"
       hx-target="this"
       hx-swap="outerHTML">
    <span class="loading">Loading...</span>
  </div>
{/if}
```

## Pattern: Out-of-band swaps (HTMX)

When to use:

- A single server response should update multiple parts of the page.

Example:

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

## Pattern: CSRF protection with HTMX

When to use:

- **Every** HTMX application with mutating endpoints (POST, PUT, PATCH, DELETE).
  This is mandatory, not optional -- without CSRF protection, external sites can
  submit requests on behalf of authenticated users.

Configuration:

```properties
quarkus.csrf-reactive.enabled=true
quarkus.csrf-reactive.token-header-name=X-CSRF-TOKEN
quarkus.csrf-reactive.cookie-same-site=STRICT
```

Base template (include on every page):

```html
<meta name="csrf-token" content="{inject:csrf.token}">
<script>
  document.addEventListener('htmx:configRequest', (e) => {
    e.detail.headers['X-CSRF-TOKEN'] =
      document.querySelector('meta[name="csrf-token"]').content;
  });
</script>
```

See `references/htmx/security.md` for full CSRF guidance including the hidden
field approach and troubleshooting.

## Pattern: Server-Sent Events with HTMX

When to use:

- Real-time updates should stream from the server to the browser.

Resource:

```java
@GET
@Path("/stream")
@Produces(MediaType.SERVER_SENT_EVENTS)
public Multi<String> stream() {
    return eventBus.<String>publisher("updates")
        .onItem().transform(msg -> "data: " + msg + "\n\n");
}
```

Template:

```html
<div hx-ext="sse"
     sse-connect="/api/updates/stream"
     sse-swap="message"
     hx-target="#notifications"
     hx-swap="beforeend">
</div>
```

Add `htmx-ext-sse` script after HTMX.
