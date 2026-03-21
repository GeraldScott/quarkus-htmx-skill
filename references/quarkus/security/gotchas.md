# Quarkus Security Gotchas

Common security pitfalls, symptoms, and fixes.

## Authentication and sessions

### HTMX cannot follow 302 redirects to a login page

**Symptom:** HTMX partial request to a protected endpoint returns a 302, but the
browser tries to swap the login page HTML into the target element instead of
redirecting the full page.

**Fix:** Intercept 302s for HTMX requests and convert to `HX-Redirect` header
(see patterns.md "HTMX Authentication with Session Cookies").

### Session cookie not sent on HTMX requests

**Symptom:** User is authenticated but HTMX requests return 401/403.

**Fix:** Ensure `SameSite` is `STRICT` or `LAX` (not `NONE` without `Secure`).
HTMX requests are same-origin by default, so `STRICT` works. If using
cross-origin HTMX requests, you need `SameSite=NONE; Secure`.

### @RolesAllowed not working

**Symptom:** Annotation is present but access is not restricted.

**Fix:** Ensure `quarkus-security` is in your dependencies. The annotation
requires a security extension to be active. Without one, endpoints are
unprotected by default.

## IDOR (Insecure Direct Object Reference)

### Forgetting ownership checks on resource endpoints

**Symptom:** User A can access `/ui/orders/42` which belongs to User B.

**Fix:** Never assume a valid ID means authorized access. Always verify
ownership in the service layer or resource method. See patterns.md "IDOR
Prevention" and "Scope queries to current user".

### Using sequential IDs exposes enumeration

**Symptom:** Attacker iterates `/api/items/1`, `/api/items/2`, etc. to scrape
data.

**Fix:** Use UUIDs for public-facing identifiers, or always combine ID lookup
with ownership filter:
```java
Order.find("id = ?1 and ownerUsername = ?2", id, currentUser).firstResult();
```

## CSRF

### CSRF token not sent on HTMX requests

**Symptom:** POST/PUT/DELETE via HTMX returns 403 with CSRF error.

**Fix:** Ensure the `htmx:configRequest` listener is in your base template
(loaded on every page), and the meta tag name matches what your JavaScript reads.
See patterns.md "CSRF + HTMX (complete setup)".

### CSRF token missing on first page load

**Symptom:** First form submission after cold start fails CSRF validation.

**Fix:** `{inject:csrf.token}` in Qute generates a token on page render. Ensure
your base template always includes the meta tag, not just form pages.

## XSS

### Using .raw on user-controlled data

**Symptom:** Stored XSS -- attacker injects `<script>` via form input that
renders unescaped.

**Fix:** Never use `{value.raw}` on any data that originates from user input.
Qute auto-escapes by default -- `.raw` explicitly disables this. Treat `.raw`
the same as `innerHTML` assignment.

### Constructing HTML via string concatenation

**Symptom:** XSS in SSE, WebSocket, or exception mapper responses.

**Fix:** Always render HTML through Qute templates, even for small fragments.
Qute auto-escapes all variables. Never do:
```java
// DANGEROUS -- bypasses escaping
"<div>" + userInput + "</div>"
```

Instead:
```java
// SAFE -- Qute auto-escapes userInput
template.data("value", userInput).render()
```

## Headers and CORS

### CORS misconfigured with wildcard + credentials

**Symptom:** Browser rejects response or credentials are not sent.

**Fix:** `Access-Control-Allow-Origin: *` is incompatible with
`Access-Control-Allow-Credentials: true`. Always specify explicit origins:
```properties
quarkus.http.cors.origins=https://app.example.com
```

### Missing security headers in production

**Symptom:** Security scanner flags missing HSTS, X-Frame-Options, etc.

**Fix:** Add security headers via `application.properties` or a
`ContainerResponseFilter`. See api.md "Security headers" section.

## Secrets and configuration

### Hardcoded credentials in application.properties

**Symptom:** Database password, API key, or OIDC secret committed to version
control.

**Fix:** Use environment variable placeholders for all secrets:
```properties
%prod.quarkus.datasource.password=${DB_PASSWORD}
%prod.quarkus.oidc.credentials.secret=${OIDC_CLIENT_SECRET}
```

Never commit `.env` files. Add `.env` to `.gitignore`.

### Dev credentials leaking to production

**Symptom:** Production runs with default `username=admin / password=admin`.

**Fix:** Use profile prefixes. Dev credentials under `%dev.` are never active in
production:
```properties
%dev.quarkus.datasource.username=dev
%dev.quarkus.datasource.password=dev
%prod.quarkus.datasource.username=${DB_USER}
%prod.quarkus.datasource.password=${DB_PASSWORD}
```

## File uploads

### No validation on uploaded files

**Symptom:** Attacker uploads `.jsp`, `.html`, or oversized files.

**Fix:** Validate file type, size, and name server-side:
```java
@POST @Path("/upload")
@Consumes(MediaType.MULTIPART_FORM_DATA)
public Response upload(@RestForm("file") FileUpload file) {
    // Validate size
    if (file.size() > 5_000_000) {
        return Response.status(413).entity("File too large").build();
    }
    // Validate content type
    if (!Set.of("image/png", "image/jpeg").contains(file.contentType())) {
        return Response.status(415).entity("Unsupported file type").build();
    }
    // Sanitize filename -- strip path components
    String safeName = Path.of(file.fileName()).getFileName().toString();
    // Store outside web root
    Files.copy(file.filePath(), uploadDir.resolve(safeName));
    return Response.ok().build();
}
```

Also set global limits:
```properties
quarkus.http.limits.max-body-size=10M
```
