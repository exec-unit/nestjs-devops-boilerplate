# ADR-001: Monorepo Strategy for Microservices

**Date:** 2025-12-17
**Status:** Accepted
**Deciders:** Project Lead

## Context

The boilerplate is designed for multi-service NestJS backends. The repository needs to contain both the application services and the entire DevOps infrastructure.

Repository organization options:

1. Polyrepo - each microservice in a separate repository
2. Monorepo - all services in a single repository with `pnpm` workspaces
3. Hybrid - core services together, auxiliary services separate

## Decision

Use monorepo with `pnpm` workspace structure.

## Rationale

### Why Monorepo for This Project

Solo Developer Efficiency:

- Single `git clone` for the entire platform
- All code searchable in one IDE workspace
- No context switching between multiple repositories

Atomic Cross-Service Changes:

- Update event schemas across publishers and subscribers in one commit
- Refactor shared DTOs or types in a single PR
- No version coordination between repositories

Unified CI/CD:

- Single GitHub Actions workflow with `dorny/paths-filter` for incremental builds
- Shared Docker layer cache across services
- One place for lint, test, and build configuration

Shared Libraries Without Registry:

- `libs/*` packages referenced via `workspace:*` protocol in `package.json`
- No need to publish internal packages to npm
- Type-safe cross-service contracts enforced at build time

### Trade-offs

Not Polyrepo Because:

- Multiple repositories = multiple CI/CD configurations to maintain
- Cross-service changes require multiple PRs and coordination
- Dependency version drift between services
- Harder to demonstrate cohesive architecture

Not Hybrid Because:

- Adds complexity without benefits at this scale
- Still requires coordination between repos for infrastructure changes
- Unclear service boundaries for splitting

## Implementation

### Repository Structure

```
.
├── pnpm-workspace.yaml
├── apps/
│   └── user-service/
├── libs/
├── infrastructure/
├── compose/
├── config/
└── makefiles/
```

### pnpm Workspaces

- `apps/*` - NestJS microservices, each with its own `package.json`
- `libs/*` - Shared TypeScript packages referenced via `workspace:*`
- Root `package.json` contains shared dev dependencies (ESLint, Prettier, Jest, SWC, commitlint, husky)

### CI/CD Strategy

- `dorny/paths-filter` detects changed `apps/` directories per push
- Only changed services are built and pushed to the container registry
- Ansible deploys only updated services (incremental deployment)

## Consequences

### Positive

- Faster development velocity with no cross-repo coordination
- Consistent tooling: single ESLint config, single tsconfig, single Prettier config
- Shared `libs/` packages consumed without publishing to npm
- Simplified local development setup: single `pnpm install` at root

### Negative

- Requires discipline to avoid tight coupling between services via `libs/`
- Larger initial clone size (acceptable trade-off)

## Alternatives Considered

### Polyrepo

Rejected because:

- Overhead of maintaining multiple CI/CD pipelines
- Difficult to make atomic changes across services
- Dependency version drift between services
- Complicated local development setup

### Hybrid (Monorepo + Polyrepo)

Rejected because:

- Adds complexity without clear benefits for current team size
- Still requires cross-repo coordination for some changes

## Related Decisions

- [ADR-002: Redpanda for Event Streaming](002-redpanda.md)
- [ADR-003: Docker Compose for Container Management](003-docker-compose.md)

## References

- [Monorepo.tools](https://monorepo.tools/)
- [Google's Monorepo Philosophy](https://research.google/pubs/pub45424/)
- [pnpm Workspaces](https://pnpm.io/workspaces)
