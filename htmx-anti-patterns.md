# HTMX Anti-Patterns (Quarkus + Qute)

When building HTMX-driven UIs, **never** fall back to SPA-style patterns.
If a solution mimics SPA architecture, stop and restructure.

---

## 1. JSON instead of HTML

**Wrong** — returning JSON and building DOM client-side:
```java
@GET
@Path("/search")
@Produces(MediaType.APPLICATION_JSON)          // BAD
public List<ProductDto> search(@QueryParam("q") String q) {
    return productService.search(q);
}
```
```html
<!-- BAD — fetch + manual DOM construction -->
<script>
fetch('/api/products/search?q=' + q)
  .then(r => r.json())
  .then(data => {
    container.innerHTML = data.map(p => `<div>${p.name}</div>`).join('');
  });
</script>
```

**Right** — server returns rendered HTML fragment:
```java
@GET
@Path("/search")
@Produces(MediaType.TEXT_HTML)
public TemplateInstance search(@QueryParam("q") String q) {
    return productList.data("products", productService.search(q));
}
```
```html
<input type="search" name="q"
       hx-get="/ui/products/search"
       hx-target="#product-list"
       hx-swap="innerHTML"
       hx-trigger="keyup changed delay:400ms">
```

**Rule: Server returns HTML, not JSON. Never rebuild DOM with client-side JavaScript.**

---

## 2. SPA state management

**Wrong** — recreating React-like state in JavaScript:
```html
<script>
let state = { items: [], filter: '', page: 0 };
function render() { /* rebuild entire UI from state */ }
function addItem(item) { state.items.push(item); render(); }
</script>
```

**Right** — the server is the state. Each interaction fetches a fresh HTML fragment:
```html
<form hx-post="/ui/items"
      hx-target="#item-list"
      hx-swap="beforeend"
      hx-on::after-request="this.reset()">
  <input name="name" required>
  <button type="submit">Add</button>
</form>
```

**Rule: The server owns state. The browser renders HTML it receives.**

---

## 3. Full layout in a fragment response

**Wrong** — returning `<html>...</html>` for an HTMX request:
```java
@GET
@Path("/{id}")
@Produces(MediaType.TEXT_HTML)
public TemplateInstance get(@PathParam("id") Long id) {
    // Returns full page with base layout every time — even for HTMX partial requests
    return fullPage.data("item", itemService.find(id));
}
```

**Right** — detect `HX-Request` header and return only the fragment:
```java
@GET
@Path("/{id}")
@Produces(MediaType.TEXT_HTML)
public TemplateInstance get(@PathParam("id") Long id,
                            @HeaderParam("HX-Request") boolean htmx) {
    ItemDto item = itemService.find(id);
    if (htmx) {
        return items$row.data("item", item);       // Fragment only
    }
    return items.data("items", List.of(item));      // Full page for direct navigation
}
```

**Rule: Detect `HX-Request` header. Return fragments for HTMX, full pages for direct navigation.**

---

## 4. No history handling

**Wrong** — pagination/filtering without updating the browser URL:
```html
<button hx-get="/ui/products?page=2"
        hx-target="#product-list"
        hx-swap="innerHTML">Next</button>
<!-- User can't bookmark or share the filtered/paged view -->
```

**Right** — push URL to browser history:
```html
<button hx-get="/ui/products?page=2"
        hx-target="#product-list"
        hx-swap="innerHTML"
        hx-push-url="true">Next</button>
```

**Rule: Use `hx-push-url` for pagination, filters, and any state a user should be able to bookmark.**

---

## 5. Polling abuse

**Wrong** — aggressive polling with no reason:
```html
<div hx-get="/ui/notifications"
     hx-trigger="every 1s"
     hx-target="#notifications">
</div>
```

**Right** — use reasonable intervals or SSE for real-time needs:
```html
<!-- Polling: only when appropriate, with sane intervals -->
<div hx-get="/ui/notifications"
     hx-trigger="every 30s"
     hx-target="#notifications">
</div>

<!-- Better for real-time: Server-Sent Events -->
<div hx-ext="sse"
     sse-connect="/api/notifications/stream"
     sse-swap="message"
     hx-target="#notifications"
     hx-swap="beforeend">
</div>
```

**Rule: Avoid unnecessary polling. Prefer SSE for real-time updates. If polling, use intervals of 10s+.**

---

## 6. Validation redirect

**Wrong** — redirecting on validation failure (loses form state):
```java
@POST
@Transactional
@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
@Produces(MediaType.TEXT_HTML)
public Response create(@FormParam("name") String name) {
    if (name == null || name.isBlank()) {
        return Response.seeOther(URI.create("/ui/items?error=name-required")).build();
    }
    // ...
}
```

**Right** — return the form fragment with inline error messages:
```java
@POST
@Transactional
@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
@Produces(MediaType.TEXT_HTML)
public Response create(@FormParam("name") String name) {
    if (name == null || name.isBlank()) {
        return Response.status(422)
            .entity(itemForm.data("error", "Name is required").data("name", name).render())
            .build();
    }
    Item item = itemService.create(name);
    return Response.ok(items$row.data("item", item).render()).build();
}
```

**Rule: On validation failure, return the form with errors inline (HTTP 422). Never redirect — it loses user input.**

---

## 7. Not using OOB swaps

**Wrong** — updating multiple page areas with separate JavaScript calls:
```html
<script>
fetch('/api/cart/add', { method: 'POST', body: formData })
  .then(r => r.json())
  .then(data => {
    document.getElementById('cart-items').innerHTML = renderItems(data.items);
    document.getElementById('cart-count').textContent = data.count;
    document.getElementById('cart-total').textContent = data.total;
  });
</script>
```

**Right** — use out-of-band (OOB) swaps in a single HTMX response:
```html
<!-- Server response includes the main target content + OOB elements -->

<!-- Main response (swapped into hx-target) -->
<tr id="cart-row-{item.id}">
  <td>{item.name}</td>
  <td>{item.quantity}</td>
</tr>

<!-- OOB swaps — HTMX handles these automatically -->
<span id="cart-count" hx-swap-oob="true">{cartCount}</span>
<span id="cart-total" hx-swap-oob="true">{cartTotal}</span>
```

```java
// Qute template returns all three elements in one response
return cartRow.data("item", newItem)
              .data("cartCount", cart.itemCount())
              .data("cartTotal", cart.total());
```

**Rule: Use `hx-swap-oob="true"` to update multiple page areas from a single response. Never use JavaScript for multi-target updates.**
