# Swap Strategies

## Strategies

| Strategy | Behavior |
|----------|----------|
| `innerHTML` | Replace inner content (default) |
| `outerHTML` | Replace entire element including itself |
| `textContent` | Replace text content only (no HTML parsing, safe for text) |
| `beforebegin` | Insert before the target element |
| `afterbegin` | Insert as first child of target |
| `beforeend` | Insert as last child of target (append) |
| `afterend` | Insert after the target element |
| `delete` | Remove the target element (ignores response body) |
| `none` | No DOM swap (fire-and-forget, useful for side effects) |

Based on `Element.insertAdjacentHTML` positions plus `delete`, `none`, and `textContent`.

## Choosing the Right Strategy

```html
<!-- Replace content inside a container -->
<div hx-get="/todos" hx-swap="innerHTML" hx-target="#list">

<!-- Replace the whole element (e.g., toggle, inline edit) -->
<div hx-patch="/todos/1/toggle" hx-swap="outerHTML">

<!-- Append new items to a list -->
<form hx-post="/todos" hx-swap="beforeend" hx-target="#list">

<!-- Prepend new items -->
<form hx-post="/messages" hx-swap="afterbegin" hx-target="#feed">

<!-- Delete on removal -->
<button hx-delete="/todos/1" hx-target="closest .todo" hx-swap="delete">

<!-- Fire-and-forget (analytics, side effects) -->
<button hx-post="/track" hx-swap="none">
```

## Timing Modifiers

```html
<!-- Delay before old content is removed -->
<div hx-get="/page" hx-swap="innerHTML swap:300ms">

<!-- Delay before new content settles (attributes applied) -->
<div hx-get="/page" hx-swap="innerHTML settle:200ms">

<!-- Both together (for CSS transition choreography) -->
<div hx-get="/page" hx-swap="innerHTML swap:200ms settle:300ms">
```

## Scroll Modifiers

```html
<!-- Scroll target to top after swap -->
<div hx-get="/page/2" hx-swap="innerHTML show:top">

<!-- Scroll to bottom (chat messages) -->
<div hx-get="/messages" hx-swap="beforeend scroll:bottom">

<!-- Scroll a specific element into view -->
<div hx-get="/item" hx-swap="innerHTML show:#item-5:top">

<!-- Control focus scrolling -->
<div hx-get="/form" hx-swap="innerHTML focus-scroll:true">
```

## View Transitions

```html
<!-- Opt in to View Transitions API (Chrome 111+) -->
<div hx-get="/page" hx-swap="innerHTML transition:true">
```

Falls back gracefully in unsupported browsers. Pair with CSS:

```css
::view-transition-old(root) { animation: fade-out 0.2s; }
::view-transition-new(root) { animation: fade-in 0.2s; }
```

Enable globally: `htmx.config.globalViewTransitions = true`

## Out-of-Band Swaps (OOB)

Update multiple page regions from a single response:

```html
<!-- In the server response, mark elements for OOB swap -->
<div id="main-content">Primary response content</div>
<div id="notification-count" hx-swap-oob="innerHTML">5</div>
<div id="status-bar" hx-swap-oob="true">Updated status</div>
```

OOB elements are removed from the main response before primary swap,
then swapped into matching IDs on the page. Default OOB strategy is `outerHTML`.

Choose swap strategy based on UI intention. Avoid replacing large containers unnecessarily.
