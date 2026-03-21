# htmx.config Options

Configure htmx behavior globally via `htmx.config` or `<meta>` tags.

## Setting Config

```javascript
// Via JavaScript
htmx.config.defaultSwapStyle = 'outerHTML';

// Via meta tag (before htmx loads)
<meta name="htmx-config" content='{"defaultSwapStyle": "outerHTML"}'>
```

## Important Options

### Security

| Option | Default (2.x) | Description |
|--------|---------------|-------------|
| `selfRequestsOnly` | `true` | Block cross-origin requests (was `false` in 1.x) |
| `allowEval` | `true` | Allow `eval()` for `hx-on:*` and filters |
| `allowScriptTags` | `false` | Process `<script>` tags in responses (2.x default) |

### Swap Behavior

| Option | Default | Description |
|--------|---------|-------------|
| `defaultSwapStyle` | `innerHTML` | Default swap strategy |
| `defaultSwapDelay` | `0` | Delay before swap (ms) |
| `defaultSettleDelay` | `20` | Delay before settle (ms) |
| `globalViewTransitions` | `false` | Enable View Transitions API globally |

### History

| Option | Default | Description |
|--------|---------|-------------|
| `historyCacheSize` | `10` | Number of pages cached in localStorage |
| `historyEnabled` | `true` | Enable history support |
| `refreshOnHistoryMiss` | `false` | Full page refresh on cache miss |

### Timing

| Option | Default | Description |
|--------|---------|-------------|
| `timeout` | `0` | Request timeout in ms (0 = no timeout) |
| `defaultFocusScroll` | `false` | Scroll to focused element after swap |

### Indicators

| Option | Default | Description |
|--------|---------|-------------|
| `indicatorClass` | `htmx-indicator` | Class toggled on indicators |
| `requestClass` | `htmx-request` | Class added to element during request |
| `settlingClass` | `htmx-settling` | Class during settle phase |
| `swappingClass` | `htmx-swapping` | Class during swap phase |

## HTMX 1.x vs 2.x Key Differences

| Feature | 1.x | 2.x |
|---------|-----|-----|
| `selfRequestsOnly` | `false` | `true` (security) |
| `allowScriptTags` | `true` | `false` (security) |
| `textContent` swap | Not available | Available |
| `hx-on` syntax | `hx-on="event: handler"` | `hx-on:event="handler"` |
| Extensions | Bundled | Separate packages (`htmx-ext-*`) |
| `revealed` trigger | Supported | Deprecated (use `intersect`) |
| IE11 support | Yes | No |

When migrating from 1.x to 2.x:
1. Update `hx-on` syntax to colon-separated format
2. Load extensions as separate scripts
3. Replace `revealed` with `intersect`
4. Review `selfRequestsOnly` if you use cross-origin requests
5. Review `allowScriptTags` if responses contain `<script>` tags
