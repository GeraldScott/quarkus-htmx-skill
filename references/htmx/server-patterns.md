# Server Response Patterns

## HX-Request Detection

Every HTMX request sends `HX-Request: true`. Use it to return fragments vs full pages:

```java
@Path("/todos")
@ApplicationScoped
public class TodoResource {

    @Inject Template todos;        // templates/todos.html (full page)
    @Inject Template todos$list;   // templates/todos$list.html (fragment)

    @GET
    @Produces(MediaType.TEXT_HTML)
    public TemplateInstance list(
        @HeaderParam("HX-Request") String hxRequest
    ) {
        List<TodoDto> items = todoService.listAll();
        if ("true".equals(hxRequest)) {
            return todos$list.data("items", items);
        }
        return todos.data("items", items);
    }
}
```

## HTTP Status Codes

| Code | Meaning for HTMX |
|------|-------------------|
| 200 | Success, swap response content |
| 204 | No Content -- no swap occurs |
| 422 | Validation error -- swap error fragment (form with errors) |
| 286 | Stop polling -- htmx-specific, stops `every` triggers |
| 4xx/5xx | Error -- triggers `htmx:responseError` event |

## Context-Aware Responses

Use request headers for smarter responses:

```java
@GET
@Path("/content")
@Produces(MediaType.TEXT_HTML)
public TemplateInstance content(
    @HeaderParam("HX-Target") String hxTarget,
    @HeaderParam("HX-Current-URL") String currentUrl,
    @HeaderParam("HX-Boosted") String hxBoosted
) {
    if ("sidebar".equals(hxTarget)) {
        return sidebar.data("data", sidebarData);
    }
    return content.data("data", contentData);
}
```

## Fragment Architecture

Qute uses `$` in injection names to map to template files:

```
templates/
  base.html                  # Base layout with {#insert content/}
  todos.html                 # Full page (includes base.html)
  todos$list.html            # List fragment (injected as todos$list)
  todos$item.html            # Single item fragment
  todos$form.html            # Form (returned on 422 with errors)
  todos$item$edit.html       # Edit mode for a single item
  partials/
    nav.html                 # Shared navigation partial
    flash.html               # Flash notification (OOB)
    error.html               # Error message fragment
```

Injection convention:

```java
@Inject Template todos;            // -> templates/todos.html
@Inject Template todos$list;       // -> templates/todos$list.html
@Inject Template todos$item;       // -> templates/todos$item.html
@Inject Template todos$form;       // -> templates/todos$form.html
```

Type-safe alternative with @CheckedTemplate:

```java
@CheckedTemplate
public class Templates {
    public static native TemplateInstance todos(List<TodoDto> items);
    public static native TemplateInstance todos$list(List<TodoDto> items);
    public static native TemplateInstance todos$item(TodoDto item);
    public static native TemplateInstance todos$form(TodoDto values, List<String> errors);
}
```

Fragments should be reusable, isolated, and self-contained.
Never return a full HTML layout for an HTMX request unless intentional.

## Server-Side OOB Pattern

Return multiple fragments in one response using a Qute template that includes OOB elements:

```java
@POST
@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
@Produces(MediaType.TEXT_HTML)
@Transactional
public TemplateInstance create(
    @FormParam("title") String title
) {
    TodoDto todo = todoService.create(title);
    int count = todoService.count();
    // Template includes primary content + OOB span
    return todos$item.data("item", todo).data("count", count);
}
```

```html
{! todos$item.html -- primary response + OOB update !}
<li id="todo-{item.id}">
  {item.title}
</li>
<span id="todo-count" hx-swap-oob="true">{count}</span>
```

Alternatively, build the response manually for more control:

```java
@POST
@Produces(MediaType.TEXT_HTML)
@Transactional
public String create(@FormParam("title") String title) {
    TodoDto todo = todoService.create(title);
    String itemHtml = todos$item.data("item", todo).render();
    String countHtml = "<span id=\"todo-count\" hx-swap-oob=\"true\">"
        + todoService.count() + "</span>";
    return itemHtml + countHtml;
}
```

## Server-Driven Events

Use HX-Trigger header to fire client-side events:

```java
@POST
@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
@Produces(MediaType.TEXT_HTML)
@Transactional
public Response create(@FormParam("title") String title) {
    TodoDto todo = todoService.create(title);
    String triggerJson = Json.createObjectBuilder()
        .add("todoAdded", Json.createObjectBuilder()
            .add("id", todo.id())
            .add("title", todo.title()))
        .build().toString();

    return Response.ok(todos$item.data("item", todo).render())
        .header("HX-Trigger", triggerJson)
        .build();
}
```

Listen on the client:

```html
<body hx-on:todo-added="console.log('Todo added:', event.detail)">
```

## SSE with RESTEasy Reactive

Stream real-time updates using Server-Sent Events:

```java
@Path("/events")
@ApplicationScoped
public class EventResource {

    @Inject EventBus eventBus;
    @Inject Template notification; // templates/notification.html

    @GET
    @Path("/stream")
    @Produces(MediaType.SERVER_SENT_EVENTS)
    @RestStreamElementType(MediaType.TEXT_HTML)
    public Multi<String> stream() {
        return eventBus.<String>consumer("updates")
            .bodyStream()
            .map(msg -> notification.data("message", msg).render());
    }
}
```

```html
{! templates/notification.html -- Qute auto-escapes {message}, preventing XSS !}
<div class="notification">{message}</div>
```

```html
<div hx-ext="sse"
     sse-connect="/events/stream"
     sse-swap="message"
     hx-target="#notifications"
     hx-swap="beforeend">
</div>
```

## Response Helpers

```java
// Redirect after POST (Post/Redirect/Get pattern)
return Response.seeOther(URI.create("/ui/todos")).build();

// Trigger HTMX events from the server
return Response.ok(fragment.render())
    .header("HX-Trigger", "itemAdded")
    .header("HX-Redirect", "/ui/items")
    .build();

// Useful HX-* response headers:
// HX-Trigger       -- fire a client-side event
// HX-Redirect      -- redirect (full page)
// HX-Push-Url      -- update browser URL without redirect
// HX-Reswap        -- override the hx-swap on the request
// HX-Retarget      -- override the hx-target on the request
// HX-Refresh       -- force a full page reload (true)
```
