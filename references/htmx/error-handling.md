# HTMX Error Handling

## Overview

HTMX requests can fail at multiple levels: network errors, server errors (4xx/5xx),
swap errors, and timeouts. A production HTMX app must handle all of these gracefully
to avoid silent failures and broken UI states.

## Error Events

HTMX fires specific events for each error type. Listen on `document.body` to catch
errors from any element:

```javascript
// Network failure (request never reached the server)
document.body.addEventListener('htmx:sendError', function(event) {
    showToast('Network error. Check your connection.', 'error');
});

// Server error (4xx or 5xx response)
document.body.addEventListener('htmx:responseError', function(event) {
    var status = event.detail.xhr.status;
    if (status === 401) {
        window.location.href = '/login';
    } else if (status === 403) {
        showToast('You do not have permission for this action.', 'error');
    } else if (status >= 500) {
        showToast('Server error. Please try again later.', 'error');
    }
});

// Request timeout
document.body.addEventListener('htmx:timeout', function(event) {
    showToast('Request timed out. Please try again.', 'warning');
});

// Swap error (response received but DOM swap failed)
document.body.addEventListener('htmx:swapError', function(event) {
    console.error('Swap failed:', event.detail);
});
```

## `htmx:beforeSwap` -- Status Code Routing

Override swap behavior based on HTTP status codes. This is the most powerful
error-handling hook:

```javascript
document.body.addEventListener('htmx:beforeSwap', function(event) {
    var status = event.detail.xhr.status;

    if (status === 422) {
        // Validation error -- allow swap so the form re-renders with errors.
        // The server returns the form fragment with error messages.
        event.detail.shouldSwap = true;
        event.detail.isError = false;
    } else if (status === 404) {
        event.detail.shouldSwap = true;
        event.detail.target = htmx.find('#error-container');
    } else if (status === 419) {
        // CSRF token expired -- refresh the page
        window.location.reload();
    }
});
```

### Key properties on `event.detail`

| Property | Type | Purpose |
|----------|------|---------|
| `shouldSwap` | boolean | Set to `true` to force swap on error status |
| `isError` | boolean | Set to `false` to suppress console error logging |
| `target` | Element | Override the swap target element |
| `xhr` | XMLHttpRequest | Access response status, headers, body |

## response-targets Extension

Map specific HTTP status codes to specific target elements declaratively:

```html
<body hx-ext="response-targets">

<form hx-post="/ui/register"
      hx-target="#success-area"
      hx-target-422="#form-errors"
      hx-target-5*="#server-error">
    <input name="email" required />
    <button type="submit">Register</button>
</form>

<div id="success-area"></div>
<div id="form-errors"></div>
<div id="server-error"></div>

</body>
```

Load the extension:

```html
<script src="https://unpkg.com/htmx-ext-response-targets@2.0.2"></script>
```

### Wildcard targets

| Attribute | Matches |
|-----------|---------|
| `hx-target-422` | Exactly 422 |
| `hx-target-4*` | Any 4xx status |
| `hx-target-5*` | Any 5xx status |
| `hx-target-error` | Any 4xx or 5xx status |

## Quarkus Server-Side Error Patterns

### Validation errors (422)

Return the form fragment with error messages. The client swaps it into the form area:

```java
@POST
@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
@Produces(MediaType.TEXT_HTML)
@Transactional
public Response create(
    @FormParam("email") String email,
    @FormParam("name") String name
) {
    List<String> errors = validate(email, name);
    if (!errors.isEmpty()) {
        return Response.status(422)
            .entity(register$form
                .data("errors", errors)
                .data("values", Map.of("email", email, "name", name))
                .render())
            .build();
    }
    userService.register(email, name);
    return Response.ok(register$success.render()).build();
}
```

### Server errors (500) with error fragment

```java
@ServerExceptionMapper
public Response handleUnexpected(Exception e) {
    Log.error("Unexpected error", e);
    return Response.serverError()
        .entity(error$server.data("message", "Something went wrong").render())
        .type(MediaType.TEXT_HTML)
        .build();
}
```

### Error fragment template

```html
{! templates/error$server.html !}
<div class="alert alert-danger" role="alert" aria-live="assertive">
    <strong>Error:</strong> {message}
    <button hx-get="/ui/retry" hx-target="closest .alert" hx-swap="outerHTML">
        Retry
    </button>
</div>
```

### Not Found (404) with HX-Request awareness

```java
@ServerExceptionMapper(NotFoundException.class)
public Response handleNotFound(
    @HeaderParam("HX-Request") String hxRequest
) {
    if ("true".equals(hxRequest)) {
        return Response.status(404)
            .entity(error$notfound.render())
            .type(MediaType.TEXT_HTML)
            .build();
    }
    return Response.status(404)
        .entity(notfound.render())
        .type(MediaType.TEXT_HTML)
        .build();
}
```

## Error Toast Pattern

A reusable toast notification system for HTMX errors:

```html
{! In base.html layout !}
<div id="toast-container"
     aria-live="polite"
     aria-atomic="true"
     class="toast-container"></div>

<script>
function showToast(message, type) {
    var container = document.getElementById('toast-container');
    var toast = document.createElement('div');
    toast.className = 'toast toast-' + type;
    toast.setAttribute('role', 'alert');
    toast.textContent = message;
    container.appendChild(toast);
    setTimeout(function() { toast.remove(); }, 5000);
}

document.body.addEventListener('htmx:responseError', function(event) {
    var status = event.detail.xhr.status;
    var messages = {
        401: 'Session expired. Please log in again.',
        403: 'You do not have permission for this action.',
        404: 'The requested resource was not found.',
        422: 'Please correct the errors in the form.',
        429: 'Too many requests. Please wait a moment.',
        500: 'Server error. Please try again later.',
        503: 'Service temporarily unavailable.'
    };
    showToast(messages[status] || 'An unexpected error occurred.', 'error');
});

document.body.addEventListener('htmx:sendError', function() {
    showToast('Network error. Check your connection.', 'error');
});

document.body.addEventListener('htmx:timeout', function() {
    showToast('Request timed out. Please try again.', 'warning');
});
</script>
```

## Server-Triggered Error Events

Use `HX-Trigger` to fire custom error events from the server:

```java
return Response.status(422)
    .entity(form.render())
    .header("HX-Trigger", "{\"showError\": {\"message\": \"Email already taken\"}}")
    .build();
```

```html
<body hx-on:show-error="showToast(event.detail.message, 'error')">
```

## Timeout Configuration

```html
{! Per-element timeout (milliseconds) !}
<button hx-post="/ui/slow-action"
        hx-request='{"timeout": 30000}'>
    Process
</button>
```

```javascript
// Global timeout
htmx.config.timeout = 10000; // 10 seconds
```

## Testing Error Handling

```java
@QuarkusTest
class ErrorHandlingTest {

    @Test
    void serverError_returns500WithErrorFragment() {
        given()
            .header("HX-Request", "true")
        .when()
            .get("/ui/broken-endpoint")
        .then()
            .statusCode(500)
            .body(containsString("Something went wrong"));
    }

    @Test
    void validationError_returns422WithFormErrors() {
        given()
            .contentType("application/x-www-form-urlencoded")
            .formParam("email", "not-an-email")
            .header("HX-Request", "true")
        .when()
            .post("/ui/register")
        .then()
            .statusCode(422)
            .body(containsString("Invalid email"));
    }

    @Test
    void notFound_htmxRequest_returnsFragment() {
        given()
            .header("HX-Request", "true")
        .when()
            .get("/ui/nonexistent")
        .then()
            .statusCode(404)
            .body(not(containsString("<!DOCTYPE")));
    }
}
```
