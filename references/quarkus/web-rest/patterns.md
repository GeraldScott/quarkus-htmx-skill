# Quarkus Web REST Usage Patterns

Use these patterns for repeatable HTTP API implementation workflows.

## Pattern: Bootstrap a JSON API

When to use:

- You are starting a new JSON-first service.

Command:

```bash
quarkus create app com.acme:catalog-service --extension='rest-jackson' --no-code
```

## Pattern: Keep endpoint return types concrete

When to use:

- You want native-friendly serialization and clearer API contracts.

Example:

```java
import java.util.List;

import org.jboss.resteasy.reactive.RestResponse;

@GET
public List<Fruit> list() {
    return service.findAll();
}

@GET
@Path("{id}")
public RestResponse<Fruit> byId(String id) {
    return RestResponse.ok(service.find(id));
}
```

Prefer this over returning raw `Response` unless dynamic payload typing is required.

## Pattern: Map domain exceptions at the HTTP boundary

When to use:

- Service-layer exceptions should map to stable HTTP responses.

Example:

```java
import jakarta.ws.rs.core.Response;
import org.jboss.resteasy.reactive.RestResponse;
import org.jboss.resteasy.reactive.server.ServerExceptionMapper;

record ApiError(String code, String message) {
}

class Mappers {
    @ServerExceptionMapper
    RestResponse<ApiError> map(UnknownFruitException x) {
        return RestResponse.status(Response.Status.NOT_FOUND, new ApiError("FRUIT_NOT_FOUND", x.getMessage()));
    }
}
```

## Pattern: Upload file + JSON metadata in one request

When to use:

- Clients submit binary data and structured metadata together.

Example:

```java
@POST
@Consumes(MediaType.MULTIPART_FORM_DATA)
void upload(@RestForm("file") FileUpload file,
            @RestForm @PartType(MediaType.APPLICATION_JSON) Metadata metadata) {
    // move uploaded file to durable storage before request ends
}
```

## Pattern: Use reactive signatures intentionally

When to use:

- Endpoint behavior is asynchronous or streaming.

Example:

```java
@GET
Uni<Event> latest() {
    return service.latest();
}

@GET
Multi<Event> stream() {
    return service.stream();
}
```

Use `@Blocking` when interacting with blocking technologies.

## Pattern: Validate request bodies with Bean Validation

When to use:

- Incoming JSON payloads need constraint checking before reaching business logic.

Example:

```java
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;

record CreateOrder(@NotBlank String product, @Positive int quantity) {
}

@POST
RestResponse<Order> create(@Valid CreateOrder command) {
    return RestResponse.status(Response.Status.CREATED, service.create(command));
}
```

Quarkus returns 400 with violation details automatically. Add `quarkus-hibernate-validator`.

## Pattern: Stream data to clients with Server-Sent Events

When to use:

- Clients need a continuous push of updates (dashboards, notifications, live feeds).

Example:

```java
@GET
@Path("/stream")
@Produces(MediaType.SERVER_SENT_EVENTS)
@RestStreamElementType(MediaType.APPLICATION_JSON)
Multi<StockPrice> prices() {
    return priceService.stream();
}
```

The connection stays open and events are pushed as the `Multi` emits items.

## Pattern: Call an external API with the REST Client

When to use:

- Your service needs to call another HTTP service.

Example:

```java
@Path("/weather")
@RegisterRestClient(configKey = "weather-api")
public interface WeatherClient {
    @GET
    @Path("/{city}")
    WeatherForecast forecast(@RestPath String city);
}
```

```properties
quarkus.rest-client.weather-api.url=https://api.weather.example
quarkus.rest-client.weather-api.scope=jakarta.inject.Singleton
```

```java
@ApplicationScoped
class ForecastService {
    @RestClient
    WeatherClient weather;

    WeatherForecast get(String city) {
        return weather.forecast(city);
    }
}
```

The REST Client shares provider infrastructure (JSON serialization, filters, exception mappers) with Quarkus REST server endpoints.

## Pattern: HTMX response headers for client-side control

When to use:

- An HTMX endpoint needs to trigger client-side events, redirect, or update the browser URL after a server action.

Example:

```java
// Trigger a client-side event after adding an item
return Response.ok(fragment.render())
    .header("HX-Trigger", "itemAdded")
    .build();

// Redirect to another page (full page navigation)
return Response.ok()
    .header("HX-Redirect", "/ui/items")
    .build();

// Update browser URL without a full redirect
return Response.ok(fragment.render())
    .header("HX-Push-Url", "/ui/items/" + item.id)
    .build();
```

Useful HX-* response headers:

| Header | Purpose |
|--------|---------|
| `HX-Trigger` | Fire a client-side event after the response is processed |
| `HX-Redirect` | Redirect the browser (full page) |
| `HX-Push-Url` | Update browser URL without redirect |
| `HX-Reswap` | Override the `hx-swap` on the request |
| `HX-Retarget` | Override the `hx-target` on the request |
| `HX-Refresh` | Force a full page reload (`true`) |

## Pattern: Post/Redirect/Get with HTMX

When to use:

- After a form submission, the server should redirect to avoid duplicate submissions on refresh.

Example:

```java
@POST
@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
@Transactional
public Response createProduct(
    @FormParam("name") String name,
    @FormParam("price") BigDecimal price
) {
    productService.create(name, price);
    return Response.seeOther(URI.create("/ui/products")).build();
}
```

For HTMX requests that should redirect on the client side, use the `HX-Redirect` header instead of HTTP 303.
