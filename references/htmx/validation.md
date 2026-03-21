# Validation Patterns

## Server-Side Validation (Primary)

On validation error:

1. Return HTTP 422 status code
2. Return same form fragment with error messages
3. Preserve user input in form fields
4. Do NOT redirect on validation failure

### Bean Validation with Quarkus

```java
@Path("/ui/todos")
@ApplicationScoped
public class TodoResource {

    @Inject Template todos$form;
    @Inject Template todos$item;
    @Inject TodoService todoService;

    @POST
    @Consumes(MediaType.APPLICATION_FORM_URLENCODED)
    @Produces(MediaType.TEXT_HTML)
    @Transactional
    public Response create(
        @FormParam("title") @NotBlank @Size(min = 3, max = 255) String title,
        @FormParam("description") @Size(max = 2000) String description
    ) {
        TodoDto todo = todoService.create(title, description);
        return Response.ok(todos$item.data("item", todo).render()).build();
    }
}
```

### Exception Mapper for Validation Errors

Map `ConstraintViolationException` to a 422 response with re-rendered form:

```java
@Provider
public class ValidationExceptionMapper
    implements ExceptionMapper<ConstraintViolationException> {

    @Inject Template todos$form;

    @Override
    public Response toResponse(ConstraintViolationException ex) {
        List<String> errors = ex.getConstraintViolations().stream()
            .map(v -> v.getPropertyPath() + ": " + v.getMessage())
            .toList();

        // Re-render the form fragment with errors
        String html = todos$form
            .data("errors", errors)
            .data("values", Map.of()) // preserve input if available
            .render();

        return Response.status(422)
            .type(MediaType.TEXT_HTML)
            .entity(html)
            .build();
    }
}
```

### Generic HTMX-Aware Validation Mapper

For reusable validation across multiple resources:

```java
@Provider
public class HtmxValidationMapper
    implements ExceptionMapper<ConstraintViolationException> {

    @Override
    public Response toResponse(ConstraintViolationException ex) {
        List<String> errors = ex.getConstraintViolations().stream()
            .map(ConstraintViolation::getMessage)
            .toList();

        String errorHtml = errors.stream()
            .map(e -> "<p class=\"error\">" + e + "</p>")
            .collect(Collectors.joining());

        return Response.status(422)
            .type(MediaType.TEXT_HTML)
            .entity("<div class=\"errors\" role=\"alert\">" + errorHtml + "</div>")
            .build();
    }
}
```

### Qute Template for Form with Errors

```html
{! todos$form.html !}
<form hx-post="/ui/todos" hx-target="#todo-list" hx-swap="beforeend">
  <div>
    <label for="title">Title</label>
    <input type="text" name="title" id="title"
           value="{values.title ?: ''}"
           required minlength="3" maxlength="255">
  </div>

  {#if errors != null && errors.size > 0}
    <div class="errors" role="alert">
      {#for error in errors}
        <p class="error">{error}</p>
      {/for}
    </div>
  {/if}

  <button type="submit">Add</button>
</form>
```

### DTO-Based Validation

For complex forms, use a validated DTO:

```java
public record CreateTodoRequest(
    @NotBlank @Size(min = 3, max = 255) String title,
    @Size(max = 2000) String description,
    @NotNull @FutureOrPresent LocalDate dueDate
) {}

@POST
@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
@Produces(MediaType.TEXT_HTML)
@Transactional
public Response create(@Valid @BeanParam CreateTodoRequest req) {
    TodoDto todo = todoService.create(req);
    return Response.ok(todos$item.data("item", todo).render()).build();
}
```

## Client-Side Validation (hx-validate)

`hx-validate="true"` triggers HTML5 form validation before the HTMX request:

```html
<form hx-post="/ui/todos" hx-validate="true">
  <input type="text" name="title" required minlength="3">
  <input type="email" name="email" required>
  <button type="submit">Submit</button>
</form>
```

## Inline Field Validation

Validate individual fields as the user types by hitting a Quarkus endpoint:

```html
<input type="email" name="email"
       hx-get="/ui/validate/email"
       hx-trigger="change delay:500ms"
       hx-target="next .field-error"
       hx-swap="innerHTML"
       hx-vals='js:{"email": this.value}'>
<span class="field-error"></span>
```

```java
@Path("/ui/validate")
@ApplicationScoped
public class ValidationResource {

    @GET
    @Path("/email")
    @Produces(MediaType.TEXT_HTML)
    public Response validateEmail(@QueryParam("email") String email) {
        if (email == null || !email.matches("^[\\w.+%-]+@[\\w.-]+\\.[a-zA-Z]{2,}$")) {
            return Response.ok("<span class=\"error\">Invalid email address</span>")
                .build();
        }
        if (userService.emailExists(email)) {
            return Response.ok("<span class=\"error\">Email already registered</span>")
                .build();
        }
        return Response.ok("<span class=\"valid\">Email available</span>").build();
    }
}
```

## Validation Events

```javascript
// Custom validation logic before request
document.body.addEventListener('htmx:validation:validate', function(evt) {
  const elt = evt.detail.elt;
  if (elt.name === 'username' && elt.value.includes(' ')) {
    evt.detail.valid = false;
    elt.setCustomValidity('No spaces allowed');
  }
});

// React to validation failure
document.body.addEventListener('htmx:validation:halted', function(evt) {
  // Validation prevented the request
});
```

## Error Retargeting

Use `HX-Retarget` header to send errors to a different element:

```java
@POST
@Consumes(MediaType.APPLICATION_FORM_URLENCODED)
@Produces(MediaType.TEXT_HTML)
@Transactional
public Response create(@FormParam("title") String title) {
    if (title == null || title.isBlank()) {
        return Response.status(422)
            .header("HX-Retarget", "#form-errors")
            .header("HX-Reswap", "innerHTML")
            .entity("<p class=\"error\">Title is required</p>")
            .build();
    }
    TodoDto todo = todoService.create(title);
    return Response.ok(todos$item.data("item", todo).render()).build();
}
```
