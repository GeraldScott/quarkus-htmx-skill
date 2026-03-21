# Scheduler Reference

Use this module when the task is about scheduled and recurring jobs in Quarkus: `@Scheduled`, cron expressions, programmatic scheduling, and Quartz integration.

## Overview

Quarkus provides a lightweight scheduler built into the core, with an optional Quartz extension for persistent and clustered jobs.

- Use `@Scheduled` for simple periodic or cron-driven methods.
- Use the programmatic `Scheduler` API when jobs must be created, paused, or removed at runtime.
- Use `quarkus-quartz` when jobs must survive restarts, run in clusters, or need persistent state.

## General guidelines

- Keep scheduled methods short; offload heavy work to service beans.
- Use cron expressions for fixed-schedule jobs and `every` for interval-based jobs.
- Mark blocking scheduled methods with `@Blocking` when the scheduler runs on the event loop.
- Use `@Scheduled(concurrentExecution = SKIP)` to prevent overlap when execution can exceed the interval.

---

## Scheduler API

### Extension entry points

Built-in scheduler (no extra dependency needed for basic `@Scheduled`):

```xml
<!-- included transitively by quarkus-core, but add explicitly for Quartz -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-scheduler</artifactId>
</dependency>
```

For persistent or clustered jobs:

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-quartz</artifactId>
</dependency>
```

### `@Scheduled` with interval

```java
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
class PollingService {
    @Scheduled(every = "10s")
    void poll() {
        // runs every 10 seconds
    }
}
```

Supported duration formats: `10s`, `5m`, `1h`, `PT30S` (ISO-8601).

### `@Scheduled` with cron expression

```java
@Scheduled(cron = "0 15 10 * * ?")
void dailyReport() {
    // runs at 10:15 AM every day
}
```

Cron format: `second minute hour day-of-month month day-of-week`.

### Externalize schedule via config

```java
@Scheduled(every = "{polling.interval}", cron = "{report.cron}")
void configurable() {
}
```

```properties
polling.interval=30s
report.cron=0 0 8 * * ?
```

Wrap the config key in `{}` inside the annotation value.

### `@Scheduled` with identity and concurrency control

```java
@Scheduled(
    every = "5s",
    identity = "inventory-sync",
    concurrentExecution = Scheduled.ConcurrentExecution.SKIP
)
void sync() {
}
```

`SKIP` prevents overlapping executions. The `identity` is used for logging, metrics, and programmatic control.

### Access execution metadata

```java
import io.quarkus.scheduler.ScheduledExecution;

@Scheduled(every = "1m")
void withMetadata(ScheduledExecution execution) {
    Instant fireTime = execution.getFireTime();
    Trigger trigger = execution.getTrigger();
}
```

### Programmatic scheduler

```java
import io.quarkus.scheduler.Scheduler;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
class JobManager {
    @Inject
    Scheduler scheduler;

    void pause(String identity) {
        scheduler.pause(identity);
    }

    void resume(String identity) {
        scheduler.resume(identity);
    }

    void pauseAll() {
        scheduler.pause();
    }

    boolean isRunning(String identity) {
        Scheduler.ScheduledJob job = scheduler.getScheduledJob(identity);
        return job != null && job.isRunning();
    }
}
```

### Programmatic job registration

```java
import io.quarkus.scheduler.Scheduler;

scheduler.newJob("dynamic-job")
    .setInterval("5s")
    .setTask(execution -> {
        // job logic
    })
    .schedule();
```

Use this when job definitions come from configuration or user input at runtime.

### Non-blocking scheduled methods

```java
import io.smallrye.mutiny.Uni;

@Scheduled(every = "30s")
Uni<Void> asyncPoll() {
    return client.fetch()
        .onItem().invoke(data -> process(data))
        .replaceWithVoid();
}
```

Methods returning `Uni<Void>` or `CompletionStage<Void>` run on the event loop by default.

---

## Configuration Reference

### High-value properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.scheduler.enabled` | `true` | All scheduled methods should be disabled |
| `quarkus.scheduler.overdue-grace-period` | `1S` | Late triggers should be tolerated for a longer window |
| `quarkus.scheduler.start-mode` | `normal` | Scheduler should start in `halted` or `forced` mode |
| `quarkus.scheduler.tracing.enabled` | `false` | OpenTelemetry tracing should be enabled for scheduled methods |

### Quartz-specific properties

| Property | Default | Use when |
|----------|---------|----------|
| `quarkus.quartz.store-type` | `ram` | Jobs must persist across restarts (`jdbc-cmt` or `jdbc-tx`) |
| `quarkus.quartz.clustered` | `false` | Multiple app instances should coordinate job execution |
| `quarkus.quartz.misfire-policy.*` | smart default | Misfired triggers need explicit handling |
| `quarkus.quartz.thread-count` | `25` | Quartz thread pool size should be tuned |
| `quarkus.quartz.instance-name` | `QuarkusQuartzScheduler` | Cluster instances need distinct names |

### Disable scheduling in tests

```properties
%test.quarkus.scheduler.enabled=false
```

### JDBC job store

```properties
quarkus.quartz.store-type=jdbc-cmt
quarkus.quartz.clustered=true
```

Requires a datasource and Quartz database tables. Use Flyway or manual DDL from the Quartz distribution.

### Overdue grace period

```properties
quarkus.scheduler.overdue-grace-period=30S
```

Triggers that fire within this window after their scheduled time are still executed. Triggers beyond the grace period are skipped.

## See Also

- `../dependency-injection/` - CDI scopes and bean lifecycle for scheduled beans
- `../configuration/` - Externalize cron expressions and intervals via config
