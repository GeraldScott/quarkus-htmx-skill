# Quick-Start Reference

Scaffolding skeletons and minimal configs for new Quarkus + HTMX projects.

## Project creation (CLI)
```bash
quarkus create app com.example:my-app \
  --extension=rest,rest-qute,hibernate-orm-panache,\
              jdbc-postgresql,flyway,smallrye-health
cd my-app && ./mvnw quarkus:dev
```

## Minimum datasource config (application.properties)
```properties
# Dev / test -- DevServices spins up PostgreSQL automatically when Docker is available.
# Production
%prod.quarkus.datasource.db-kind=postgresql
%prod.quarkus.datasource.username=${DB_USER}
%prod.quarkus.datasource.password=${DB_PASSWORD}
%prod.quarkus.datasource.jdbc.url=jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME}
%prod.quarkus.hibernate-orm.database.generation=none
%prod.quarkus.flyway.migrate-at-start=true
```

## REST Resource skeleton (JSON API)
```java
@Path("/api/items")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@ApplicationScoped
public class ItemResource {

    @Inject ItemService itemService;

    @GET
    public List<ItemDto> list() { return itemService.listAll(); }

    @POST @Transactional
    public Response create(@Valid CreateItemRequest req) {
        Item item = itemService.create(req);
        return Response.created(URI.create("/api/items/" + item.id)).build();
    }
}
```

## Qute template resource (for HTMX)
```java
@Path("/ui/items")
@Produces(MediaType.TEXT_HTML)
@ApplicationScoped
public class ItemUiResource {

    @Inject Template items;          // templates/items.html
    @Inject Template items$row;      // templates/items$row.html (fragment)
    @Inject ItemService itemService;

    @GET
    public TemplateInstance page() {
        return items.data("items", itemService.listAll());
    }

    @POST @Transactional
    @Consumes(MediaType.APPLICATION_FORM_URLENCODED)
    public TemplateInstance create(
        @FormParam("name") @NotBlank @Size(max = 255) String name
    ) {
        Item item = itemService.create(name);
        return items$row.data("item", item);
    }
}
```

## HTMX + Qute template snippet
```html
<!-- templates/items.html -->
{#include base.html}
{#content}
<div id="item-list">
  {#for item in items}
    {#include items$row item=item /}
  {/for}
</div>
<form hx-post="/ui/items" hx-target="#item-list" hx-swap="beforeend"
      hx-on::after-request="this.reset()">
  <input name="name" required />
  <button type="submit">Add</button>
</form>
{/content}

<!-- templates/items$row.html -->
<div id="item-{item.id}" class="item">
  <span>{item.name}</span>
  <button hx-delete="/ui/items/{item.id}" hx-target="#item-{item.id}"
          hx-swap="outerHTML" hx-confirm="Delete?">x</button>
</div>
```

## Panache Entity (Active Record)
```java
@Entity @Table(name = "items")
public class Item extends PanacheEntity {
    @Column(nullable = false) public String name;
    @Column(name = "created_at") public Instant createdAt;
    public static List<Item> findByName(String name) { return list("name", name); }
}
```

## Flyway migration
```sql
-- src/main/resources/db/migration/V1__create_items.sql
CREATE TABLE items (
    id         BIGSERIAL PRIMARY KEY,
    name       VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## HTMX attribute cheat sheet

| Attribute | Purpose |
|-----------|---------|
| `hx-get="/path"` | GET on trigger (default: click) |
| `hx-post="/path"` | POST on trigger |
| `hx-put/hx-patch/hx-delete` | Other HTTP methods |
| `hx-target="#id"` | Where to put the response |
| `hx-swap="innerHTML"` | How to swap (innerHTML, outerHTML, beforeend, delete) |
| `hx-trigger="click"` | Event trigger (click, change, submit, keyup delay:500ms) |
| `hx-indicator="#spinner"` | Show/hide during request |
| `hx-push-url="true"` | Push URL to browser history |
| `hx-boost="true"` | Upgrade links and forms to HTMX |
| `hx-confirm="Sure?"` | Confirmation dialog |
| `hx-vals='{"k":"v"}'` | Extra values to submit |
| `hx-headers='{"X-K":"v"}'` | Extra request headers |
| `hx-sync="this:drop"` | Request coordination strategy |
