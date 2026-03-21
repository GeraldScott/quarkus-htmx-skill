# HTMX Headers

## Request Headers (sent by htmx to server)

| Header | Value | Notes |
|--------|-------|-------|
| `HX-Request` | `true` | Always sent on HTMX requests |
| `HX-Boosted` | `true` | Request came from `hx-boost` |
| `HX-Current-URL` | URL string | Current browser URL |
| `HX-History-Restore-Request` | `true` | This is a history restoration (back/forward) |
| `HX-Prompt` | string | User response from `hx-prompt` |
| `HX-Target` | element ID | The `id` of the target element |
| `HX-Trigger-Name` | string | The `name` of the triggered element |
| `HX-Trigger` | element ID | The `id` of the triggered element |

Use these server-side to determine context and return appropriate fragments.

## Response Headers (set by server)

### Navigation

| Header | Effect |
|--------|--------|
| `HX-Location` | Client-side redirect (AJAX, no full reload) |
| `HX-Redirect` | Full page redirect (traditional) |
| `HX-Refresh` | Full page refresh when set to `true` |
| `HX-Push-Url` | Push URL into browser history |
| `HX-Replace-Url` | Replace current URL (no new history entry) |

### Swap Control

| Header | Effect |
|--------|--------|
| `HX-Reswap` | Override `hx-swap` from server (e.g., `innerHTML`, `none`) |
| `HX-Retarget` | Override `hx-target` from server (CSS selector) |
| `HX-Reselect` | Override `hx-select` from server (CSS selector) |

These are powerful for error handling -- retarget errors to a different element:

```java
@POST @Path("/todos") @Transactional
@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
@Produces(MediaType.TEXT_HTML)
public Response create(@FormParam("text") String text) {
    List<String> errors = validate(text);
    if (!errors.isEmpty()) {
        return Response.status(422)
            .header("HX-Retarget", "#form-errors")
            .header("HX-Reswap", "innerHTML")
            .entity(validationErrors.data("errors", errors).render())
            .build();
    }
    // ...
}
```

### Event Triggers

| Header | When event fires |
|--------|------------------|
| `HX-Trigger` | Immediately |
| `HX-Trigger-After-Swap` | After content is swapped |
| `HX-Trigger-After-Settle` | After DOM settles |

Trigger values can be simple names or JSON with data:

```http
HX-Trigger: todoAdded
HX-Trigger: event1, event2
HX-Trigger: {"showMessage": {"level": "info", "text": "Saved!"}}
```

Listen on client:

```javascript
document.body.addEventListener('showMessage', function(evt) {
  showToast(evt.detail.level, evt.detail.text);
});
```

Use headers to coordinate client behavior without custom JS.
