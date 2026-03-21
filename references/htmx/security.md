# Security

## CSRF Protection

Every mutating HTMX request (POST, PUT, PATCH, DELETE) needs CSRF protection.

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
```

### Via meta tag + htmx:configRequest (recommended)

Inject the CSRF token into your base Qute template and attach it to every HTMX request:

```html
{! base.html !}
<meta name="csrf-token" content="{inject:csrf.token}">
<script>
  document.addEventListener('htmx:configRequest', function(e) {
    e.detail.headers['X-CSRF-TOKEN'] =
      document.querySelector('meta[name="csrf-token"]').content;
  });
</script>
```

### Via hidden field in forms

```html
<form hx-post="/ui/todos">
  <input type="hidden" name="csrf-token" value="{inject:csrf.token}">
  {! form fields !}
</form>
```

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
If you use CSP:

- Add `'unsafe-eval'` to `script-src`, OR
- Use the htmx CSP-compatible build (disables eval-dependent features)
- Set `htmx.config.allowEval = false` to disable eval features

Set CSP headers via a Quarkus HTTP filter:

```java
@Provider
public class SecurityHeadersFilter implements ContainerResponseFilter {

    @Override
    public void filter(ContainerRequestContext req, ContainerResponseContext res) {
        res.getHeaders().putSingle("Content-Security-Policy",
            "default-src 'self'; " +
            "script-src 'self' 'unsafe-eval' https://unpkg.com; " +
            "style-src 'self' 'unsafe-inline'");
    }
}
```

Or configure via `application.properties`:

```properties
quarkus.http.header."Content-Security-Policy".value=default-src 'self'; script-src 'self' 'unsafe-eval' https://unpkg.com; style-src 'self' 'unsafe-inline'
```

## Rate Limiting

Use the `quarkus-rate-limiter` extension or implement a filter:

```java
@Provider
@Priority(Priorities.AUTHENTICATION + 1)
public class RateLimitFilter implements ContainerRequestFilter {

    private final RateLimiter limiter = RateLimiter.create(100); // 100 req/sec

    @Override
    public void filter(ContainerRequestContext ctx) {
        if (!limiter.tryAcquire()) {
            ctx.abortWith(Response.status(429)
                .entity("Too many requests, please try again later.")
                .build());
        }
    }
}
```

## History Security

Prevent sensitive pages from being cached in htmx's localStorage history:

```html
<div hx-history="false">
  {! Payment form, sensitive data !}
</div>
```

## General Rules

- Validate all input on the server (Bean Validation + custom checks)
- Qute auto-escapes HTML output -- never use `.raw` on untrusted data
- Use HTTPS in production
- Validate content types
- Use `hx-disable` on user-generated content containers
- Set appropriate CORS headers if needed (Quarkus CORS filter in application.properties)
- Enable CSRF protection for all state-changing endpoints
