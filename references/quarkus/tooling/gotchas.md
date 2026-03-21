# Quarkus CLI Gotchas

Common pitfalls, how to detect them, and what to do next.

## CLI Availability and Version Drift

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `quarkus: command not found` | CLI not installed or not on `PATH` | Install via SDKMAN/Homebrew/Chocolatey/Scoop/JBang, then re-check `quarkus --version` |
| Command/flag from docs fails locally | Docs and local CLI versions differ | Use `quarkus --help` and `quarkus <command> --help` for installed version truth |

## Project Context Issues

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `quarkus dev` fails unexpectedly | Not running from project root | Run from directory containing `pom.xml` or `build.gradle(.kts)` |
| Build tool mismatch confusion | CLI delegates based on project type | Verify project files and use matching wrapper fallback (`./mvnw` or `./gradlew`) |

## Extension Management Pitfalls

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Extension not found | Search too broad or wrong ID guess | Use `quarkus ext list --concise -i -s <term>` before `ext add` |
| Unexpected extensions added with wildcard | Wildcard expansion too broad | Prefer exact extension IDs in automated scripts |

## Image and Deploy Pitfalls

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `quarkus image push` auth errors | Missing/invalid registry credentials | Use `--registry`, `--registry-username`, and `--registry-password-stdin` |
| Deploy command fails for target | Local cluster/runtime prerequisites missing | Validate target environment first (kind/minikube/kubernetes/openshift) |

## Plugin Scope Confusion

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Plugin works in one project but not another | Plugin installed project-scoped | Check `<project>/.quarkus/cli/plugins/quarkus-cli-catalog.json` |
| User plugin appears ignored in project | Project catalog overrides user catalog | Use `--user` when you need to act on user-scoped plugins |

## Dev Services Pitfalls

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Dev Services does not start a container | Docker/Podman is not running or not accessible | Start Docker/Podman and verify with `docker ps` |
| Dev Services starts but app uses a different database | An explicit `quarkus.datasource.jdbc.url` is configured | Remove or profile-scope the explicit URL so Dev Services can inject its own |
| Container starts on a different port each restart | Dev Services uses random ports by default | Set `quarkus.datasource.devservices.port` for a fixed port |
| Dev Services container conflicts with another project | Two Quarkus apps share the same Dev Services container by default | Set different `quarkus.datasource.devservices.db-name` per project or disable sharing |
| Dev mode is slow to start | Multiple Dev Services containers start in sequence | Disable unused Dev Services or pre-pull images with `docker pull` |

## Shell UX Pitfalls

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Completion works only in current terminal | Completion not persisted | Add `source <(quarkus completion)` to shell profile |
| Alias `q` does not autocomplete | Alias completion function not bound | Configure `complete -F _complete_quarkus q` |
