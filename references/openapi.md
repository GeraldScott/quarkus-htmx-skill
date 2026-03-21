# OpenAPI & Swagger UI Reference

Consolidated reference for Quarkus SmallRye OpenAPI: annotations, filters, static documents, Swagger UI, and configuration.

## Overview and setup

Extension dependency:

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-smallrye-openapi</artifactId>
</dependency>
```

Or add it via CLI:

```bash
quarkus extension add quarkus-smallrye-openapi
```

Default endpoints once enabled:

- OpenAPI document: `/q/openapi`
- JSON format: `/q/openapi?format=json`
- Swagger UI: `/q/swagger-ui` (dev and test only by default)

Verify by starting dev mode and opening `/q/openapi` or `/q/swagger-ui`.

## Documenting operations (@Operation, @APIResponse, @Schema)

### Basic operation

```java
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@Path("/products")
@Tag(name = "products")
class ProductResource {
    @GET
    @Operation(summary = "List products", operationId = "listProducts")
    @APIResponse(responseCode = "200", description = "Products returned")
    public List<Product> list() {
        return service.findAll();
    }
}
```

Prefer explicit `operationId` values when clients will be generated from the schema.

### Multiple responses

```java
@GET
@Operation(summary = "Get product by id", operationId = "getProductById")
@APIResponse(responseCode = "200", description = "Product returned")
@APIResponse(responseCode = "404", description = "Product not found")
public Product byId(@RestPath String id) {
    return service.find(id);
}
```

Also consider `quarkus.smallrye-openapi.operation-id-strategy` when explicit IDs are not practical. Built-in strategies: `method`, `class-method`, `package-class-method`.

### Request and response schemas

```java
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.RequestBody;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;

@POST
@RequestBody(required = true, content = @Content(schema = @Schema(implementation = CreateProduct.class)))
@APIResponse(
    responseCode = "201",
    description = "Product created",
    content = @Content(schema = @Schema(implementation = Product.class))
)
public Product create(CreateProduct command) {
    return service.create(command);
}
```

### Schema hints on models

```java
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(name = "Product", description = "Catalog product returned by the API")
public class Product {
    @Schema(example = "sku-123")
    public String sku;

    @Schema(example = "Coffee mug")
    public String name;
}
```

## Application-level metadata (annotation vs config)

### Annotation approach

```java
import jakarta.ws.rs.core.Application;
import org.eclipse.microprofile.openapi.annotations.OpenAPIDefinition;
import org.eclipse.microprofile.openapi.annotations.info.Contact;
import org.eclipse.microprofile.openapi.annotations.info.Info;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@OpenAPIDefinition(
    info = @Info(
        title = "Catalog API",
        version = "1.0.0",
        description = "Operations for product catalog management",
        contact = @Contact(name = "API Support", email = "support@example.com")
    ),
    tags = @Tag(name = "catalog", description = "Catalog operations")
)
public class ApiApplication extends Application {
}
```

### Config approach (preferred when values vary by environment)

```properties
quarkus.smallrye-openapi.info-title=Inventory API
%dev.quarkus.smallrye-openapi.info-title=Inventory API (dev)
quarkus.smallrye-openapi.info-version=1.0.0
quarkus.smallrye-openapi.info-description=Inventory and stock management endpoints
quarkus.smallrye-openapi.info-contact-name=API Support
quarkus.smallrye-openapi.info-contact-email=support@example.com
quarkus.smallrye-openapi.info-license-name=Apache-2.0
```

Prefer config over hardcoded annotations when deployments need different labels.

## Security scheme metadata

### Annotation approach

```java
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.enums.SecuritySchemeType;
import org.eclipse.microprofile.openapi.annotations.security.SecurityRequirement;
import org.eclipse.microprofile.openapi.annotations.security.SecurityScheme;

@SecurityScheme(
    securitySchemeName = "bearerAuth",
    type = SecuritySchemeType.HTTP,
    scheme = "bearer",
    bearerFormat = "JWT"
)
class OpenApiSecurity {
}

@GET
@Operation(summary = "Read current profile")
@SecurityRequirement(name = "bearerAuth")
public Profile me() {
    return service.currentProfile();
}
```

### Config approach (avoids repeating annotations across resources)

```properties
quarkus.smallrye-openapi.security-scheme=jwt
quarkus.smallrye-openapi.security-scheme-name=bearerAuth
quarkus.smallrye-openapi.security-scheme-description=JWT bearer authentication
quarkus.smallrye-openapi.auto-add-security=true
quarkus.smallrye-openapi.auto-add-security-requirement=true
```

For API key auth, also set `quarkus.smallrye-openapi.api-key-parameter-in` and `quarkus.smallrye-openapi.api-key-parameter-name`.

## OpenAPI filters (OASFilter)

```java
import io.quarkus.smallrye.openapi.OpenApiFilter;
import org.eclipse.microprofile.openapi.OASFilter;
import org.eclipse.microprofile.openapi.models.OpenAPI;

@OpenApiFilter(stages = OpenApiFilter.RunStage.BUILD)
public class ContractFilter implements OASFilter {
    @Override
    public void filterOpenAPI(OpenAPI openAPI) {
        openAPI.getInfo().setDescription("Generated contract for platform consumers");
    }
}
```

Filter stages:

- **BUILD** -- runs once at build time. Preferred for static enrichment.
- **RUNTIME_STARTUP** -- runs once at application start.
- **RUNTIME_PER_REQUEST** -- runs on every schema request. Use only when the document truly needs request-specific changes.

A filter can also be registered declaratively with `mp.openapi.filter=com.example.MyFilter`.

## Static documents

Supported contract file locations:

- `src/main/resources/META-INF/openapi.yml`
- `src/main/resources/META-INF/openapi.yaml`
- `src/main/resources/META-INF/openapi.json`

Static content is merged with generated content by default. For static-only mode:

```properties
mp.openapi.scan.disable=true
```

Example static contract at `src/main/resources/META-INF/openapi.yml`:

```yaml
openapi: 3.1.0
info:
  title: Inventory API
  version: "1.0"
paths:
  /products:
    get:
      responses:
        "200":
          description: OK
```

To merge additional static fragments alongside generated output:

```properties
quarkus.smallrye-openapi.additional-docs-directory=META-INF/openapi
```

If a checked-in `META-INF/openapi.*` file should be ignored for one document, use `quarkus.smallrye-openapi.<document-name>.ignore-static-document=true`.

## Multiple documents

Use scan profiles to split a large application into separate contracts for different consumers.

### Tag operations with profile extensions

```java
import org.eclipse.microprofile.openapi.annotations.extensions.Extension;

@GET
@Path("/users")
@Extension(name = "x-smallrye-profile-user", value = "")
public List<UserDto> listUsers() {
    return service.listUsers();
}

@GET
@Path("/orders")
@Extension(name = "x-smallrye-profile-order", value = "")
public List<OrderDto> listOrders() {
    return service.listOrders();
}
```

### Configure named documents

```properties
quarkus.smallrye-openapi.user.scan-profiles=user
quarkus.smallrye-openapi.order.scan-profiles=order
quarkus.smallrye-openapi.user.path=/openapi-user
quarkus.smallrye-openapi.order.path=/openapi-order
mp.openapi.extensions.smallrye.remove-unused-schemas.enable=true
```

If all documents should advertise the same server list, use `mp.openapi.servers`. If only one named document differs, use `quarkus.smallrye-openapi.<document-name>.servers`.

For named documents, use the document-specific form for any property: `quarkus.smallrye-openapi.<document-name>.*`.

## Swagger UI configuration

### Custom paths

```properties
quarkus.smallrye-openapi.path=/swagger
quarkus.swagger-ui.path=docs
```

Paths starting with `/` are absolute; otherwise they resolve under the non-application root.

### Include in production

```properties
quarkus.swagger-ui.always-include=true
```

This is a build-time property -- rebuild after changing it.

### Multiple documents in one UI

```properties
quarkus.swagger-ui.always-include=true
quarkus.swagger-ui.urls."Combined"=/q/openapi
quarkus.swagger-ui.urls."User Service"=/q/openapi-user
quarkus.swagger-ui.urls."Order Service"=/q/openapi-order
quarkus.swagger-ui.urls-primary-name=Combined
quarkus.swagger-ui.try-it-out-enabled=true
quarkus.swagger-ui.persist-authorization=true
```

### Advanced hooks and auth

- Request/response hooks: `request-interceptor`, `response-interceptor`, `request-curl-options`, `show-mutated-request`
- Rendering: `show-extensions`, `show-common-extensions`, `syntax-highlight`, `layout`, `plugins`, `scripts`, `presets`, `on-complete`
- Browser/network: `with-credentials`, `oauth2-redirect-url`
- OAuth init: `oauth-client-id`, `oauth-client-secret`, `oauth-realm`, `oauth-app-name`, `oauth-scope-separator`, `oauth-scopes`, `oauth-use-pkce-with-authorization-code-grant`
- Preauthorization: `preauthorize-basic-auth-definition-key`, `preauthorize-basic-username`, `preauthorize-basic-password`, `preauthorize-api-key-auth-definition-key`, `preauthorize-api-key-api-key-value`

All prefixed with `quarkus.swagger-ui.`.

## CI artifact generation

```properties
quarkus.smallrye-openapi.store-schema-directory=target/generated-openapi
quarkus.smallrye-openapi.store-schema-file-name=inventory
```

This writes `inventory.yaml` and `inventory.json` during the build, useful for pipelines that need a stable schema file for client generation or contract testing.

## Configuration reference

### OpenAPI endpoint and document output

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.smallrye-openapi.enabled` | `true` | The OpenAPI endpoint must be disabled entirely |
| `quarkus.smallrye-openapi.management.enabled` | `true` | OpenAPI should/should not be exposed on the management interface |
| `quarkus.smallrye-openapi.path` | `openapi` | The default document needs a custom path |
| `quarkus.smallrye-openapi.<doc>.path` | `openapi-<doc>` | A named document needs its own path |
| `quarkus.smallrye-openapi.store-schema-directory` | - | Build output should include generated schema files |
| `quarkus.smallrye-openapi.store-schema-file-name` | `openapi` | Stored schema files need a custom base name |
| `quarkus.smallrye-openapi.ignore-static-document` | `false` | `META-INF/openapi.*` exists but should not be merged |
| `quarkus.smallrye-openapi.additional-docs-directory` | - | Static fragments should be merged from additional dirs |
| `quarkus.smallrye-openapi.open-api-version` | generated | The contract must target a specific OpenAPI version |
| `quarkus.smallrye-openapi.servers` | - | The default document should advertise explicit servers |
| `quarkus.smallrye-openapi.<doc>.servers` | - | A named document needs a different server list |

### Metadata and generated content

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.smallrye-openapi.info-title` | - | Title from config instead of annotations |
| `quarkus.smallrye-openapi.info-version` | - | Version injected by environment/release |
| `quarkus.smallrye-openapi.info-description` | - | Description set from config |
| `quarkus.smallrye-openapi.info-contact-name` | - | Contact name included |
| `quarkus.smallrye-openapi.info-contact-email` | - | Contact email included |
| `quarkus.smallrye-openapi.info-contact-url` | - | Contact URL included |
| `quarkus.smallrye-openapi.info-license-name` | - | License metadata included |
| `quarkus.smallrye-openapi.info-license-url` | - | License URL included |
| `quarkus.smallrye-openapi.info-terms-of-service` | - | Terms of service published |
| `quarkus.smallrye-openapi.operation-id-strategy` | - | Consistent IDs for client generation |
| `quarkus.smallrye-openapi.auto-add-tags` | `true` | Automatic class-name tags on/off |
| `quarkus.smallrye-openapi.auto-add-operation-summary` | `true` | Method-name-based summaries on/off |
| `quarkus.smallrye-openapi.auto-add-bad-request-response` | `true` | Default 400 responses on/off |
| `quarkus.smallrye-openapi.auto-add-security-requirement` | `true` | `@RolesAllowed` auto security requirements |
| `quarkus.smallrye-openapi.auto-add-security` | `true` | Security requirements from configured schemes |
| `quarkus.smallrye-openapi.auto-add-server` | unset | Default server entry generation |
| `quarkus.smallrye-openapi.auto-add-open-api-endpoint` | `false` | Include the OpenAPI endpoint itself in the schema |
| `quarkus.smallrye-openapi.scan-profiles` | - | Include only selected profile-tagged operations |
| `quarkus.smallrye-openapi.scan-exclude-profiles` | - | Exclude selected profile-tagged operations |
| `quarkus.smallrye-openapi.merge-schema-examples` | `true` | Preserve deprecated `@Schema(example=...)` behavior |

### MicroProfile OpenAPI properties

| Property | Default | Use when |
|----------|---------|----------|
| `mp.openapi.scan.disable` | `false` | Only static documents should be served |
| `mp.openapi.filter` | - | Register an `OASFilter` declaratively |
| `mp.openapi.servers` | - | Same server list for all documents |
| `mp.openapi.extensions.smallrye.remove-unused-schemas.enable` | `false` | Drop unreferenced schemas from filtered/named docs |

### Security scheme config

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.smallrye-openapi.security-scheme` | - | Declare a standard scheme from config |
| `quarkus.smallrye-openapi.security-scheme-name` | `SecurityScheme` | Stable public name for the scheme |
| `quarkus.smallrye-openapi.security-scheme-description` | `Authentication` | Better description for the scheme |
| `quarkus.smallrye-openapi.security-scheme-extensions."ext"` | - | Vendor extensions on the scheme |
| `quarkus.smallrye-openapi.api-key-parameter-in` | - | API key location: `query`, `header`, `cookie` |
| `quarkus.smallrye-openapi.api-key-parameter-name` | - | API key header/query/cookie name |
| `quarkus.smallrye-openapi.basic-security-scheme-value` | `basic` | Custom basic auth scheme text |
| `quarkus.smallrye-openapi.jwt-security-scheme-value` | `bearer` | Custom JWT scheme value |
| `quarkus.smallrye-openapi.jwt-bearer-format` | `JWT` | Custom JWT bearer format |
| `quarkus.smallrye-openapi.oidc-open-id-connect-url` | - | Publish OIDC discovery metadata |

### Swagger UI properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.swagger-ui.path` | `swagger-ui` | Custom UI path |
| `quarkus.swagger-ui.always-include` | `false` | Package UI outside dev/test |
| `quarkus.swagger-ui.enabled` | `true` | Toggle included UI on/off |
| `quarkus.swagger-ui.urls."name"` | - | Offer multiple documents in the top bar |
| `quarkus.swagger-ui.urls-primary-name` | - | Preselect one document entry |
| `quarkus.swagger-ui.title` | - | Custom browser page title |
| `quarkus.swagger-ui.theme` | - | Non-default theme |
| `quarkus.swagger-ui.footer` | - | Custom footer |
| `quarkus.swagger-ui.filter` | - | Enable tag filtering |
| `quarkus.swagger-ui.doc-expansion` | UI default | Tags/operations expanded or collapsed |
| `quarkus.swagger-ui.display-operation-id` | `false` | Show operation IDs in UI |
| `quarkus.swagger-ui.try-it-out-enabled` | `false` | Start try-it-out enabled |
| `quarkus.swagger-ui.persist-authorization` | UI default | Keep auth state on refresh |
| `quarkus.swagger-ui.operations-sorter` | server order | Sort by path or method |
| `quarkus.swagger-ui.tags-sorter` | UI default | Predictable tag sorting |
| `quarkus.swagger-ui.validator-url` | swagger.io | Redirect or disable validation |

### Deprecated keys to avoid

- `quarkus.smallrye-openapi.enable`
- `quarkus.swagger-ui.enable`
- `quarkus.smallrye-openapi.always-run-filter`

## Gotchas

### Paths and visibility

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Swagger UI works in dev but is missing in production | `quarkus.swagger-ui.always-include` defaults to `false` | Set `quarkus.swagger-ui.always-include=true` and rebuild |
| OpenAPI or Swagger UI path is not where expected | Relative paths resolve under the non-application root | Use an absolute path starting with `/` |
| Setting `quarkus.swagger-ui.path=/` breaks the app | `/` is not a valid Swagger UI path | Use a sub-path such as `docs` or `/docs` |

### Generated vs static documents

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Static YAML is present but generated endpoints still appear | Static documents merge with generated output by default | Set `mp.openapi.scan.disable=true` for static-only mode |
| A checked-in static contract unexpectedly changes the main document | `META-INF/openapi.*` is auto-loaded | Remove the file, move it, or set `ignore-static-document=true` |

### Filters and rebuilds

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Filter runs only once even though the document should be dynamic | Filter stage is `BUILD` or `RUNTIME_STARTUP` | Use `@OpenApiFilter(stages = OpenApiFilter.RunStage.RUNTIME_PER_REQUEST)` |
| Packaged app ignores Swagger UI visibility changes | `always-include` is a build-time property | Rebuild the application after changing it |
| Per-request filter logic is expensive | Dynamic filter runs on every schema request | Move work to `BUILD` or `RUNTIME_STARTUP` unless request-specific data is required |

### Multiple documents

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Named documents still share some settings unexpectedly | `mp.openapi.*` properties apply to all documents | Use `quarkus.smallrye-openapi.<doc>.*` for document-specific settings |
| Operation appears in the wrong named document | Profile extension is missing or mismatched | Verify `@Extension(name = "x-smallrye-profile-...")` values match `scan-profiles` config |
| Class-level and method-level profile extensions do not combine | Method extensions override class extensions | Put the full intended profile set on the method |

### Contract quality

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Generated client method names are unstable | Operation IDs omitted or derived from renamed methods | Set explicit `@Operation(operationId = ...)` or configure an operation ID strategy |
| Secured endpoints look public in the contract | Security scheme metadata or requirements missing | Define `@SecurityScheme` or matching config and add `@SecurityRequirement` |
| Split documents still contain unused schemas | Schema cleanup is disabled | Set `mp.openapi.extensions.smallrye.remove-unused-schemas.enable=true` |
