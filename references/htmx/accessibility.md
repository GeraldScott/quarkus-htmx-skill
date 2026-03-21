# HTMX Accessibility (a11y)

## Overview

HTMX dynamically updates the DOM, which can break screen readers, keyboard navigation,
and focus management if not handled carefully. This reference covers the patterns
needed to keep HTMX applications accessible.

The core principle: **HTMX swaps are invisible to assistive technology unless you
explicitly announce them.**

## ARIA Live Regions

When HTMX swaps content, screen readers don't know something changed. Use ARIA live
regions to announce dynamic updates:

```html
{! Place in base.html -- one per app !}
<div id="live-announce"
     role="status"
     aria-live="polite"
     aria-atomic="true"
     class="sr-only"></div>

<div id="error-announce"
     role="alert"
     aria-live="assertive"
     aria-atomic="true"
     class="sr-only"></div>
```

### Announce after HTMX swaps

```javascript
document.body.addEventListener('htmx:afterSwap', function(event) {
    // Announce meaningful content changes
    var target = event.detail.target;
    var message = target.getAttribute('data-a11y-message');
    if (message) {
        document.getElementById('live-announce').textContent = message;
    }
});
```

```html
<div id="todo-list"
     data-a11y-message="Todo list updated">
    {! HTMX swaps content here; screen reader announces the message !}
</div>
```

### Announce errors

```javascript
document.body.addEventListener('htmx:responseError', function(event) {
    document.getElementById('error-announce').textContent =
        'An error occurred. Please try again.';
});
```

### `aria-live` values

| Value | Use when |
|-------|----------|
| `polite` | Content update is informational (list refreshed, item added) |
| `assertive` | Urgent feedback (error messages, validation failures) |
| `off` | Suppress announcements (e.g., during rapid polling) |

## Focus Management After Swaps

When HTMX replaces or removes the focused element, focus is lost. This breaks
keyboard navigation. Explicitly manage focus after swaps:

```javascript
document.body.addEventListener('htmx:afterSwap', function(event) {
    var target = event.detail.target;

    // After form submission, focus the first error or the success message
    var firstError = target.querySelector('[aria-invalid="true"]');
    if (firstError) {
        firstError.focus();
        return;
    }

    // After adding an item, focus the new item
    var newItem = target.querySelector('[data-new-item]');
    if (newItem) {
        newItem.focus();
    }
});
```

### Focus after delete

When an item is removed (`hx-swap="outerHTML"` with empty response), move focus
to the next sibling or the parent container:

```javascript
document.body.addEventListener('htmx:beforeSwap', function(event) {
    if (event.detail.xhr.status === 200 && event.detail.xhr.responseText === '') {
        // Element is about to be removed -- save focus target
        var el = event.detail.elt;
        var next = el.nextElementSibling || el.previousElementSibling || el.parentElement;
        if (next) {
            setTimeout(function() { next.focus(); }, 50);
        }
    }
});
```

### Preserve focus during morph swaps

The `idiomorph` extension preserves focus automatically during DOM diffing.
Use it for complex forms where users may be mid-edit:

```html
<div hx-get="/ui/dashboard" hx-swap="morph:innerHTML">
    {! Focus and scroll position preserved during updates !}
</div>
```

## Semantic HTML for HTMX Elements

Always use the correct HTML element for interactive HTMX triggers:

```html
{! BAD -- div is not keyboard accessible !}
<div hx-get="/ui/details" hx-target="#panel">Show details</div>

{! GOOD -- button is focusable and keyboard-activated !}
<button hx-get="/ui/details" hx-target="#panel">Show details</button>

{! GOOD -- anchor for navigation-like actions !}
<a hx-get="/ui/page/2" hx-target="#content" hx-push-url="true">Page 2</a>
```

If you must use a non-interactive element (rare), add the required attributes:

```html
<div hx-get="/ui/details"
     hx-target="#panel"
     role="button"
     tabindex="0"
     hx-trigger="click, keydown[key=='Enter']"
     aria-label="Show details">
    Show details
</div>
```

## Loading States

Announce loading states to screen readers:

```html
<button hx-post="/ui/save"
        hx-indicator="#save-spinner"
        aria-describedby="save-status">
    Save
</button>
<span id="save-spinner" class="htmx-indicator" aria-hidden="true">
    <span id="save-status" class="sr-only" role="status">Saving...</span>
</span>
```

Toggle `aria-busy` on the swap target during requests:

```javascript
document.body.addEventListener('htmx:beforeRequest', function(event) {
    var target = document.querySelector(
        event.detail.elt.getAttribute('hx-target') || event.detail.elt.id
    );
    if (target) target.setAttribute('aria-busy', 'true');
});

document.body.addEventListener('htmx:afterSwap', function(event) {
    event.detail.target.removeAttribute('aria-busy');
});
```

## Forms and Validation

### Mark invalid fields

Server-rendered validation errors should use ARIA attributes:

```html
{! Qute form fragment with validation errors !}
<form hx-post="/ui/register" hx-target="this" hx-swap="outerHTML">
    <label for="email">Email</label>
    <input id="email" name="email" type="email"
           value="{values.email}"
           {#if errors.email}aria-invalid="true"
           aria-describedby="email-error"{/if}
           required />
    {#if errors.email}
    <span id="email-error" class="error" role="alert">{errors.email}</span>
    {/if}

    <button type="submit">Register</button>
</form>
```

### Validation error summary

```html
{#if errors.any}
<div role="alert" aria-label="Form errors">
    <h3>Please fix the following errors:</h3>
    <ul>
        {#for error in errors.all}
        <li><a href="#{error.field}">{error.message}</a></li>
        {/for}
    </ul>
</div>
{/if}
```

## Confirmation Dialogs

`hx-confirm` uses the browser's native `confirm()` dialog, which is accessible.
For custom confirmation modals, ensure they are accessible:

```html
<button hx-delete="/ui/items/{item.id}"
        hx-target="#item-{item.id}"
        hx-swap="outerHTML"
        hx-confirm="Delete {item.name}? This cannot be undone."
        aria-label="Delete {item.name}">
    Delete
</button>
```

## Tables with Dynamic Content

When HTMX updates table rows, maintain table semantics:

```html
<table aria-label="Product list">
    <thead>
        <tr>
            <th scope="col">Name</th>
            <th scope="col">Price</th>
            <th scope="col">Actions</th>
        </tr>
    </thead>
    <tbody id="product-rows"
           hx-get="/ui/products"
           hx-trigger="load"
           hx-swap="innerHTML"
           data-a11y-message="Product list loaded">
    </tbody>
</table>
```

## Pagination Accessibility

```html
<nav aria-label="Pagination">
    <a hx-get="/ui/products?page=1"
       hx-target="#product-list"
       hx-push-url="true"
       aria-label="Page 1">1</a>
    <a hx-get="/ui/products?page=2"
       hx-target="#product-list"
       hx-push-url="true"
       aria-label="Page 2"
       aria-current="page">2</a>
</nav>
```

Use `aria-current="page"` on the active page link.

## CSS for Screen Reader Text

```css
.sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
}
```

## Checklist

Before shipping an HTMX feature, verify:

- [ ] All interactive elements are `<button>` or `<a>` (or have `role`, `tabindex`, keyboard trigger)
- [ ] Dynamic content areas have `aria-live` regions to announce changes
- [ ] Focus is managed after swaps (not lost to `<body>`)
- [ ] Validation errors use `aria-invalid` and `aria-describedby`
- [ ] Loading states have `aria-busy` or screen-reader-only status text
- [ ] Confirmation actions have clear `hx-confirm` text or accessible modals
- [ ] Pagination links have `aria-label` and `aria-current`
- [ ] Error responses are announced via `role="alert"` live region
- [ ] Tab order makes sense after HTMX swaps content
