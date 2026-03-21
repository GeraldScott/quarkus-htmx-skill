# Quarkus Security Patterns

Use these patterns for repeatable security implementation workflows.

## Pattern: IDOR Prevention (Insecure Direct Object Reference)

Never trust a path/query parameter alone to authorize access. Always verify the
requesting user owns or has permission to access the resource.

```java
@Path("/ui/orders")
@Authenticated
@ApplicationScoped
public class OrderResource {

    @Inject SecurityIdentity identity;
    @Inject Template order;

    @GET @Path("/{id}")
    @Produces(MediaType.TEXT_HTML)
    public TemplateInstance getOrder(@RestPath Long id) {
        Order o = Order.findById(id);
        if (o == null) {
            throw new NotFoundException();
        }
        // Verify ownership -- do NOT skip this check
        if (!o.ownerUsername.equals(identity.getPrincipal().getName())) {
            throw new ForbiddenException();
        }
        return order.data("order", o);
    }

    @DELETE @Path("/{id}") @Transactional
    public Response delete(@RestPath Long id) {
        Order o = Order.findById(id);
        if (o == null) {
            throw new NotFoundException();
        }
        if (!o.ownerUsername.equals(identity.getPrincipal().getName())) {
            throw new ForbiddenException();
        }
        o.delete();
        return Response.ok().build();
    }
}
```

For repeated ownership checks, extract to a service:

```java
@ApplicationScoped
public class AuthorizationService {

    @Inject SecurityIdentity identity;

    public <T> T requireOwnership(PanacheEntity entity, String ownerField) {
        try {
            String owner = (String) entity.getClass()
                .getField(ownerField).get(entity);
            if (!owner.equals(identity.getPrincipal().getName())) {
                throw new ForbiddenException("Access denied");
            }
        } catch (ReflectiveOperationException e) {
            throw new IllegalArgumentException("Invalid owner field: " + ownerField);
        }
        return (T) entity;
    }
}
```

## Pattern: Scope queries to current user

Prevent IDOR at the data layer by always filtering by the current user:

```java
@ApplicationScoped
public class OrderService {

    @Inject SecurityIdentity identity;

    public List<Order> listMyOrders() {
        return Order.list("ownerUsername", identity.getPrincipal().getName());
    }

    public Order findMyOrder(Long id) {
        return Order.find("id = ?1 and ownerUsername = ?2",
            id, identity.getPrincipal().getName())
            .firstResult();
    }
}
```

## Pattern: HTMX Authentication with Session Cookies

For HTMX apps, session cookies are the natural auth mechanism (sent automatically
on every request). Avoid Bearer tokens in HTMX unless you have a specific reason.

```properties
# application.properties
quarkus.http.auth.form.enabled=true
quarkus.http.auth.form.login-page=/ui/login
quarkus.http.auth.form.landing-page=/ui/dashboard
quarkus.http.auth.session.cookie-same-site=STRICT
quarkus.http.auth.session.cookie-secure=true
quarkus.http.auth.session.cookie-http-only=true
```

Handle HTMX-specific auth redirects (HTMX cannot follow 302 redirects transparently):

```java
@Provider
@Priority(Priorities.AUTHENTICATION - 1)
public class HtmxAuthRedirectFilter implements ContainerResponseFilter {

    @Override
    public void filter(ContainerRequestContext req, ContainerResponseContext res) {
        boolean isHtmx = "true".equals(req.getHeaderString("HX-Request"));
        if (isHtmx && res.getStatus() == 302) {
            // Tell HTMX to do a full-page redirect to login
            res.setStatus(200);
            res.getHeaders().putSingle("HX-Redirect",
                res.getHeaderString("Location"));
        }
    }
}
```

## Pattern: CSRF + HTMX (complete setup)

```properties
quarkus.csrf-reactive.enabled=true
quarkus.csrf-reactive.token-header-name=X-CSRF-TOKEN
quarkus.csrf-reactive.cookie-same-site=STRICT
```

Base template (attach token to every HTMX request):

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

## Pattern: Security Headers Filter

```java
@Provider
public class SecurityHeadersFilter implements ContainerResponseFilter {

    @Override
    public void filter(ContainerRequestContext req, ContainerResponseContext res) {
        var headers = res.getHeaders();
        headers.putSingle("X-Content-Type-Options", "nosniff");
        headers.putSingle("X-Frame-Options", "DENY");
        headers.putSingle("Referrer-Policy", "strict-origin-when-cross-origin");
        headers.putSingle("Permissions-Policy",
            "camera=(), microphone=(), geolocation=()");
        // CSP -- prefer the htmx CSP-compatible build to avoid unsafe-eval
        headers.putSingle("Content-Security-Policy",
            "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'");
    }
}
```

## Pattern: Password Hashing

Always use bcrypt for password storage. Never store plaintext or MD5/SHA hashes.

```java
import org.wildfly.security.password.Password;
import org.wildfly.security.password.PasswordFactory;
import org.wildfly.security.password.interfaces.BCryptPassword;
import io.quarkus.elytron.security.common.BcryptUtil;

@ApplicationScoped
public class UserService {

    @Transactional
    public AppUser register(String username, String rawPassword, String role) {
        if (AppUser.find("username", username).firstResult() != null) {
            throw new WebApplicationException("Username taken", 409);
        }
        AppUser user = new AppUser();
        user.username = username;
        user.password = BcryptUtil.bcryptHash(rawPassword);
        user.role = role;
        user.persist();
        return user;
    }
}
```

## Pattern: Rate Limiting on Login

Protect authentication endpoints from brute-force attacks:

```java
@Path("/ui/login")
@ApplicationScoped
public class LoginResource {

    // Per-IP rate limiter: max 10 attempts per minute
    private final Cache<String, AtomicInteger> attempts = CacheBuilder.newBuilder()
        .expireAfterWrite(1, TimeUnit.MINUTES)
        .build();

    @POST
    @Consumes(MediaType.APPLICATION_FORM_URLENCODED)
    public Response login(
        @FormParam("username") @NotBlank String username,
        @FormParam("password") @NotBlank String password,
        @Context HttpServerRequest request
    ) {
        String clientIp = request.remoteAddress().host();
        AtomicInteger count = attempts.get(clientIp, AtomicInteger::new);
        if (count.incrementAndGet() > 10) {
            return Response.status(429).entity("Too many login attempts").build();
        }
        // delegate to Quarkus form auth or custom auth logic
    }
}
```

## Pattern: Audit Logging for Security Events

```java
@ApplicationScoped
public class SecurityAuditLogger {

    private static final Logger LOG = Logger.getLogger(SecurityAuditLogger.class);

    public void onAuthSuccess(@Observes AuthenticationSuccessEvent event) {
        LOG.infof("AUTH_SUCCESS user=%s", event.getIdentity().getPrincipal().getName());
    }

    public void onAuthFailure(@Observes AuthenticationFailedEvent event) {
        LOG.warnf("AUTH_FAILURE reason=%s", event.getAuthenticationRequest());
    }

    public void onForbidden(@Observes @Priority(1) ForbiddenException event) {
        LOG.warnf("ACCESS_DENIED resource=%s", event.getMessage());
    }
}
```
