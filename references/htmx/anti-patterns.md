# Anti-Patterns

## JSON Instead of HTML

Returning JSON and building DOM client-side defeats the purpose of HTMX.

```java
// BAD -- returns JSON, requires client-side rendering
@GET
@Path("/todos")
@Produces(MediaType.APPLICATION_JSON)
public List<TodoDto> list() {
    return todoService.listAll();
}

// GOOD -- returns rendered HTML fragment
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

## SPA State Management

Recreating React/Vue-like client-side state management. HTMX keeps state on the server.
Use sessions, databases, or URL parameters -- not localStorage for business data.

## Full Layout in Fragment

Returning `<html><head>...</head><body>...</body></html>` for an HTMX request.
Always check `HX-Request` header and return only the fragment.

```java
// BAD -- always returns full page
@GET
@Produces(MediaType.TEXT_HTML)
public TemplateInstance list() {
    return todos.data("items", todoService.listAll()); // full page with base.html
}

// GOOD -- context-aware response
@GET
@Produces(MediaType.TEXT_HTML)
public TemplateInstance list(@HeaderParam("HX-Request") String hxRequest) {
    List<TodoDto> items = todoService.listAll();
    return "true".equals(hxRequest)
        ? todos$list.data("items", items)    // fragment only
        : todos.data("items", items);        // full page
}
```

## No History Handling

Forgetting `hx-push-url` on navigation-like actions (pagination, tab switching, filters).
Users expect the back button to work.

```html
{! BAD: no history !}
<a hx-get="/ui/page/2" hx-target="#content">Page 2</a>

{! GOOD: preserves history !}
<a hx-get="/ui/page/2" hx-target="#content" hx-push-url="true">Page 2</a>
```

## Polling Abuse

Using `every 1s` when data doesn't change that frequently.
Prefer SSE/WebSockets for real-time, or use longer polling intervals with conditions.

## Validation Redirect

Redirecting on validation error instead of returning the form with errors.
Use HTTP 422 + re-rendered form fragment with error messages.

```java
// BAD -- redirect loses form state
@POST
@Transactional
public Response create(@FormParam("title") String title) {
    if (title == null || title.isBlank()) {
        return Response.seeOther(URI.create("/ui/todos?error=title-required")).build();
    }
    // ...
}

// GOOD -- return form with errors and 422 status
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

## Not Using OOB

Making separate AJAX calls or using JavaScript to update multiple UI areas
when a single response with `hx-swap-oob` would suffice.

## Ignoring hx-sync

Not using `hx-sync` on forms, allowing duplicate submissions or race conditions.

```html
{! BAD: rapid clicks send multiple requests !}
<button hx-post="/ui/save">Save</button>

{! GOOD: prevent duplicate submissions !}
<button hx-post="/ui/save" hx-sync="this:drop">Save</button>
```

## Overusing JavaScript

Writing JavaScript event handlers when htmx attributes would work.
Check if `hx-trigger`, `hx-confirm`, `hx-indicator`, `hx-on:*` can solve it first.

## Missing hx-disable on User Content

Rendering user-generated HTML without `hx-disable`, allowing attribute injection attacks.

```html
{! BAD -- user could inject hx-post, hx-delete etc. !}
<div>{userContent.raw}</div>

{! GOOD -- Qute auto-escaping prevents attribute injection !}
<div>{userContent}</div>

{! ALSO GOOD -- hx-disable as defense in depth !}
<div hx-disable>{userContent.raw}</div>
```

## Using .raw on Untrusted Data

Qute auto-escapes output by default. Using `.raw` on user input bypasses this
and creates XSS vulnerabilities. Only use `.raw` for content you fully control.

## Accessibility Anti-Patterns

### Missing ARIA Attributes

```html
{! BAD: no accessibility hints !}
<button hx-get="/ui/load-more" hx-target="#items" hx-swap="beforeend">
  Load More
</button>

{! GOOD: screen readers understand the interaction !}
<button hx-get="/ui/load-more"
        hx-target="#items"
        hx-swap="beforeend"
        aria-label="Load more items">
  Load More
</button>
```

### No Loading State Announcement

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

### No Error Announcement for Assistive Technology

Always provide a live region for dynamic error messages:

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

### Non-Keyboard-Accessible HTMX Elements

Ensure all interactive HTMX elements are keyboard-accessible. Use `<button>` or
`<a>` elements. Avoid adding `hx-get`/`hx-post` to `<div>` or `<span>` without
proper `role`, `tabindex`, and keyboard event handling.
