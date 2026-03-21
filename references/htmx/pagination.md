# HTMX Pagination Patterns

## Overview

HTMX supports multiple pagination strategies, all server-driven. The server renders
the next page of results as an HTML fragment; HTMX swaps it into the DOM. No
client-side state management needed.

## Strategy Comparison

| Strategy | Trigger | Best for | History |
|----------|---------|----------|---------|
| Infinite scroll | `hx-trigger="revealed"` | Feeds, timelines, logs | Usually no |
| Click to load more | `hx-trigger="click"` | Product lists, search results | Optional |
| Page numbers | `hx-trigger="click"` | Tables, admin panels | Yes (`hx-push-url`) |
| Cursor-based | Server cursor in next-page URL | Large datasets, real-time feeds | Optional |

## Infinite Scroll

The last element in each page contains the trigger to load the next page. When it
scrolls into view, HTMX fetches the next batch and appends it.

### Qute template

```html
{! templates/products$list.html -- rendered for each page !}
{#for product in products}
<div class="product-card" {#if product_isLast && hasMore}
     hx-get="/ui/products?cursor={product.id}"
     hx-trigger="revealed"
     hx-swap="afterend"
     hx-indicator="#load-spinner"{/if}>
    <h3>{product.name}</h3>
    <p>{product.price}</p>
</div>
{/for}
```

### Quarkus endpoint

```java
@Path("/ui/products")
@Produces(MediaType.TEXT_HTML)
@ApplicationScoped
public class ProductUiResource {

    @Inject Template products;           // full page
    @Inject Template products$list;      // fragment for infinite scroll
    @Inject ProductRepository repo;

    private static final int PAGE_SIZE = 20;

    @GET
    public TemplateInstance list(
        @HeaderParam("HX-Request") String hxRequest,
        @QueryParam("cursor") Long cursor
    ) {
        List<Product> items = cursor != null
            ? repo.findAfterId(cursor, PAGE_SIZE + 1)
            : repo.findFirst(PAGE_SIZE + 1);

        boolean hasMore = items.size() > PAGE_SIZE;
        if (hasMore) items = items.subList(0, PAGE_SIZE);

        if ("true".equals(hxRequest)) {
            return products$list
                .data("products", items)
                .data("hasMore", hasMore);
        }
        return products
            .data("products", items)
            .data("hasMore", hasMore);
    }
}
```

### Panache repository query

```java
@ApplicationScoped
public class ProductRepository implements PanacheRepository<Product> {

    public List<Product> findFirst(int limit) {
        return find("ORDER BY id").page(0, limit).list();
    }

    public List<Product> findAfterId(Long cursor, int limit) {
        return find("id > ?1 ORDER BY id", cursor)
            .page(0, limit).list();
    }
}
```

## Click to Load More

A button replaces itself with the next page of results:

```html
{! templates/products$list.html !}
{#for product in products}
<div class="product-card">
    <h3>{product.name}</h3>
    <p>{product.price}</p>
</div>
{/for}
{#if hasMore}
<button hx-get="/ui/products?cursor={lastId}"
        hx-target="this"
        hx-swap="outerHTML"
        hx-indicator="#load-spinner"
        class="load-more-btn">
    Load more
</button>
{/if}
```

The button swaps itself with `outerHTML` -- the next batch of items plus a new
"Load more" button (if there are still more results) replaces it.

## Page Number Navigation

Traditional numbered pagination with browser history support:

### Template

```html
{! templates/products.html -- full page !}
{#include base.html}
{#content}
<div id="product-table">
    {#include products$table /}
</div>
{/content}

{! templates/products$table.html -- fragment !}
<table>
    <thead>
        <tr><th>Name</th><th>Price</th></tr>
    </thead>
    <tbody>
        {#for product in products}
        <tr><td>{product.name}</td><td>{product.price}</td></tr>
        {/for}
    </tbody>
</table>
<nav aria-label="Page navigation">
    {#if page > 1}
    <a hx-get="/ui/products?page={page - 1}"
       hx-target="#product-table"
       hx-push-url="true"
       aria-label="Previous page">Previous</a>
    {/if}

    {#for p in pages}
    <a hx-get="/ui/products?page={p}"
       hx-target="#product-table"
       hx-push-url="true"
       class="{#if p == page}active{/if}"
       aria-label="Page {p}"
       {#if p == page}aria-current="page"{/if}>{p}</a>
    {/for}

    {#if page < totalPages}
    <a hx-get="/ui/products?page={page + 1}"
       hx-target="#product-table"
       hx-push-url="true"
       aria-label="Next page">Next</a>
    {/if}
</nav>
```

### Endpoint

```java
@GET
public TemplateInstance list(
    @HeaderParam("HX-Request") String hxRequest,
    @QueryParam("page") @DefaultValue("1") int page
) {
    int pageSize = 20;
    long total = Product.count();
    int totalPages = (int) Math.ceil((double) total / pageSize);
    List<Product> items = Product.findAll()
        .page(page - 1, pageSize).list();

    // Generate page number list (e.g., 1..totalPages, capped at 10)
    List<Integer> pages = IntStream.rangeClosed(
            Math.max(1, page - 4), Math.min(totalPages, page + 5))
        .boxed().toList();

    TemplateInstance template = "true".equals(hxRequest)
        ? products$table : products;

    return template
        .data("products", items)
        .data("page", page)
        .data("totalPages", totalPages)
        .data("pages", pages);
}
```

## Cursor-Based Pagination (Keyset)

More efficient than offset for large datasets. Uses the last item's sort key
as the cursor instead of an offset:

```java
@GET
public TemplateInstance list(
    @HeaderParam("HX-Request") String hxRequest,
    @QueryParam("after") String afterCursor,
    @QueryParam("size") @DefaultValue("20") int size
) {
    List<Product> items;
    if (afterCursor != null) {
        items = Product.find("name > ?1 ORDER BY name", afterCursor)
            .page(0, size + 1).list();
    } else {
        items = Product.find("ORDER BY name")
            .page(0, size + 1).list();
    }

    boolean hasMore = items.size() > size;
    if (hasMore) items = items.subList(0, size);

    String nextCursor = hasMore ? items.get(items.size() - 1).name : null;

    TemplateInstance template = "true".equals(hxRequest)
        ? products$list : products;

    return template
        .data("products", items)
        .data("hasMore", hasMore)
        .data("nextCursor", nextCursor);
}
```

## Filtered Pagination with Search

Combine search input with paginated results:

```html
<input type="search" name="q"
       hx-get="/ui/products"
       hx-trigger="input changed delay:300ms, search"
       hx-target="#product-list"
       hx-push-url="true"
       hx-indicator="#search-spinner"
       placeholder="Search products..."
       aria-label="Search products" />

<div id="product-list">
    {#include products$list /}
</div>
```

```java
@GET
public TemplateInstance list(
    @HeaderParam("HX-Request") String hxRequest,
    @QueryParam("q") @DefaultValue("") String query,
    @QueryParam("cursor") Long cursor
) {
    List<Product> items;
    if (query.isBlank()) {
        items = cursor != null
            ? repo.findAfterId(cursor, PAGE_SIZE + 1)
            : repo.findFirst(PAGE_SIZE + 1);
    } else {
        items = cursor != null
            ? repo.searchAfterId(query, cursor, PAGE_SIZE + 1)
            : repo.search(query, PAGE_SIZE + 1);
    }

    boolean hasMore = items.size() > PAGE_SIZE;
    if (hasMore) items = items.subList(0, PAGE_SIZE);

    // ... return template with data
}
```

## Loading Indicators

Always show a loading indicator during pagination requests:

```html
<img id="load-spinner"
     class="htmx-indicator"
     src="/static/spinner.svg"
     alt="Loading..."
     aria-hidden="true" />
```

The `htmx-indicator` class is shown when any element referencing `#load-spinner`
via `hx-indicator` has an active request.

## Testing Pagination

```java
@QuarkusTest
class ProductPaginationTest {

    @Test
    void firstPage_rendersProductsAndNextLink() {
        given()
            .header("HX-Request", "true")
        .when()
            .get("/ui/products")
        .then()
            .statusCode(200)
            .body(containsString("product-card"))
            .body(containsString("hx-trigger=\"revealed\""));
    }

    @Test
    void cursorPagination_returnsNextBatch() {
        given()
            .header("HX-Request", "true")
            .queryParam("cursor", 20)
        .when()
            .get("/ui/products")
        .then()
            .statusCode(200)
            .body(containsString("product-card"));
    }

    @Test
    void lastPage_omitsNextTrigger() {
        given()
            .header("HX-Request", "true")
            .queryParam("cursor", 999)
        .when()
            .get("/ui/products")
        .then()
            .statusCode(200)
            .body(not(containsString("hx-trigger=\"revealed\"")));
    }
}
```
