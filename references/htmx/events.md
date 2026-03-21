# HTMX Event Lifecycle

## Request Lifecycle (in order)

| Event | When | Can Cancel? |
|-------|------|-------------|
| `htmx:configRequest` | Before request is configured | No |
| `htmx:beforeRequest` | Before request is sent | Yes (`preventDefault()`) |
| `htmx:beforeSend` | Just before XHR send | Yes (`preventDefault()`) |
| `htmx:afterRequest` | After request completes (success or fail) | No |
| `htmx:beforeSwap` | Before response is swapped into DOM | Yes |
| `htmx:afterSwap` | After content is swapped | No |
| `htmx:afterSettle` | After DOM has settled (attributes applied) | No |
| `htmx:load` | After htmx processes new content | No |

## Error Events

| Event | When |
|-------|------|
| `htmx:responseError` | Server returned non-2xx status |
| `htmx:sendError` | Network error (no response) |
| `htmx:timeout` | Request timed out |

## History Events

| Event | When |
|-------|------|
| `htmx:beforeHistorySave` | Before page state is saved to history cache |
| `htmx:pushedIntoHistory` | After URL pushed to browser history |
| `htmx:historyRestore` | When restoring from history (back/forward) |
| `htmx:historyCacheMiss` | History entry not in cache (triggers server request) |
| `htmx:historyCacheError` | Error reading from history cache |

## Validation Events

| Event | When |
|-------|------|
| `htmx:validation:validate` | Before validation (add custom validation here) |
| `htmx:validation:failed` | HTML5 validation failed |
| `htmx:validation:halted` | Validation prevented the request |

## Event Detail Properties

All events provide `evt.detail` with:

```javascript
evt.detail.elt            // the element that dispatched the request
evt.detail.xhr            // the XMLHttpRequest
evt.detail.target         // the target element
evt.detail.requestConfig  // the request configuration
evt.detail.boosted        // true if request came from hx-boost
```

Additional properties on specific events:

```javascript
// htmx:afterRequest
evt.detail.successful  // true if 2xx response
evt.detail.failed      // true if non-2xx or error

// htmx:beforeSwap -- can modify swap behavior
evt.detail.shouldSwap    // set to false to prevent swap
evt.detail.target        // change target element
evt.detail.swapOverride  // change swap strategy
```

## Common Patterns

```javascript
// Initialize JS plugins on dynamically loaded content
document.body.addEventListener('htmx:afterSettle', function(evt) {
  initPlugins(evt.detail.target);
});

// Modify request before sending (add auth header)
document.body.addEventListener('htmx:configRequest', function(evt) {
  evt.detail.headers['Authorization'] = 'Bearer ' + getToken();
});

// Handle errors gracefully
document.body.addEventListener('htmx:beforeSwap', function(evt) {
  if (evt.detail.xhr.status === 404) {
    evt.detail.shouldSwap = true;
    evt.detail.target = document.getElementById('error-area');
  }
});
```

## Inline Event Handling (HTMX 2.x)

```html
<button hx-post="/save"
        hx-on:htmx:after-request="if(event.detail.successful) showToast('Saved')">
  Save
</button>
```

Prefer attribute-based solutions over JavaScript event listeners.
