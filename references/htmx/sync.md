# hx-sync

Controls how requests from an element are synchronized. Critical for preventing
race conditions, duplicate submissions, and request ordering issues.

## Strategies

| Strategy | Behavior |
|----------|----------|
| `drop` | Drop new request if one is already in flight |
| `abort` | Abort the in-flight request, send the new one |
| `replace` | Abort in-flight request, send new one (alias for abort) |
| `queue first` | Queue requests, only keep the first |
| `queue last` | Queue requests, only keep the last |
| `queue all` | Queue all requests, execute in order |

## Common Patterns

### Prevent Duplicate Form Submissions

```html
<form hx-post="/save" hx-sync="this:drop">
  <button type="submit">Save</button>
</form>
```

### Live Search (Only Latest Matters)

```html
<input hx-get="/search"
       hx-trigger="input changed delay:300ms"
       hx-sync="this:replace"
       hx-target="#results">
```

### Form with Abort (Cancel Previous on Resubmit)

```html
<form hx-post="/save" hx-sync="this:abort">
  <!-- If user submits again, previous request is cancelled -->
</form>
```

### Queue Requests in Order

```html
<div hx-sync="this:queue all">
  <button hx-post="/step1">Step 1</button>
  <button hx-post="/step2">Step 2</button>
</div>
```

## Sync Across Elements

Target a parent or sibling to coordinate between elements:

```html
<div id="actions">
  <button hx-post="/save" hx-sync="closest #actions:abort">Save</button>
  <button hx-post="/publish" hx-sync="closest #actions:abort">Publish</button>
  <!-- Only one action at a time; new action cancels previous -->
</div>
```

## When to Use hx-sync

- Forms: always use `drop` or `abort` to prevent double-submit
- Search inputs: use `replace` so only the latest query runs
- Action buttons: use `drop` to ignore rapid clicks
- Sequential workflows: use `queue all` for ordered execution
