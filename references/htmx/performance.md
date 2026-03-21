# Performance Guidelines

## Return Minimal HTML

Return only the fragment that changed, not the full page layout.
Smaller responses = faster swaps.

## Fragment Caching

### Qute Template Caching

Qute templates are compiled at build time in Quarkus. For runtime caching of
rendered fragments, use Quarkus cache:

```java
@ApplicationScoped
public class SidebarService {

    @CacheResult(cacheName = "sidebar")
    public String renderSidebar() {
        return sidebar.data("links", getLinks()).render();
    }

    @CacheInvalidate(cacheName = "sidebar")
    public void invalidateSidebar() {
        // Called when sidebar data changes
    }
}
```

### HTTP Cache Headers

Set cache headers on semi-static fragments:

```java
@GET
@Path("/sidebar")
@Produces(MediaType.TEXT_HTML)
public Response sidebar() {
    String html = sidebar.data("links", getLinks()).render();
    return Response.ok(html)
        .header("Cache-Control", "max-age=3600, must-revalidate")
        .build();
}
```

### ETags for Conditional Responses

```java
@GET
@Path("/todos")
@Produces(MediaType.TEXT_HTML)
public Response list(
    @HeaderParam("If-None-Match") String ifNoneMatch
) {
    List<TodoDto> items = todoService.listAll();
    String etag = "\"" + items.hashCode() + "\"";

    if (etag.equals(ifNoneMatch)) {
        return Response.notModified().build();
    }

    return Response.ok(todos$list.data("items", items).render())
        .header("ETag", etag)
        .build();
}
```

## Debounce and Throttle

Debounce search inputs and expensive triggers:

```html
<input hx-get="/ui/search"
       hx-trigger="input changed delay:300ms"
       hx-target="#results">
```

Throttle rate-sensitive interactions:

```html
<button hx-post="/ui/like" hx-trigger="click throttle:1s">
```

## Lazy Loading

Use `intersect` to load content only when visible:

```html
<div hx-get="/ui/expensive-widget"
     hx-trigger="intersect once"
     hx-swap="outerHTML">
  <div class="skeleton-loader">Loading...</div>
</div>
```

## Preloading

Use the `preload` extension to fetch content on hover:

```html
<body hx-ext="preload">
  <a href="/page" hx-boost="true" preload="mousedown">Page</a>
</body>
```

## Request Deduplication

Use `hx-sync` to prevent duplicate requests:

```html
<form hx-post="/ui/save" hx-sync="this:abort">
  {! Only one request at a time; new one cancels previous !}
</form>
```

## Morphing (Preserve DOM State)

Use the `idiomorph` extension to merge DOM trees instead of replacing:

```html
<div hx-ext="morph" hx-get="/ui/content" hx-swap="morph:innerHTML">
```

Morphing preserves focus, scroll position, and CSS transition state by
diffing the DOM rather than replacing it wholesale.

## hx-preserve

Keep specific elements intact across swaps:

```html
<video id="player" hx-preserve>...</video>
<iframe id="embed" hx-preserve>...</iframe>
```

Requires `id` attribute. Use for media players, iframes, canvas elements.

## Minimize DOM Replacements

- Target the smallest possible element
- Use `beforeend`/`afterbegin` for adding items (avoids re-rendering entire lists)
- Use `hx-select` to extract only needed parts from larger responses

## Avoid Excessive Polling

- Prefer SSE or WebSockets for real-time data
- If polling, use reasonable intervals (`every 10s`, not `every 1s`)
- Use conditional polling: `hx-trigger="every 5s [shouldPoll]"`
- Server returns 286 to stop polling when done

## Quarkus Production Checklist

- [ ] Qute templates compiled at build time (automatic in native/JVM mode)
- [ ] HTTP cache headers set on semi-static fragments
- [ ] ETag support for conditional responses on list endpoints
- [ ] Debouncing on all search/filter inputs (delay:300ms minimum)
- [ ] `hx-sync` on all forms to prevent duplicate submissions
- [ ] Lazy loading for below-fold content (`intersect once`)
- [ ] `hx-indicator` on all async operations for perceived performance
- [ ] Fragment responses are minimal (no full layout wrappers)
- [ ] Quarkus HTTP compression enabled (`quarkus.http.enable-compression=true`)
- [ ] Consider `@CacheResult` for expensive fragment rendering
- [ ] Use `hx-push-url` for navigation to enable browser back/forward caching
- [ ] Loading states and skeleton loaders for all async content
