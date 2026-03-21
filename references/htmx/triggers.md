# Trigger Syntax

## Standard DOM Events

```
click, change, submit, input, keyup, keydown, mouseenter, mouseover, focus, blur
```

Default trigger: `click` for most elements, `change` for inputs, `submit` for forms.

## Special Triggers

- `load` -- fires when element is loaded into DOM
- `revealed` -- fires when element scrolls into viewport (deprecated in 2.x, use `intersect`)
- `intersect` -- IntersectionObserver-based, fires when element enters viewport
- `every <time>` -- polling at interval (e.g., `every 5s`)

## Modifiers

```html
<!-- Debounce: wait for pause in events -->
<input hx-get="/search" hx-trigger="input changed delay:500ms">

<!-- Throttle: limit to one event per interval -->
<div hx-get="/updates" hx-trigger="click throttle:2s">

<!-- Only fire if value changed -->
<input hx-get="/search" hx-trigger="input changed">

<!-- Listen on a different element -->
<div hx-get="/updates" hx-trigger="click from:body">
<div hx-get="/updates" hx-trigger="click from:document">
<div hx-get="/updates" hx-trigger="click from:window">
<div hx-get="/updates" hx-trigger="click from:closest form">

<!-- Filter by event target -->
<div hx-get="/updates" hx-trigger="click target:.btn">

<!-- Consume event (stop propagation) -->
<div hx-get="/action" hx-trigger="click consume">

<!-- Queue strategy for concurrent triggers -->
<div hx-get="/data" hx-trigger="click queue:last">
<!-- queue:first, queue:last, queue:all, queue:none -->

<!-- Fire only once -->
<div hx-get="/init" hx-trigger="load once">
```

## Conditional Filters

JavaScript expressions in brackets gate the trigger:

```html
<div hx-get="/updates" hx-trigger="every 2s [isActive]">
<input hx-get="/validate" hx-trigger="input changed delay:300ms [this.value.length > 2]">
```

## Intersect Options

```html
<!-- Fire when 50% visible -->
<div hx-get="/content" hx-trigger="intersect threshold:0.5">

<!-- Fire relative to a scroll container -->
<div hx-get="/content" hx-trigger="intersect root:.scroll-container threshold:0.1">
```

## Multiple Triggers

Comma-separated, each with own modifiers:

```html
<div hx-get="/news" hx-trigger="load, click delay:1s, every 30s">
```

## Polling

```html
<!-- Basic polling -->
<div hx-get="/status" hx-trigger="every 5s">Status: loading...</div>

<!-- Conditional polling (stops when condition is false) -->
<div hx-get="/status" hx-trigger="every 5s [!isComplete]">

<!-- Server stops polling by returning status 286 -->
```

Always debounce expensive triggers. Prefer SSE over polling for real-time data.
