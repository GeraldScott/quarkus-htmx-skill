# Quarkus Scheduler Gotchas

Common scheduling pitfalls, symptoms, and fixes.

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Scheduled method never runs | Bean is missing `@ApplicationScoped` or another bean-defining scope | Add a scope annotation to the class |
| Scheduled method runs in dev mode but not in production | `quarkus.scheduler.enabled` is `false` or the bean was removed as unused | Verify the property and check ArC bean removal settings |
| Job overlaps cause duplicate processing | `concurrentExecution` defaults to `PROCEED` (allow overlap) | Set `concurrentExecution = Scheduled.ConcurrentExecution.SKIP` |
| Cron job fires at wrong time | Cron expression uses wrong timezone or field order | Quarkus cron uses `second minute hour day month weekday`; set `quarkus.scheduler.cron-timezone` if needed |
| Config expression `{key}` is not resolved | Config key is missing or `{}` was used instead of `${}` | Use `{}` (not `${}`) inside `@Scheduled` and ensure the property exists |
| Event-loop blocked warning from scheduled method | Blocking I/O runs on a non-blocking scheduler thread | Add `@Blocking` or return `Uni<Void>` for async work |
| Quartz JDBC store fails at startup | Quartz tables are missing from the database | Create tables using DDL scripts from the Quartz distribution or add them via Flyway |
| Scheduled tests are flaky due to timing | Jobs fire during test setup or between assertions | Disable the scheduler in tests and invoke job methods directly |
| Scheduled job accesses sensitive resources without authorization | Jobs run as the system, not as a user | If a scheduled job calls protected services, ensure it uses an appropriate service account or bypasses security intentionally with documentation |
| Programmatic job creation is exposed to untrusted input | `scheduler.newJob()` allows arbitrary intervals and task logic | Never let user input control job scheduling parameters (interval, cron expression) without strict validation |
