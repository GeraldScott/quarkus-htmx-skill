# Quarkus Web REST API Reference

Use this module when the task is about Quarkus REST and HTTP APIs: endpoint mapping, JSON payloads, request/response handling, exception mapping, filters, multipart, form data, and reactive streaming.

## Overview

Quarkus REST (formerly RESTEasy Reactive) is Quarkus' Jakarta REST implementation built on Vert.x with build-time optimization.

- Supports blocking and non-blocking endpoints in the same application.
- Supports JSON with Jackson (`quarkus-rest-jackson`) or JSON-B (`quarkus-rest-jsonb`).
- Includes multipart handling, streaming, content negotiation, and typed responses.
- Shares provider infrastructure with Quarkus REST Client.

## General guidelines

- Prefer concrete return types (`Fruit`, `List<Fruit>`, `RestResponse<Fruit>`) over raw `Response`.
- Keep blocking work off the event-loop thread; use reactive APIs or `@Blocking`.
- Map domain/service exceptions to HTTP with `@ServerExceptionMapper`.
- Move uploaded files to durable storage during request handling.

---

## Extension entry points

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-rest</artifactId>
</dependency>
```

JSON variants:

- `io.quarkus:quarkus-rest-jackson`
- `io.quarkus:quarkus-rest-jsonb`

## Minimal endpoint

```java
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;

@Path("/hello")
class GreetingResource {
    @GET
    String hello() {
        return "hello";
    }
}
```

## Base path

```java
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

@ApplicationPath("/api")
public class ApiApplication extends Application {
}
```

Alternative: set `quarkus.rest.path=/api`.

## Request parameters

```java
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import org.jboss.resteasy.reactive.RestCookie;
import org.jboss.resteasy.reactive.RestHeader;
import org.jboss.resteasy.reactive.RestPath;
import org.jboss.resteasy.reactive.RestQuery;

@Path("/items/{id}")
class ItemResource {
    @GET
    String get(@RestPath String id,
               @RestQuery String expand,
               @RestCookie("tenant") String tenant,
               @RestHeader("X-Request-Id") String requestId) {
        return id;
    }
}
```

`@RestPath` is optional when the parameter name matches a URI template variable.

## Form data handling

For HTML form submissions (common with HTMX POST requests):

```java
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.FormParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/cart")
class CartResource {
    @POST
    @Consumes(MediaType.APPLICATION_FORM_URLENCODED)
    @Produces(MediaType.TEXT_HTML)
    @Transactional
    public TemplateInstance addToCart(
        @FormParam("productId") @NotNull Long productId,
        @FormParam("quantity") @Min(1) @Max(999) int quantity
    ) {
        Cart cart = cartService.add(productId, quantity);
        return cartFragment.data("cart", cart);
    }
}
```

Use `@FormParam` with `@Consumes(MediaType.APPLICATION_FORM_URLENCODED)` for standard HTML form posts. This is the primary pattern for HTMX `hx-post` endpoints that submit form fields. Always add Bean Validation constraints (`@NotNull`, `@NotBlank`, `@Size`, `@Min`, `@Max`) to form parameters -- never trust client-side validation alone.

## Typed responses

```java
import org.jboss.resteasy.reactive.RestResponse;

@GET
RestResponse<Fruit> byId() {
    return RestResponse.ok(new Fruit());
}
```

Prefer `RestResponse<T>` over raw `Response` when possible.

## Multipart form handling

```java
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.core.MediaType;
import org.jboss.resteasy.reactive.PartType;
import org.jboss.resteasy.reactive.RestForm;
import org.jboss.resteasy.reactive.multipart.FileUpload;

@Path("/uploads")
class UploadResource {
    static class Metadata {
        public String owner;
    }

    private static final Set<String> ALLOWED_TYPES = Set.of(
        "image/png", "image/jpeg", "application/pdf");

    @POST
    @Consumes(MediaType.MULTIPART_FORM_DATA)
    Response upload(@RestForm("file") FileUpload file,
                    @RestForm @PartType(MediaType.APPLICATION_JSON) Metadata metadata) {
        // Validate file size (also set quarkus.http.limits.max-body-size)
        if (file.size() > 5_000_000) {
            return Response.status(413).entity("File too large (max 5 MB)").build();
        }
        // Validate content type against allowlist
        if (!ALLOWED_TYPES.contains(file.contentType())) {
            return Response.status(415).entity("Unsupported file type").build();
        }
        // Sanitize filename -- strip path components to prevent traversal
        String safeName = java.nio.file.Path.of(file.fileName())
            .getFileName().toString();
        // Store outside the web root
        java.nio.file.Files.copy(file.filePath(), uploadDir.resolve(safeName));
        return Response.ok().build();
    }
}
```

## Reactive endpoints

```java
import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;

@GET
Uni<Fruit> latest() {
    return Uni.createFrom().item(new Fruit());
}

@GET
Multi<Fruit> stream() {
    return Multi.createFrom().items(new Fruit(), new Fruit());
}
```

Use `Uni` for one async value and `Multi` for streams.

## Content negotiation

```java
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/report")
class ReportResource {
    @GET
    @Produces({ MediaType.APPLICATION_JSON, MediaType.TEXT_PLAIN })
    Report get() {
        return new Report();
    }
}
```

Quarkus selects the response format based on the `Accept` header. List preferred types first. When combined with Qute, content negotiation can serve HTML or JSON from the same endpoint using template variants.

## Exception mapping

```java
import jakarta.ws.rs.core.Response;
import org.jboss.resteasy.reactive.RestResponse;
import org.jboss.resteasy.reactive.server.ServerExceptionMapper;

record ApiError(String message) {
}

class Mappers {
    @ServerExceptionMapper
    RestResponse<ApiError> map(UnknownFruitException x) {
        return RestResponse.status(Response.Status.NOT_FOUND, new ApiError(x.getMessage()));
    }
}
```

## Request/response filters

```java
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.container.ContainerResponseContext;
import org.jboss.resteasy.reactive.server.ServerRequestFilter;
import org.jboss.resteasy.reactive.server.ServerResponseFilter;

class Filters {
    @ServerRequestFilter
    void before(ContainerRequestContext ctx) {
    }

    @ServerResponseFilter
    void after(ContainerResponseContext ctx) {
    }
}
```

## Bean Validation

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-hibernate-validator</artifactId>
</dependency>
```

```java
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

record CreateFruit(@NotBlank @Size(min = 2) String name) {
}

@POST
void create(@Valid CreateFruit fruit) {
}
```

Validation errors return HTTP 400 automatically with constraint violation details.

## Server-Sent Events (SSE)

```java
import io.smallrye.mutiny.Multi;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.jboss.resteasy.reactive.RestStreamElementType;

@Path("/events")
class EventResource {
    @GET
    @Produces(MediaType.SERVER_SENT_EVENTS)
    @RestStreamElementType(MediaType.APPLICATION_JSON)
    Multi<Event> stream() {
        return eventService.stream();
    }
}
```

Return `Multi<T>` with `@Produces(MediaType.SERVER_SENT_EVENTS)` for SSE streaming.

## REST Client

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-rest-client-jackson</artifactId>
</dependency>
```

Define a client interface:

```java
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

@Path("/extensions")
@RegisterRestClient(configKey = "extensions-api")
public interface ExtensionsClient {
    @GET
    List<Extension> list();
}
```

Configure the base URL:

```properties
quarkus.rest-client.extensions-api.url=https://stage.code.quarkus.io/api
quarkus.rest-client.extensions-api.scope=jakarta.inject.Singleton
```

Inject and use:

```java
import org.eclipse.microprofile.rest.client.inject.RestClient;

@ApplicationScoped
class ExtensionService {
    @RestClient
    ExtensionsClient client;

    List<Extension> list() {
        return client.list();
    }
}
```

---

## Configuration Reference

### High-value properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.rest.path` | - | You need a base path for all REST endpoints without `@ApplicationPath` |
| `quarkus.rest.exception-mapping.disable-mapper-for` | - | A built-in mapper must be disabled so custom mappers take precedence |
| `quarkus.rest.jackson.optimization.enable-reflection-free-serializers` | `false` | You want build-time generated Jackson serializers/deserializers |
| `quarkus.jackson.fail-on-unknown-properties` | `false` | Unknown JSON fields should fail request deserialization |
| `quarkus.jackson.write-dates-as-timestamps` | `false` | Date/time fields should be serialized as timestamps |
| `quarkus.http.limits.max-form-attribute-size` | `2048` | Multipart parts must allow payloads larger than the default |
| `quarkus.http.body.delete-uploaded-files-on-end` | - | Upload temp files should be deleted automatically after request end |
| `quarkus.http.body.uploads-directory` | - | Upload temp files should be written to a specific directory |
| `quarkus.http.enable-compression` | `false` | HTTP response compression should be enabled |
| `quarkus.http.compress-media-types` | built-in list | Compression should include or exclude specific content types |

### Base path

```properties
quarkus.http.root-path=/service
quarkus.rest.path=/api
```

With this setup, `@Path("/fruits")` is served from `/service/api/fruits`.

### JSON behavior

```properties
quarkus.jackson.fail-on-unknown-properties=true
quarkus.jackson.write-dates-as-timestamps=true
quarkus.rest.jackson.optimization.enable-reflection-free-serializers=true
```

### Multipart controls

```properties
quarkus.http.limits.max-form-attribute-size=20K
quarkus.http.body.uploads-directory=/var/tmp/quarkus-uploads
quarkus.http.body.delete-uploaded-files-on-end=true
```

### Compression controls

```properties
quarkus.http.enable-compression=true
quarkus.http.compress-media-types=application/json,text/plain,text/html
```

### REST Client properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.rest-client.<configKey>.url` | - | Base URL for the REST client |
| `quarkus.rest-client.<configKey>.scope` | `@Dependent` | Client bean scope should be singleton or application-scoped |
| `quarkus.rest-client.<configKey>.connect-timeout` | provider default | Connection timeout must be tuned |
| `quarkus.rest-client.<configKey>.read-timeout` | provider default | Read timeout must be tuned |
| `quarkus.rest-client.<configKey>.follow-redirects` | `false` | Client should follow HTTP redirects |
| `quarkus.rest-client.<configKey>.tls-configuration-name` | - | Named TLS config should be used for this client |

Use `configKey` from `@RegisterRestClient(configKey = "...")` as the property segment.

### Diagnostics logging

```properties
quarkus.log.category."org.jboss.resteasy.reactive.server.handlers.ParameterHandler".level=DEBUG
quarkus.log.category."org.jboss.resteasy.reactive.common.core.AbstractResteasyReactiveContext".level=DEBUG
quarkus.log.category."WebApplicationException".level=DEBUG
```
