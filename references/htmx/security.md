# Security

## CSRF Protection

Every mutating HTMX request (POST, PUT, PATCH, DELETE) **must** have CSRF
protection. This is not optional -- without it, any external site can submit
forms on behalf of authenticated users.

### Quarkus CSRF Reactive Setup

Add the extension:

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-csrf-reactive</artifactId>
</dependency>
```

Configure in `application.properties`:

```properties
quarkus.csrf-reactive.enabled=true
quarkus.csrf-reactive.token-header-name=X-CSRF-TOKEN
# SameSite=STRICT prevents the cookie from being sent on cross-origin requests
quarkus.csrf-reactive.cookie-same-site=STRICT
```

### Via meta tag + htmx:configRequest (recommended)

Inject the CSRF token into your base Qute template and attach it to every HTMX
request. The `htmx:configRequest` listener fires on *all* HTMX requests, so the
token is sent automatically for every POST/PUT/PATCH/DELETE:

```html
{! base.html -- include this on EVERY page, not just form pages !}
<meta name="csrf-token" content="{inject:csrf.token}">
<script>
  document.addEventListener('htmx:configRequest', function(e) {
    e.detail.headers['X-CSRF-TOKEN'] =
      document.querySelector('meta[name="csrf-token"]').content;
  });
</script>
```

### Via hidden field in forms

The hidden field name **must** match the server-expected form field name (not
the header name). By default `quarkus-csrf-reactive` accepts the token from
either the header (`X-CSRF-TOKEN`) or a form field named `csrf-token`:

```html
<form hx-post="/ui/todos">
  <input type="hidden" name="csrf-token" value="{inject:csrf.token}">
  {! form fields !}
</form>
```

The meta tag approach above is preferred because it covers all HTMX requests
(including `hx-delete`, `hx-put`, etc.) without modifying each form.

## Input Sanitization

Qute auto-escapes all variable output by default, preventing XSS:

```html
{! Safe -- auto HTML-escaped !}
<span>{userInput}</span>

{! Dangerous -- raw/unescaped output, use only for trusted content !}
<span>{userInput.raw}</span>
```

Validate and sanitize all input on the server using Bean Validation:

```java
@POST
@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
@Produces(MediaType.TEXT_HTML)
@Transactional
public Response create(
    @FormParam("title") @NotBlank @Size(max = 255) String title,
    @FormParam("description") @Size(max = 2000) String description
) {
    // Bean Validation runs automatically; ConstraintViolationException
    // is thrown and mapped to an error response if validation fails
    TodoDto todo = todoService.create(title, description);
    return Response.ok(todos$item.data("item", todo).render()).build();
}
```

Never trust `hx-vals` blindly. Always validate server-side.

## hx-disable

Prevent htmx from processing elements within a subtree. Critical for
user-generated content where users could inject `hx-get` or `hx-post` attributes:

```html
<div hx-disable>
  {! User-generated content here !}
  {! Any hx- attributes inside will be ignored !}
  {userContent}
</div>
```

## Cross-Origin Requests

HTMX 2.x defaults `htmx.config.selfRequestsOnly = true`, blocking cross-origin
requests. Only disable this if you explicitly need cross-origin HTMX requests.

## Content Security Policy

htmx uses `eval()` for `hx-on:*` attributes and trigger filter expressions.
**Prefer the CSP-compatible approach** to avoid weakening your CSP:

1. **Recommended:** Use the htmx CSP-compatible build (`htmx.csp.js`) and set
   `htmx.config.allowEval = false`. This disables `hx-on:*` inline handlers and
   trigger filters that depend on eval, but all other htmx features work normally.
2. **Fallback:** If you need `hx-on:*` or eval-based trigger filters, add
   `'unsafe-eval'` to `script-src`. Be aware this significantly weakens XSS
   protection.

### Security headers filter (recommended)

Set CSP alongside other security headers. Use a `ContainerResponseFilter` to
ensure all responses include them:

```java
@Provider
public class SecurityHeadersFilter implements ContainerResponseFilter {

    @Override
    public void filter(ContainerRequestContext req, ContainerResponseContext res) {
        var headers = res.getHeaders();
        headers.putSingle("Content-Security-Policy",
            "default-src 'self'; " +
            "script-src 'self'; " +
            "style-src 'self' 'unsafe-inline'");
        headers.putSingle("Strict-Transport-Security",
            "max-age=31536000; includeSubDomains");
        headers.putSingle("X-Content-Type-Options", "nosniff");
        headers.putSingle("X-Frame-Options", "DENY");
        headers.putSingle("Referrer-Policy", "strict-origin-when-cross-origin");
        headers.putSingle("Permissions-Policy",
            "camera=(), microphone=(), geolocation=()");
    }
}
```

Or configure via `application.properties`:

```properties
quarkus.http.header."Content-Security-Policy".value=default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'
quarkus.http.header."Strict-Transport-Security".value=max-age=31536000; includeSubDomains
quarkus.http.header."X-Content-Type-Options".value=nosniff
quarkus.http.header."X-Frame-Options".value=DENY
quarkus.http.header."Referrer-Policy".value=strict-origin-when-cross-origin
quarkus.http.header."Permissions-Policy".value=camera=(), microphone=(), geolocation=()
```

## Rate Limiting

Use per-IP rate limiting to prevent brute-force and abuse. A single global
bucket is insufficient -- it lets one attacker exhaust the limit for all users.

```java
@Provider
@Priority(Priorities.AUTHENTICATION + 1)
public class RateLimitFilter implements ContainerRequestFilter {

    // Per-IP: max 100 requests per minute, auto-expires idle entries
    private final ConcurrentHashMap<String, long[]> counters = new ConcurrentHashMap<>();

    @Override
    public void filter(ContainerRequestContext ctx) throws IOException {
        String clientIp = ((io.vertx.core.http.HttpServerRequest)
            ctx.getProperty("io.vertx.ext.web.RoutingContext"))
            .remoteAddress().host();

        long now = System.currentTimeMillis();
        long[] bucket = counters.compute(clientIp, (key, val) -> {
            if (val == null || now - val[1] > 60_000) {
                return new long[]{1, now}; // [count, windowStart]
            }
            val[0]++;
            return val;
        });

        if (bucket[0] > 100) {
            ctx.abortWith(Response.status(429)
                .header("Retry-After", "60")
                .entity("Too many requests, please try again later.")
                .build());
        }
    }
}
```

For production, consider a distributed rate limiter backed by Redis or use a
reverse proxy (nginx, Envoy) for rate limiting at the edge.

## History Security

Prevent sensitive pages from being cached in htmx's localStorage history.
Also use `autocomplete="off"` on sensitive form fields to prevent browser
autofill from leaking data:

```html
<div hx-history="false">
  {! Payment form, sensitive data !}
  <input type="text" name="card-number" autocomplete="off" />
  <input type="text" name="cvv" autocomplete="off" />
</div>
```

Note: `hx-history="false"` only prevents htmx localStorage caching. Sensitive
data may still appear in browser history or network logs -- always use HTTPS.

## Security Logging

Log security-relevant events for monitoring and incident response. Mask
sensitive data (passwords, tokens, PII) in log output. See
`references/quarkus/security/patterns.md` for the full audit logging pattern.

```java
import io.quarkus.security.spi.runtime.AuthenticationFailedEvent;
import io.quarkus.security.spi.runtime.AuthenticationSuccessEvent;

@ApplicationScoped
public class SecurityEventLogger {

    private static final Logger LOG = Logger.getLogger(SecurityEventLogger.class);

    public void onAuthSuccess(@Observes AuthenticationSuccessEvent event) {
        LOG.infof("AUTH_SUCCESS user=%s",
            event.getSecurityIdentity().getPrincipal().getName());
    }

    public void onAuthFailure(@Observes AuthenticationFailedEvent event) {
        LOG.warnf("AUTH_FAILURE reason=%s", event.getAuthenticationRequest());
    }
}
```

Never log passwords, CSRF tokens, session IDs, or full credit card numbers.

## General Rules

- Validate all input on the server (Bean Validation + custom checks)
- Qute auto-escapes HTML output -- never use `.raw` on untrusted data
- Use HTTPS in production (`quarkus.http.insecure-requests=redirect`)
- Validate content types
- Use `hx-disable` on user-generated content containers
- Set CORS origins explicitly -- never use wildcard with credentials
- Enable CSRF protection for all state-changing endpoints (mandatory, not optional)
- Set all security headers (HSTS, X-Content-Type-Options, X-Frame-Options, CSP)
- Log authentication failures and access denials for monitoring
- Run dependency vulnerability scanning in CI (see `references/quarkus/tooling/`)
