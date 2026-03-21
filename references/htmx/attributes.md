# HTMX Attributes

## Core Request Attributes

Issue AJAX requests with the corresponding HTTP method. Value is the URL.

- `hx-get` -- GET request
- `hx-post` -- POST request
- `hx-put` -- PUT request
- `hx-patch` -- PATCH request
- `hx-delete` -- DELETE request

Server must return HTML fragments, not JSON.

## Targeting

### hx-target

CSS selector specifying which element receives the response. Defaults to the element itself.

Extended selectors (htmx-specific, not standard CSS):

```html
hx-target="this"                   <!-- the element itself (default) -->
hx-target="#todo-list"             <!-- by ID -->
hx-target="closest tr"            <!-- nearest ancestor matching selector -->
hx-target="find .result"          <!-- first child matching selector -->
hx-target="next .sibling"         <!-- next sibling matching selector -->
hx-target="previous .sibling"     <!-- previous sibling matching selector -->
```

### hx-select

Pick only part of the server response for swapping (client-side filtering):

```html
<button hx-get="/full-page" hx-select="#content-area" hx-target="#main">
  Load Content
</button>
```

### hx-select-oob

Select elements from the response for out-of-band swapping:

```html
<button hx-get="/info"
        hx-select="#info-details"
        hx-swap="outerHTML"
        hx-select-oob="#alert:afterbegin, #count:innerHTML">
  Get Info
</button>
```

## Attribute Inheritance

Children inherit hx-target, hx-swap, hx-boost, and other attributes from parents.
Set once on a container; all child elements use it:

```html
<div hx-target="#results" hx-swap="innerHTML">
  <button hx-get="/page/1">Page 1</button>   <!-- inherits target + swap -->
  <button hx-get="/page/2">Page 2</button>   <!-- inherits target + swap -->
  <button hx-get="/other" hx-target="#other"> <!-- overrides target -->
</div>
```

## History

- `hx-push-url="true"` -- push request URL into browser history
- `hx-push-url="/custom"` -- push a custom URL
- `hx-replace-url="true"` -- replace current URL (no new history entry)
- `hx-history="false"` -- prevent page from being cached in history (for sensitive data)
- `hx-history-elt` -- element whose innerHTML is saved/restored for history

## Boost

`hx-boost="true"` progressively enhances links and forms to use AJAX:

```html
<nav hx-boost="true">
  <a href="/dashboard">Dashboard</a>    <!-- becomes hx-get="/dashboard" -->
  <a href="/settings">Settings</a>
  <a href="/file.pdf" hx-boost="false">Download</a>  <!-- opt out -->
</nav>
```

Boosted requests send `HX-Boosted: true` header. Use with `head-support` extension
to update `<head>` elements (title, CSS) on navigation.

## Other Important Attributes

- `hx-confirm="Delete?"` -- prompt before request
- `hx-include="[name='token']"` -- include additional element values in request
- `hx-vals='{"key": "value"}'` -- add values to request (JSON format). Always validate these server-side -- clients can modify `hx-vals` freely
- `hx-headers='{"X-Custom": "value"}'` -- add custom headers
- `hx-indicator="#spinner"` -- show element during request (via `.htmx-indicator` class)
- `hx-disabled-elt="this"` -- disable element during request
- `hx-preserve` -- keep element across swaps (requires `id`; useful for video, iframes)
- `hx-ext="extension-name"` -- load htmx extension
- `hx-validate="true"` -- trigger HTML5 validation before request
- `hx-encoding="multipart/form-data"` -- for file uploads
- `hx-on:event="handler"` -- inline event handler (HTMX 2.x)

Use attributes before writing JavaScript.
