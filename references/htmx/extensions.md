# HTMX Extensions

Extensions add capabilities via `hx-ext="name"` on a parent element.
Children inherit extensions.

In HTMX 2.x, extensions are separate packages (`htmx-ext-*`), loaded as
additional script tags.

## Loading Extensions

```html
<script src="https://unpkg.com/htmx.org@2.0.4"></script>
<script src="https://unpkg.com/htmx-ext-response-targets@2.0.2"></script>

<body hx-ext="response-targets">
  {! All children can use response-targets features !}
</body>
```

## Key Extensions

### response-targets

Map different HTTP status codes to different target elements:

```html
<form hx-post="/ui/todos"
      hx-target="#todo-list"
      hx-target-422="#form-errors"
      hx-target-500="#server-error">
```

### json-enc

Send request bodies as JSON instead of form-encoded:

```html
<form hx-post="/api/todos" hx-ext="json-enc">
  <input name="title" value="Learn HTMX">
  {! Sends: {"title": "Learn HTMX"} !}
</form>
```

### head-support

Merge `<head>` elements (title, CSS, meta) from responses. Essential with `hx-boost`:

```html
<body hx-boost="true" hx-ext="head-support">
  <a href="/about">About</a>
  {! Response <head> updates page title, CSS links, etc. !}
</body>
```

### preload

Preload content on hover or mousedown for faster perceived navigation:

```html
<body hx-ext="preload">
  <a href="/page" hx-boost="true" preload="mousedown">Fast Link</a>
  <a href="/other" hx-boost="true" preload>Preload on Hover</a>
</body>
```

### sse (Server-Sent Events)

Real-time updates from server without polling:

```html
<div hx-ext="sse" sse-connect="/events/stream">
  <div sse-swap="message">Waiting for updates...</div>
  <div sse-swap="notification">No notifications</div>
</div>
```

Server sends named events:
```
event: message
data: <div>New message content</div>

event: notification
data: <div>3 new notifications</div>
```

#### Quarkus SSE Endpoint

```java
@Path("/events")
@ApplicationScoped
public class SseResource {

    @Inject EventBus eventBus;
    @Inject Template notification; // templates/notification.html

    @GET
    @Path("/stream")
    @Produces(MediaType.SERVER_SENT_EVENTS)
    @RestStreamElementType(MediaType.TEXT_HTML)
    public Multi<SseEvent<String>> stream() {
        return eventBus.<String>consumer("notifications")
            .bodyStream()
            .map(msg -> SseEvent.<String>builder()
                .name("notification")
                .data(notification.data("message", msg).render())
                .build());
    }
}
```

For simple streaming without named events:

```java
@GET
@Path("/updates")
@Produces(MediaType.SERVER_SENT_EVENTS)
@RestStreamElementType(MediaType.TEXT_HTML)
public Multi<String> updates() {
    return Multi.createFrom().ticks().every(Duration.ofSeconds(5))
        .map(tick -> "<span id=\"clock\">" + LocalTime.now() + "</span>");
}
```

### ws (WebSockets)

Bidirectional communication:

```html
<div hx-ext="ws" ws-connect="/chat">
  <div id="messages"></div>
  <form ws-send>
    <input name="message">
    <button>Send</button>
  </form>
</div>
```

#### Quarkus WebSocket Endpoint

WebSocket endpoints require authentication -- without it, any client can connect
and broadcast to all users. Use a `Configurator` to verify the session cookie
or token during the handshake:

```java
@ServerEndpoint(value = "/chat", configurator = AuthConfigurator.class)
@ApplicationScoped
public class ChatSocket {

    Map<String, Session> sessions = new ConcurrentHashMap<>();

    @OnOpen
    public void onOpen(Session session) {
        sessions.put(session.getId(), session);
    }

    @OnMessage
    public void onMessage(String message, Session session) {
        // Parse htmx ws-send JSON: {"message": "hello", "HEADERS": {...}}
        JsonObject json = Json.createReader(new StringReader(message)).readObject();
        String text = json.getString("message", "");
        // Enforce max message length to prevent abuse
        if (text.length() > 2000) {
            text = text.substring(0, 2000);
        }
        String html = "<div id=\"messages\" hx-swap-oob=\"beforeend\">"
            + "<p>" + htmlEscape(text) + "</p></div>";
        broadcast(html);
    }

    @OnClose
    public void onClose(Session session) {
        sessions.remove(session.getId());
    }

    private void broadcast(String html) {
        sessions.values().forEach(s ->
            s.getAsyncRemote().sendText(html));
    }
}

public class AuthConfigurator extends ServerEndpointConfig.Configurator {
    @Override
    public boolean checkOrigin(String originHeaderValue) {
        // Reject cross-origin WebSocket connections -- replace with your domain
        return "https://yourdomain.com".equals(originHeaderValue);
    }

    @Override
    public void modifyHandshake(ServerEndpointConfig sec,
                                HandshakeRequest request,
                                HandshakeResponse response) {
        // Verify session cookie is present and valid during the HTTP upgrade.
        // Implement isValidSession() to check your auth cookie/token against
        // your session store or security identity provider.
        List<String> cookies = request.getHeaders().get("Cookie");
        if (cookies == null || !isValidSession(cookies)) {
            throw new RuntimeException("Unauthorized WebSocket connection");
        }
    }
}
```

Add the WebSocket dependency:

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-websockets</artifactId>
</dependency>
```

### idiomorph (Morphing)

DOM diffing/merging instead of wholesale replacement. Preserves focus,
scroll position, and transition state:

```html
<body hx-ext="morph">
  <div hx-get="/ui/content" hx-swap="morph:innerHTML">
    {! DOM is merged, not replaced !}
  </div>
</body>
```

Use for complex UIs where preserving DOM state matters (forms mid-edit,
animations, media players).

### loading-states

Automatic loading state management:

```html
<body hx-ext="loading-states">
  <button hx-get="/ui/data"
          data-loading-class="opacity-50"
          data-loading-disable>
    Load Data
  </button>
</body>
```

## Creating Custom Extensions

```javascript
htmx.defineExtension('my-ext', {
  onEvent: function(name, evt) {
    if (name === 'htmx:configRequest') {
      evt.detail.headers['X-Custom'] = 'value';
    }
  }
});
```
