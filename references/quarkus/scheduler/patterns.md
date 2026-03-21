# Quarkus Scheduler Usage Patterns

Use these patterns for repeatable scheduling workflows.

## Pattern: Periodic background job

When to use:

- A task should run at a fixed interval without external triggers.

Example:

```java
@ApplicationScoped
class CacheRefresher {
    @Scheduled(every = "5m", identity = "cache-refresh")
    void refresh() {
        cache.invalidateAll();
        cache.warmUp();
    }
}
```

## Pattern: Cron-driven report generation

When to use:

- A job should run at a specific time of day or on specific days.

Example:

```java
@ApplicationScoped
class DailyReportJob {
    @Scheduled(cron = "0 0 6 * * ?", identity = "daily-report")
    void generate() {
        reportService.generateAndSend();
    }
}
```

## Pattern: Externalize schedule from code

When to use:

- The schedule should be configurable per environment without code changes.

Example:

```java
@Scheduled(every = "{sync.interval}", identity = "data-sync")
void sync() {
    syncService.run();
}
```

```properties
sync.interval=30s
%dev.sync.interval=5s
%prod.sync.interval=2m
```

## Pattern: Prevent overlapping executions

When to use:

- A job can take longer than its interval and must not run concurrently with itself.

Example:

```java
@Scheduled(
    every = "10s",
    identity = "slow-import",
    concurrentExecution = Scheduled.ConcurrentExecution.SKIP
)
void importData() {
    // if still running from the previous trigger, this invocation is skipped
}
```

## Pattern: Pause and resume jobs at runtime

When to use:

- An admin endpoint or feature flag should control whether a job runs.

Example:

```java
@Path("/admin/jobs")
@ApplicationScoped
class JobAdminResource {
    @Inject
    Scheduler scheduler;

    @POST
    @Path("/{id}/pause")
    void pause(@RestPath String id) {
        scheduler.pause(id);
    }

    @POST
    @Path("/{id}/resume")
    void resume(@RestPath String id) {
        scheduler.resume(id);
    }
}
```

Use the `identity` value from `@Scheduled` as the job ID.

## Pattern: Disable scheduling in tests

When to use:

- Scheduled jobs interfere with test execution or timing.

```properties
%test.quarkus.scheduler.enabled=false
```

Test the job logic directly by calling the method or injecting the service bean.
