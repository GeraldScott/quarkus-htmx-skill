# Quarkus Security API Reference

Use this module when the task involves authentication, authorization, RBAC, OIDC/OAuth2, security headers, or protecting endpoints and resources.

## Overview

Quarkus security is built on a pluggable architecture. The core extension `quarkus-security` provides annotations and the security API. Identity providers (OIDC, JDBC, LDAP) handle authentication. Authorization is declarative via annotations or imperative via `SecurityIdentity`.

## Extensions

```xml
<!-- Core security (always needed) -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-security</artifactId>
</dependency>

<!-- OIDC (Keycloak, Auth0, Okta, etc.) -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-oidc</artifactId>
</dependency>

<!-- Form-based authentication (session cookies) -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-security-jpa</artifactId>
</dependency>

<!-- CSRF protection for HTMX -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-csrf-reactive</artifactId>
</dependency>
```

## Authentication

### OIDC configuration (Keycloak example)

```properties
# application.properties
quarkus.oidc.auth-server-url=https://keycloak.example.com/realms/my-realm
quarkus.oidc.client-id=${OIDC_CLIENT_ID}
quarkus.oidc.credentials.secret=${OIDC_CLIENT_SECRET}
quarkus.oidc.application-type=web-app
quarkus.oidc.authentication.redirect-path=/ui/login-callback
quarkus.oidc.logout.path=/ui/logout

# Session cookie settings
quarkus.http.auth.session.cookie-same-site=STRICT
quarkus.http.auth.session.cookie-secure=true
quarkus.http.auth.session.cookie-http-only=true
```

### SecurityIdentity (current user)

```java
import io.quarkus.security.identity.SecurityIdentity;

@Path("/ui/profile")
@Authenticated
@ApplicationScoped
public class ProfileResource {

    @Inject SecurityIdentity identity;

    @GET
    @Produces(MediaType.TEXT_HTML)
    public TemplateInstance profile() {
        String username = identity.getPrincipal().getName();
        Set<String> roles = identity.getRoles();
        return profileTemplate.data("username", username)
                              .data("roles", roles);
    }
}
```

### Form-based login with JPA identity store

```java
@Entity
@Table(name = "app_user")
@UserDefinition
public class AppUser extends PanacheEntity {

    @Username
    @Column(unique = true, nullable = false)
    public String username;

    @Password
    @Column(nullable = false)
    public String password; // stored as bcrypt hash

    @Roles
    public String role;
}
```

```properties
quarkus.http.auth.form.enabled=true
quarkus.http.auth.form.login-page=/ui/login
quarkus.http.auth.form.error-page=/ui/login?error
quarkus.http.auth.form.landing-page=/ui/dashboard
quarkus.http.auth.session.encryption-key=${SESSION_ENCRYPTION_KEY}
```

## Authorization annotations

```java
import io.quarkus.security.Authenticated;
import jakarta.annotation.security.RolesAllowed;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.DenyAll;

@Path("/ui/admin")
@RolesAllowed("admin")
public class AdminResource {

    @GET
    public TemplateInstance dashboard() { /* admin only */ }

    @GET @Path("/users")
    @RolesAllowed({"admin", "manager"})
    public TemplateInstance users() { /* admin or manager */ }
}

@Path("/ui/items")
@Authenticated  // any logged-in user
public class ItemResource {

    @GET
    @PermitAll  // override class-level -- public access
    public TemplateInstance list() { /* anyone */ }

    @POST @Transactional
    public TemplateInstance create(@Valid ItemForm form) { /* logged-in only */ }
}
```

## HTTP-level security policy

```properties
# Protect all /ui/admin/* paths
quarkus.http.auth.permission.admin.paths=/ui/admin/*
quarkus.http.auth.permission.admin.policy=admin-policy
quarkus.http.auth.policy.admin-policy.roles-allowed=admin

# Protect all /api/* paths -- require authentication
quarkus.http.auth.permission.api.paths=/api/*
quarkus.http.auth.permission.api.policy=authenticated

# Public paths
quarkus.http.auth.permission.public.paths=/ui/login,/ui/register,/q/*
quarkus.http.auth.permission.public.policy=permit
```

## Security headers

```properties
# Recommended production security headers
quarkus.http.header."Strict-Transport-Security".value=max-age=31536000; includeSubDomains
quarkus.http.header."X-Content-Type-Options".value=nosniff
quarkus.http.header."X-Frame-Options".value=DENY
quarkus.http.header."Referrer-Policy".value=strict-origin-when-cross-origin
quarkus.http.header."Permissions-Policy".value=camera=(), microphone=(), geolocation=()
quarkus.http.header."Content-Security-Policy".value=default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'
```

## CORS configuration

```properties
quarkus.http.cors=true
quarkus.http.cors.origins=https://app.example.com
quarkus.http.cors.methods=GET,POST,PUT,DELETE
quarkus.http.cors.headers=Content-Type,X-CSRF-TOKEN,Authorization
quarkus.http.cors.access-control-allow-credentials=true
```

Never use `quarkus.http.cors.origins=*` with `access-control-allow-credentials=true`.

## HTTPS enforcement

```properties
# Redirect HTTP to HTTPS in production
%prod.quarkus.http.insecure-requests=redirect
%prod.quarkus.http.ssl.certificate.files=/path/to/cert.pem
%prod.quarkus.http.ssl.certificate.key-files=/path/to/key.pem
```

## Security testing

```java
import io.quarkus.test.security.TestSecurity;

@QuarkusTest
class AdminResourceTest {

    @Test
    @TestSecurity(user = "admin", roles = "admin")
    void adminCanAccessDashboard() {
        given().when().get("/ui/admin")
            .then().statusCode(200);
    }

    @Test
    @TestSecurity(user = "user", roles = "user")
    void regularUserCannotAccessAdmin() {
        given().when().get("/ui/admin")
            .then().statusCode(403);
    }

    @Test
    void unauthenticatedUserIsRedirected() {
        given().redirects().follow(false)
            .when().get("/ui/admin")
            .then().statusCode(302);
    }
}
```
