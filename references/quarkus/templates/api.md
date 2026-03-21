# Quarkus Templates Reference (Qute)

## Overview

Qute is Quarkus' templating engine with build-time validation, live reload integration, and native-friendly resolution.

- Templates live under `src/main/resources/templates`.
- Quarkus can inject `Template`, render `TemplateInstance`, and validate type-safe templates at build time.
- Qute works for HTML pages, plain text, emails, reports, fragments, and localized message bundles.
- REST integration is provided by `quarkus-rest-qute`; zero-controller HTTP serving is available via `quarkus-qute-web`.

### General guidelines

- Prefer `@CheckedTemplate` or template parameter declarations for build-time validation.
- Keep business logic in Java; use templates for presentation, simple branching, and formatting.
- Use `@TemplateExtension` for computed properties and formatting helpers.
- Organize templates by feature or resource class so lookups stay predictable.
- Favor generated resolvers (`@CheckedTemplate`, `@TemplateData`) over reflection-heavy access, especially for native builds.

## Extension entry points

Core templating:

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-qute</artifactId>
</dependency>
```

Serve `TemplateInstance` from Quarkus REST:

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-rest-qute</artifactId>
</dependency>
```

Serve `templates/pub/*` directly over HTTP:

```xml
<dependency>
    <groupId>io.quarkiverse.qute.web</groupId>
    <artifactId>quarkus-qute-web</artifactId>
</dependency>
```

## Inject a template

```java
import io.quarkus.qute.Location;
import io.quarkus.qute.Template;

class Emails {
    @Inject
    Template welcome;

    @Inject
    @Location("mail/reset-password")
    Template resetPassword;
}
```

Without `@Location`, the injection point name maps to `src/main/resources/templates/<name>.*`.

### Fragment naming convention

The `$` character in a Java field name maps to a path separator or fragment identifier:

```java
@Inject Template products;            // -> templates/products.html
@Inject Template products$row;        // -> templates/products$row.html (fragment)
@Inject Template emails$welcome;      // -> templates/emails/welcome.html
```

## Return `TemplateInstance` from REST

```java
import io.quarkus.qute.Template;
import io.quarkus.qute.TemplateInstance;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/hello")
class HelloResource {
    @Inject
    Template hello;

    @GET
    @Produces(MediaType.TEXT_HTML)
    TemplateInstance hello(@QueryParam("name") String name) {
        return hello.data("name", name == null ? "Quarkus" : name);
    }
}
```

`quarkus-rest-qute` renders the returned `TemplateInstance` automatically.

## Type-safe templates with `@CheckedTemplate`

```java
import io.quarkus.qute.CheckedTemplate;
import io.quarkus.qute.TemplateInstance;

@Path("/items")
class ItemResource {
    @CheckedTemplate
    static class Templates {
        static native TemplateInstance page(Item item);
    }

    @GET
    @Path("/{id}")
    TemplateInstance get() {
        return Templates.page(service.find());
    }
}
```

This maps to `src/main/resources/templates/ItemResource/page.html` and turns `Item item` into a checked template parameter.

Top-level `@CheckedTemplate` classes can also declare fragment methods:

```java
@CheckedTemplate
public class Templates {
    public static native TemplateInstance products(List<ProductDto> products);
    public static native TemplateInstance products$row(ProductDto product);
}

// Usage in resource:
return Templates.products(productService.listAll());
```

Type-safe templates validate data bindings at build time -- Quarkus will fail the build if you access a property that does not exist on the data object.

## Type-safe template record

```java
import io.quarkus.qute.TemplateInstance;

record Hello(String name) implements TemplateInstance {
}
```

In a resource class `HelloResource`, this maps to `src/main/resources/templates/HelloResource/Hello.html`.

## Parameter declarations in templates

```html
{@org.acme.Item item}
{@java.util.List<String> tags}

<h1>{item.name}</h1>
<p>{item.price}</p>
```

Expressions rooted at `item` and `tags` are validated at build time.

## Qute syntax reference

```html
{! Comment -- not rendered !}

{! Variable output -- auto HTML-escaped !}
{product.name}

{! Raw (unescaped) output -- SECURITY WARNING: .raw bypasses HTML escaping. !}
{! Never use .raw on user-supplied or untrusted data -- it enables XSS.     !}
{! Only use for content you fully control, such as pre-sanitized HTML.      !}
{product.description.raw}

{! Conditional !}
{#if product.stock > 0}
  <span class="in-stock">In Stock</span>
{#else}
  <span class="out-of-stock">Sold Out</span>
{/if}

{! Loop !}
{#for p in products}
  <tr data-id="{p.id}">
    <td>{p.name}</td>
    <td>{p.price}</td>
  </tr>
{#else}
  <tr><td colspan="2">No products found.</td></tr>
{/for}

{! Loop metadata !}
{#for p in products}
  {#if p_count == 0}first{/if}
  {p_index}: {p.name}   {! 0-based index !}
{/for}

{! Include another template !}
{#include partials/nav.html /}

{! Include with data injection !}
{#include products$row product=p /}

{! Template inheritance -- base.html defines {#insert content/} !}
{#include base.html}
{#content}
  <h1>Products</h1>
{/content}
```

Useful built-ins:

- Elvis/default: `{item.name ?: 'Unknown'}`
- Ternary: `{item.inStock ? 'yes' : 'no'}`
- Current data namespace: `{data:item.name}`
- Raw output: `{htmlSnippet.raw}`

## Base layout pattern

Base template (`templates/base.html`):

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{#insert title}My App{/insert}</title>
  <script src="https://unpkg.com/htmx.org@2"></script>
  <link rel="stylesheet" href="/css/app.css">
</head>
<body>
  {#include partials/nav.html /}
  <main>
    {#insert content /}
  </main>
</body>
</html>
```

Child template (`templates/products.html`):

```html
{#include base.html}

{#title}Products -- My App{/title}

{#content}
<h1>Products</h1>
<div id="product-list">
  {#for p in products}
    {#include products$row product=p /}
  {/for}
</div>
{/content}
```

## Layouts with `include` and `insert`

Base template:

```html
<html>
<head><title>{#insert title}Default title{/}</title></head>
<body>{#insert}No body{/}</body>
</html>
```

Child template:

```html
{#include base}
  {#title}Catalog{/title}
  <main>{item.name}</main>
{/include}
```

## User tags

Tag template `templates/tags/badge.html`:

```html
<span class="badge badge-{kind}">{it}</span>
```

Usage:

```html
{#badge item.status kind='success' /}
```

By default, tags are isolated from the caller context. Pass `_unisolated` only when the tag must see parent data.

## Fragments

Template:

```html
{#fragment item_row}
<tr>
  <td>{item.name}</td>
  <td>{item.price}</td>
</tr>
{/fragment}
```

Java:

```java
String row = itemTemplate.getFragment("item_row")
        .data("item", item)
        .render();
```

Use fragments for partial page updates and reusable subtrees.

## Template extension methods

```java
import io.quarkus.qute.TemplateExtension;

@TemplateExtension
class ItemTemplateExtensions {
    static BigDecimal discountedPrice(Item item) {
        return item.price().multiply(new BigDecimal("0.9"));
    }
}
```

Template use:

```html
{item.discountedPrice}
```

## `@TemplateData` and `@TemplateEnum`

```java
import io.quarkus.qute.TemplateData;
import io.quarkus.qute.TemplateEnum;

@TemplateData
class ItemView {
    public String name;
    public BigDecimal price;
}

@TemplateEnum
enum Status {
    DRAFT,
    PUBLISHED
}
```

Template use:

```html
{item.name}
{#if status == Status:PUBLISHED}Live{/if}
```

These generated resolvers are native-friendly and avoid reflection.

## Inject beans directly in templates

```java
@Named
@ApplicationScoped
class PriceFormatter {
    String currency(BigDecimal value) {
        return "$" + value;
    }
}
```

```html
{inject:priceFormatter.currency(item.price)}
```

`cdi:` and `inject:` expressions are validated at build time.

## Message bundles

```java
import io.quarkus.qute.i18n.Message;
import io.quarkus.qute.i18n.MessageBundle;

@MessageBundle
interface Messages {
    @Message("Hello {name}!")
    String hello(String name);
}
```

Template use:

```html
{msg:hello(user.name)}
```

## Programmatic rendering

```java
String html = report.data("items", items)
        .data("generatedAt", LocalDateTime.now())
        .render();
```

Async options are also available via `renderAsync()`, `createUni()`, and `createMulti()`.

## Engine customization

```java
import io.quarkus.qute.EngineBuilder;

class QuteCustomizer {
    void configure(@Observes EngineBuilder builder) {
        builder.addValueResolver(MyResolver.INSTANCE);
    }
}
```

Use `@EngineConfiguration` for custom resolvers or section helpers that must also participate in build-time validation.

## Configuration

### High-value Quarkus configuration keys

| Property                                         | Default                               | Use when                                                           |
|--------------------------------------------------|---------------------------------------|--------------------------------------------------------------------|
| `quarkus.qute.suffixes`                          | `qute.html,qute.txt,html,txt`         | Template lookup should allow custom suffixes                       |
| `quarkus.qute.content-types.*`                   | URLConnection-based mapping           | Variant/content type detection needs extra suffix mappings         |
| `quarkus.qute.type-check-excludes`               | -                                     | Specific properties or methods must be skipped during validation   |
| `quarkus.qute.template-path-exclude`             | hidden files excluded                 | Some template paths should be ignored entirely                     |
| `quarkus.qute.iteration-metadata-prefix`         | `<alias_>`                            | Loop metadata prefix should change                                 |
| `quarkus.qute.escape-content-types`              | HTML/XML set                          | Auto-escaping should apply to more or fewer content types          |
| `quarkus.qute.default-charset`                   | `UTF-8`                               | Template files use a different default charset                     |
| `quarkus.qute.duplicit-templates-strategy`       | `prioritize`                          | Duplicate template path handling must fail fast                    |
| `quarkus.qute.dev-mode.no-restart-templates`     | -                                     | Some templates should hot-reload without app restart               |
| `quarkus.qute.test-mode.record-rendered-results` | `true`                                | Test render recording should be disabled                           |
| `quarkus.qute.debug.enabled`                     | `true`                                | Experimental Qute debug mode should be turned off                  |
| `quarkus.qute.property-not-found-strategy`       | dev-specific behavior when non-strict | Missing properties should noop, throw, or echo original expression |
| `quarkus.qute.remove-standalone-lines`           | `true`                                | Whitespace around section-only lines must be preserved             |
| `quarkus.qute.strict-rendering`                  | `true`                                | Missing values should fail fast or be tolerated                    |
| `quarkus.qute.timeout`                           | `10000`                               | Global render timeout must change                                  |
| `quarkus.qute.use-async-timeout`                 | `true`                                | Async rendering timeout behavior must change                       |

### Strict vs non-strict rendering

Fail on unresolved expressions:

```properties
quarkus.qute.strict-rendering=true
```

Allow unresolved expressions and control output:

```properties
quarkus.qute.strict-rendering=false
quarkus.qute.property-not-found-strategy=noop
```

`property-not-found-strategy` is ignored when strict rendering is enabled.

### Template lookup and content types

Add a custom suffix and content type mapping:

```properties
quarkus.qute.suffixes=html,txt,email
quarkus.qute.content-types.email=text/plain
```

Useful when one logical template ID should resolve to custom file variants.

### Template validation controls

Skip noisy members during type checks:

```properties
quarkus.qute.type-check-excludes=org.acme.LegacyDto.*,*.class
```

Ignore generated or hidden templates completely:

```properties
quarkus.qute.template-path-exclude=generated/.*|mail/experimental/.*
```

Excluded templates are not parsed, validated, or available at runtime.

### Loop metadata naming

Use no prefix for loop metadata:

```properties
quarkus.qute.iteration-metadata-prefix=<none>
```

Then `{count}` and `{hasNext}` work directly inside loops.

### Escaping and output formatting

Disable standalone-line removal:

```properties
quarkus.qute.remove-standalone-lines=false
```

Extend auto-escaping to JSON templates:

```properties
quarkus.qute.escape-content-types=text/html,text/xml,application/xml,application/xhtml+xml,application/json
```

### Dev mode and test mode

Hot-reload selected templates without full restart:

```properties
quarkus.qute.dev-mode.no-restart-templates=templates/fragments/.*
```

Disable rendered result recording in tests:

```properties
quarkus.qute.test-mode.record-rendered-results=false
```

### Timeout tuning

Increase the render timeout for async or slow data resolution:

```properties
quarkus.qute.timeout=30000
quarkus.qute.use-async-timeout=true
```

Prefer fixing slow or never-completing `Uni`/`CompletionStage` inputs before raising this value.
