# Quarkus Anti-Patterns Reference

Hard-won lessons from production migrations, failed experiments, and the collective scar tissue of the Quarkus community. This is not a "best practices" list — it is a catalogue of things that will hurt you, organised by how badly they hurt.

---

## 1. Spring Boot Brain Damage

The single most common source of Quarkus anti-patterns is carrying Spring Boot habits into a fundamentally different runtime. Quarkus is not "Spring but faster." It is a build-time-oriented, CDI-based, GraalVM-native-first framework. Treating it like Spring will produce code that is slower, more fragile, and harder to maintain than the Spring Boot app you left behind.

### 1.1 Using Spring DI Annotations Everywhere

**Anti-pattern:** Sprinkling `@Autowired`, `@Component`, `@Service`, `@Repository` throughout your codebase because "Quarkus supports Spring compatibility."

**Why it hurts:** Quarkus provides Spring compatibility extensions as a migration bridge, not as a target architecture. These annotations are translated to CDI equivalents at build time, adding an unnecessary layer of indirection. You lose access to CDI-specific features (qualifiers, interceptors, decorators, `@Observes`, Arc-specific extensions) and your team never learns the actual framework they are running on.

**What to do instead:**
```java
// WRONG: Spring muscle memory
@Service
public class OrderService {
    @Autowired
    private OrderRepository repo;
}

// RIGHT: Native Quarkus CDI
@ApplicationScoped
public class OrderService {
    private final OrderRepository repo;

    // @Inject is optional with a single constructor
    public OrderService(OrderRepository repo) {
        this.repo = repo;
    }
}
```

Remove the `quarkus-spring-di`, `quarkus-spring-data-jpa`, and `quarkus-spring-web` extensions as soon as migration is complete. They are training wheels, not load-bearing walls.

### 1.2 Runtime Reflection as a Design Strategy

**Anti-pattern:** Using reflection-heavy libraries, custom `Class.forName()` lookups, runtime annotation scanning, or frameworks that rely on dynamic proxies — then fighting GraalVM when nothing works in native mode.

**Why it hurts:** Quarkus performs as much work as possible at build time. GraalVM native images use a closed-world assumption — if the compiler cannot prove that a code path is reachable through static analysis, it is eliminated. Every reflection call is a hole in that analysis. You end up maintaining `reflect-config.json` files, scattering `@RegisterForReflection` annotations, and debugging opaque native image failures.

**What to do instead:**
- Use CDI producers and qualifiers instead of service locator patterns.
- Use MapStruct with `componentModel = "cdi"` and `@Inject` — never `Mappers.getMapper()`.
- Use Panache instead of hand-rolled generic DAO patterns that rely on `Class<T>` reflection.
- If you must register classes for reflection, prefer `@RegisterForReflection(targets = {Foo.class, Bar.class})` on a dedicated config class rather than scattering it across the codebase.

### 1.3 Spring Data Repository Interfaces Instead of Panache

**Anti-pattern:** Using `quarkus-spring-data-jpa` to get Spring Data-style repository interfaces because "that is what we know."

**Why it hurts:** The Spring Data compatibility layer is a subset of the real thing. You get limited query derivation, no Specifications, no QueryDSL, and no `@Query` with SpEL. Meanwhile, Panache provides a simpler, more Quarkus-native approach with active record or repository patterns that work seamlessly with native compilation.

**What to do instead:**
```java
// WRONG: Spring Data comfort blanket
public interface OrderRepository extends CrudRepository<Order, Long> {
    List<Order> findByStatusAndCreatedAfter(Status s, LocalDateTime d);
}

// RIGHT: Panache repository
@ApplicationScoped
public class OrderRepository implements PanacheRepository<Order> {
    public List<Order> findByStatusAfter(Status s, LocalDateTime d) {
        return find("status = ?1 and created > ?2", s, d).list();
    }
}

// OR: Active record pattern (even simpler)
@Entity
public class Order extends PanacheEntity {
    public Status status;
    public LocalDateTime created;

    public static List<Order> findByStatusAfter(Status s, LocalDateTime d) {
        return find("status = ?1 and created > ?2", s, d).list();
    }
}
```

### 1.4 Spring-Style Configuration Classes

**Anti-pattern:** Creating `@Configuration` classes with `@Bean` methods to wire up infrastructure, or using `@Value("${some.prop}")` for configuration injection.

**Why it hurts:** Quarkus uses MicroProfile Config / SmallRye Config. The Spring configuration model is supported for compatibility, but it does not give you: config profiles (`%dev.`, `%test.`, `%prod.`), `@ConfigMapping` with type safety and validation, build-time config vs. runtime config distinction, or Dev Services auto-configuration.

**What to do instead:**
```java
// WRONG: Spring @Value
@ApplicationScoped
public class MailService {
    @Value("${mail.host}")
    String host;
}

// RIGHT: MicroProfile Config
@ApplicationScoped
public class MailService {
    @ConfigProperty(name = "mail.host")
    String host;
}

// BEST: Type-safe config mapping with validation
@ConfigMapping(prefix = "mail")
public interface MailConfig {
    @WithDefault("localhost")
    String host();

    @Min(1) @Max(65535)
    int port();

    Optional<String> username();
}
```

### 1.5 Fat Starter Dependencies

**Anti-pattern:** Adding `spring-boot-starter-*` equivalents or pulling in massive transitive dependency trees because "we might need it."

**Why it hurts:** Quarkus extensions are curated and aligned to a platform BOM. They are tested together. Random third-party JARs — especially those designed for Spring Boot auto-configuration — can introduce classloading conflicts, break native compilation, and bloat your image. Every unnecessary dependency is a native image compilation risk.

**What to do instead:**
- Only add Quarkus extensions from the platform BOM.
- Check `quarkus extension list` before reaching for a third-party library.
- If a library is not available as a Quarkus extension, assess its native compatibility before adopting it.

---

## 2. CDI Scope Misuse

### 2.1 @ApplicationScoped vs @Singleton Confusion

**Anti-pattern:** Using `@ApplicationScoped` and `@Singleton` interchangeably without understanding proxy behaviour.

**Why it hurts:**
- `@ApplicationScoped` creates a client proxy. The bean is instantiated lazily on first method call. The proxy can be serialised and supports interceptors/decorators naturally. It requires a no-arg constructor (or Quarkus must transform the class).
- `@Singleton` is a pseudo-scope. No proxy. The bean is created eagerly when first injected. No no-arg constructor requirement. But it cannot be intercepted through normal-scoped interception, and circular dependencies will fail.

**What to do instead:** Default to `@ApplicationScoped`. Use `@Singleton` only when you explicitly need eager instantiation or cannot provide a no-arg constructor and understand the trade-offs.

### 2.2 Stateful @ApplicationScoped Beans Without Thread Safety

**Anti-pattern:** Storing mutable state in `@ApplicationScoped` beans without synchronisation.

**Why it hurts:** CDI provides zero concurrency guarantees. An `@ApplicationScoped` bean is shared across all threads. If you mutate fields without synchronisation, you get data races. This is especially insidious because it works in dev mode (single-threaded tests) and explodes under production load.

**What to do instead:**
```java
// WRONG: Mutable state, no protection
@ApplicationScoped
public class Counter {
    private int count = 0;
    public void increment() { count++; }
}

// RIGHT: Use Quarkus @Lock
@ApplicationScoped
@Lock
public class Counter {
    private int count = 0;
    public void increment() { count++; }

    @Lock(value = Lock.Type.READ)
    public int getCount() { return count; }
}
```

Or better: don't put mutable state in shared beans at all. Use `@RequestScoped` for per-request state, or use concurrent data structures.

### 2.3 Missing Bean Defining Annotations

**Anti-pattern:** Writing a class and expecting CDI to discover it without a scope annotation.

**Why it hurts:** Quarkus uses `annotated` bean discovery mode exclusively. No `beans.xml` scanning. No package scanning. If your class does not have a bean defining annotation (`@ApplicationScoped`, `@RequestScoped`, `@Dependent`, `@Singleton`, etc.), it does not exist to CDI. You get confusing "unsatisfied dependency" errors.

### 2.4 Abusing CDI.current()

**Anti-pattern:** Calling `CDI.current().select(MyBean.class).get()` to programmatically look up beans.

**Why it hurts:** This is a service locator pattern. It hides dependencies, breaks static analysis (Quarkus cannot detect the usage at build time), and fails in native images unless you register the bean for reflection. It also makes testing harder.

**What to do instead:** Use `@Inject Instance<MyBean>` for dynamic/optional lookups:
```java
@ApplicationScoped
public class ProcessorRouter {
    @Inject
    @Any
    Instance<PaymentProcessor> processors;

    public PaymentProcessor getProcessor(PaymentMethod method) {
        return processors.stream()
            .filter(p -> p.supports(method))
            .findFirst()
            .orElseThrow();
    }
}
```

---

## 3. Reactive & Event Loop Sins

### 3.1 Blocking the Event Loop

**Anti-pattern:** Making JDBC calls, calling `Thread.sleep()`, doing synchronous file I/O, or calling `.await()` on a Uni inside a reactive endpoint.

**Why it hurts:** Quarkus runs on Vert.x. A small number of event loop threads (typically one per CPU core) handle all I/O. Block one, and you block thousands of concurrent requests. Vert.x will warn you: `Thread Thread[vert.x-eventloop-thread-0] has been blocked for 253 ms`. This warning is never a false positive — it is always a bug.

**What to do instead:**
```java
// WRONG: Blocking call on event loop
@GET
@Path("/orders")
public Uni<List<Order>> getOrders() {
    List<Order> orders = jdbc.query("SELECT * FROM orders"); // BLOCKS
    return Uni.createFrom().item(orders);
}

// RIGHT: Option A — use @Blocking annotation
@GET
@Path("/orders")
@Blocking
public List<Order> getOrders() {
    return Order.listAll(); // runs on worker thread
}

// RIGHT: Option B — use reactive all the way down
@GET
@Path("/orders")
public Uni<List<Order>> getOrders() {
    return Order.listAll(); // Panache Reactive, non-blocking
}

// RIGHT: Option C — virtual threads (Quarkus 3.x+)
@GET
@Path("/orders")
@RunOnVirtualThread
public List<Order> getOrders() {
    return Order.listAll(); // blocking but on virtual thread
}
```

### 3.2 Mixing Blocking and Reactive Hibernate in the Same Entity

**Anti-pattern:** Using `io.quarkus:quarkus-hibernate-orm-panache` and `io.quarkus:quarkus-hibernate-reactive-panache` on the same entity, or mixing `@Transactional` with reactive endpoints.

**Why it hurts:** Blocking Hibernate ORM and Hibernate Reactive are fundamentally different session models. They cannot share a persistence unit. `@Transactional` starts a blocking JTA transaction — using it on a reactive endpoint silently breaks transaction semantics or blocks the event loop.

**What to do instead:**
- Pick one model per persistence unit. Do not mix.
- Use `@Transactional` for blocking endpoints only.
- Use `@WithTransaction` for reactive endpoints.
- If you need both, separate them into different persistence units with different datasources.

### 3.3 Ignoring Backpressure in Multi Streams

**Anti-pattern:** Using `Multi<T>` without configuring overflow strategy, or using `Uni<List<T>>` when you mean a stream.

**Why it hurts:** Without backpressure, a fast producer overwhelms a slow consumer. Memory grows unbounded. The application OOMs under load.

**What to do instead:**
```java
// WRONG: No backpressure control
@Incoming("orders")
public Multi<ProcessedOrder> process(Multi<Order> orders) {
    return orders.onItem().transformToUniAndMerge(this::processOrder);
}

// RIGHT: Explicit concurrency and overflow control
@Incoming("orders")
public Multi<ProcessedOrder> process(Multi<Order> orders) {
    return orders
        .onOverflow().buffer(256)
        .onItem().transformToUni(this::processOrder)
        .merge(4); // max 4 concurrent
}
```

### 3.4 Using Reactive Panache on Virtual Threads

**Anti-pattern:** Calling Hibernate Reactive / Panache Reactive methods from `@RunOnVirtualThread` endpoints.

**Why it hurts:** Reactive code must run on the Vert.x event loop thread. Virtual threads are not event loop threads. You get: `"This method should exclusively be invoked from a Vert.x EventLoop thread; currently running on thread 'quarkus-virtual-thread-0'"`

**What to do instead:** Use blocking Panache with virtual threads, or use reactive Panache with reactive endpoints. Do not cross the streams.

---

## 4. Native Image Landmines

### 4.1 Static Fields Initialised at Build Time

**Anti-pattern:** Static fields that capture runtime-dependent values (timestamps, random seeds, system properties, environment variables).

**Why it hurts:** In a native image, static initialisers run during the build. The value is baked into the binary. `System.currentTimeMillis()` returns the build timestamp forever. `Random` seeds are fixed. Singletons with runtime state are frozen.

**What to do instead:**
```java
// WRONG: Frozen at build time in native image
public class TokenGenerator {
    private static final Random RANDOM = new Random(); // seed frozen
    private static final String NODE_ID = System.getenv("NODE_ID"); // null in native
}

// RIGHT: Use CDI for runtime initialisation
@ApplicationScoped
public class TokenGenerator {
    private final Random random;
    private final String nodeId;

    TokenGenerator() {
        this.random = new SecureRandom(); // initialised at runtime
        this.nodeId = ConfigProvider.getConfig()
            .getValue("app.node-id", String.class);
    }
}
```

### 4.2 Resources Not Included in Native Image

**Anti-pattern:** Assuming classpath resources are available in native images.

**Why it hurts:** GraalVM strips everything not explicitly included. Only `META-INF/resources` (for static web assets) is included automatically. Templates, XML configs, properties files outside standard locations — all gone.

**What to do instead:**
```properties
# application.properties
quarkus.native.resources.includes=templates/**,config/*.xml,data/*.json
```

Or use `resource-config.json` in `src/main/resources/META-INF/native-image/`.

### 4.3 Unregistered Reflection Targets

**Anti-pattern:** Using Jackson/JSONB serialisation on DTOs without ensuring they are visible to native compilation.

**Why it hurts:** GraalVM cannot see dynamically-accessed classes. You get `No serializer found for class` or `Can't create instance: No default constructor found` at runtime — only in native mode.

**What to do instead:**
- DTOs used in REST endpoints with `quarkus-rest-jackson` are auto-registered. Rely on this.
- For classes accessed via reflection in other contexts, use `@RegisterForReflection`.
- For third-party classes you cannot annotate: `@RegisterForReflection(targets = {ThirdPartyDto.class})`.
- Avoid `reflect-config.json` maintenance burden when annotations suffice.

### 4.4 Dynamic Proxy Creation at Runtime

**Anti-pattern:** Libraries or code that create `java.lang.reflect.Proxy` instances at runtime.

**Why it hurts:** Native images require all proxy classes to be defined at build time. Runtime proxy creation fails with: `"Generating proxy classes at runtime is not supported."`

**What to do instead:** Register proxies with `@RegisterForProxy` or `proxy-config.json`. Better yet, replace dynamic proxies with CDI alternatives or compile-time code generation.

### 4.5 Logging Library Conflicts

**Anti-pattern:** Pulling in dependencies that bring Apache Commons Logging, Log4j, or SLF4J implementations that conflict with Quarkus's JBoss Logging.

**Why it hurts:** ClassNotFoundException during native builds. Multiple logging frameworks fighting over the same SPI. Inconsistent log output.

**What to do instead:** Exclude conflicting logging implementations. Add JBoss Logging adapters:
```xml
<dependency>
    <groupId>org.jboss.logging</groupId>
    <artifactId>commons-logging-jboss-logging</artifactId>
</dependency>
```

---

## 5. Configuration Malpractice

### 5.1 Unscoped Dangerous Properties

**Anti-pattern:** Setting `quarkus.hibernate-orm.database.generation=drop-and-create` in `application.properties` without a profile prefix.

**Why it hurts:** This runs in production. Your database is wiped on every restart.

**What to do instead:**
```properties
# WRONG: applies everywhere, including production
quarkus.hibernate-orm.database.generation=drop-and-create

# RIGHT: scoped to dev and test only
%dev.quarkus.hibernate-orm.database.generation=drop-and-create
%test.quarkus.hibernate-orm.database.generation=drop-and-create
```

### 5.2 Secrets in application.properties

**Anti-pattern:** Committing database passwords, API keys, or tokens in `application.properties`.

**Why it hurts:** It is in your Git history forever. Every developer, CI system, and code scanner can see it.

**What to do instead:**
- Use `.env` files locally (gitignored).
- Use `${ENV_VAR}` placeholders: `quarkus.datasource.password=${DB_PASSWORD}`.
- Use Kubernetes Secrets or Vault in production.
- Use `@ConfigMapping` with `@WithDefault` for safe defaults.

### 5.3 Not Validating Configuration at Startup

**Anti-pattern:** Trusting that all configuration values are correct and discovering they are not when the first request hits a code path that reads them.

**What to do instead:**
```java
@ConfigMapping(prefix = "app.cache")
public interface CacheConfig {
    @NotBlank
    String region();

    @Min(1) @Max(10000)
    int maxEntries();

    @WithDefault("PT5M")
    Duration ttl();
}
```

The application refuses to start if validation fails. Fail fast, not at 3 AM.

### 5.4 Duplicating Config Across Profiles

**Anti-pattern:** Repeating the same property under `%dev.` and `%test.` because you need it in both but not in production.

**What to do instead:** Use a shared config file or environment-specific config sources. Or use a custom profile that both dev and test activate. The Quarkus team has discussed `%!prod.` syntax but it is not yet standard — for now, accept minimal duplication or use `application-common.properties` with `quarkus.config.locations`.

---

## 6. Testing Anti-Patterns

### 6.1 Fighting Dev Services

**Anti-pattern:** Manually configuring database URLs, Kafka brokers, and Redis instances in test properties when Dev Services would do it automatically.

**Why it hurts:** Dev Services spin up containers automatically in dev and test mode. Manually overriding defeats the purpose, introduces configuration drift between developers, and breaks when someone does not have the right version of Postgres installed locally.

**What to do instead:** Remove explicit `%test.quarkus.datasource.jdbc.url` properties and let Dev Services handle it. If you need a specific database version:
```properties
%test.quarkus.datasource.devservices.image-name=postgres:16
```

### 6.2 Mocking What Quarkus Already Stubs

**Anti-pattern:** Writing Mockito mocks for mail clients, OIDC providers, or other services that Quarkus already provides test doubles for.

**Why it hurts:** Quarkus injects stubbed implementations in test mode automatically. Your Mockito mock is fighting the framework. You end up with brittle tests that verify mock interactions rather than actual behaviour.

**What to do instead:** Check if a `Mock*` or stub exists first:
- `MockMailbox` for email testing
- `OidcWiremockTestResource` for OIDC
- Dev Services for databases, Kafka, Redis, Keycloak
- `QuarkusTest` + `@InjectMock` when you truly need a mock

### 6.3 Not Using @TestProfile for Integration Tests

**Anti-pattern:** Running all tests against the same configuration, or using `@QuarkusTestResource(restrictToAnnotatedClass = true)` on every test class.

**Why it hurts:** Test resource lifecycle becomes unpredictable. Tests interfere with each other. Startup time balloons as containers are created and destroyed.

**What to do instead:** Group tests by profile. Use `@TestProfile` to define test-specific configuration:
```java
public class IntegrationTestProfile implements QuarkusTestProfile {
    @Override
    public Map<String, String> getConfigOverrides() {
        return Map.of("app.feature.flag", "true");
    }
}

@QuarkusTest
@TestProfile(IntegrationTestProfile.class)
public class FeatureFlaggedTest { ... }
```

### 6.4 Using @Transactional in Reactive Tests

**Anti-pattern:** Annotating reactive test methods with `@Transactional` or `@TestTransaction`.

**Why it hurts:** `@Transactional` starts a blocking JTA transaction. In reactive tests, you need a reactive transaction context. You get cryptic Vert.x context errors.

**What to do instead:** Use `@TestReactiveTransaction` which sets up the correct Vert.x context.

---

## 7. Architectural Anti-Patterns

### 7.1 Monolithic Extension Soup

**Anti-pattern:** Adding every Quarkus extension that might be useful, resulting in 30+ extensions in `pom.xml`.

**Why it hurts:** Each extension adds build time, memory footprint, and potential native image complications. Quarkus extensions are not free — they hook into the build process, register beans, and contribute to the dependency graph. Unused extensions are dead weight that slow your build and bloat your binary.

**What to do instead:** Start minimal. Add extensions only when you need them. Run `quarkus extension list --installed` periodically and remove what you are not using.

### 7.2 Not Using the Build-Time Mindset

**Anti-pattern:** Designing systems that defer decisions to runtime when they could be resolved at build time — dynamic bean registration, runtime classpath scanning, lazy module loading.

**Why it hurts:** Quarkus's entire performance advantage comes from doing work at build time. Every decision deferred to runtime is startup time added, memory consumed, and native image compatibility risked.

**What to do instead:** Embrace build-time configuration. Use `@IfBuildProfile`, `@UnlessBuildProfile`, and build-time config properties. Let Quarkus's build step do the heavy lifting.

### 7.3 Ignoring Dev Mode

**Anti-pattern:** Developing with `mvn compile exec:java` or rebuilding manually instead of using `quarkus dev`.

**Why it hurts:** You lose live reload, continuous testing, Dev Services, Dev UI, and the ability to change configuration on the fly. You are working harder for worse feedback loops.

**What to do instead:** Always develop with `quarkus dev` (or `./mvnw quarkus:dev`). Use the Dev UI at `/q/dev-ui` to inspect beans, config, endpoints, and more.

---

## Summary: The Quarkus Mindset

| Spring Boot Thinking | Quarkus Thinking |
|---|---|
| Runtime annotation scanning | Build-time bean discovery |
| `@Autowired` + `@Component` | CDI scopes + constructor injection |
| Spring Data repositories | Panache (active record or repository) |
| `@Value` / `@ConfigurationProperties` | `@ConfigProperty` / `@ConfigMapping` |
| Reflection is free | Reflection is a cost centre |
| Fat JARs with everything | Minimal extensions, lean image |
| Runtime is where things happen | Build time is where things happen |
| Start and configure | Start already configured |

The fundamental shift: **stop thinking in terms of a runtime that assembles itself on startup, and start thinking in terms of a build that produces a pre-assembled application.**
