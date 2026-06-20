# Architecture Overview

## Table of Contents

- [Deployment Model](#deployment-model)
- [Secrets to Runtime Flow](#secrets-to-runtime-flow)
- [Application Structure](#application-structure)
- [Data Storage Strategy](#data-storage-strategy)
- [Build and Deployment Pipeline](#build-and-deployment-pipeline)
- [Security](#security)
- [Monitoring and Observability](#monitoring-and-observability)

## Deployment Model

### Four-Environment Strategy

Docker Compose profiles activate different service sets per environment. The `ENVIRONMENT` variable in `.env.infra` drives `make up`, which selects the correct profile combination.

| Environment | ENVIRONMENT Value | Docker Profiles Activated | Services                             | Purpose                 |
| ----------- | ----------------- | ------------------------- | ------------------------------------ | ----------------------- |
| Local Dev   | `local-dev`       | `local-dev`               | Postgres, MongoDB, Redis, MinIO      | Developer laptop        |
| Shared Dev  | `shared-dev`      | `shared-dev`              | + Keycloak, Redpanda, Nginx, Certbot | Shared VDS for the team |
| Staging     | `stage`           | `stage`                   | Full stack (no MinIO, uses cloud S3) | Pre-production testing  |
| Production  | `prod`            | `prod` + `monitoring`     | Full stack + Prometheus/Grafana      | Production deployment   |

Note that profile names do not always match environment names. Production activates two profiles (`prod` and `monitoring`) because the monitoring stack is defined in a separate compose file and activated independently.

In `infra.yml`, services declare which profiles they belong to:

```yaml
postgres:
  profiles: ['infra', 'local-dev', 'shared-dev', 'stage', 'prod']

redpanda:
  profiles: ['infra', 'shared-dev', 'stage', 'prod']

minio:
  profiles: ['infra', 'local-dev']
```

The `infra` profile is used for manual testing without a full environment. MongoDB is absent from `shared-dev` because the shared VDS runs Keycloak and Redpanda (both resource-heavy); each developer runs MongoDB locally.

Keycloak and Redpanda do not run on `local-dev`. Local developers connect to the `shared-dev` instance:

- Keycloak: shared OAuth2/OIDC provider at a fixed domain
- Redpanda: shared event bus, accessible on port 19092 (SASL/SCRAM authenticated)

### Profile Activation Logic

Defined in `makefiles/docker.mk`. The `make up` target reads `ENVIRONMENT` from `.env.infra` and passes the appropriate profile flags:

```makefile
# local-dev
docker compose -f docker-compose.yml -f compose/infra.yml --profile local-dev up -d

# shared-dev
docker compose -f docker-compose.yml -f compose/infra.yml --profile shared-dev up -d

# stage
docker compose -f docker-compose.yml -f compose/infra.yml --profile stage up -d

# prod
docker compose -f docker-compose.yml -f compose/infra.yml -f compose/monitoring.yml \
  --profile prod --profile monitoring up -d
```

## Secrets to Runtime Flow

GitHub Secrets contain multiline `KEY=VALUE` blocks per environment (`INFRA_ENV`, `SERVICE_NAME_ENV`). The pipeline converts them to files on the target server without any plaintext values ever touching Git.

1. GitHub Actions runs `generate-vault.py`, which reads the secrets and writes `vault.yml` with all variables prefixed as `vault_*`. PyYAML handles escaping to prevent injection.

2. Ansible playbook `generate-configs.yml` copies `.env.infra.example` to `.env.infra` on the target server and substitutes each `vault_*` variable into its placeholder.

3. Ansible playbook `generate-service-envs.yml` discovers services from `docker-compose.yml` and creates per-service `.env.service-name` files by extracting the relevant prefix from `vault_services_env`.

4. Docker Compose reads `.env.infra` for infrastructure variables and `apps/service-name/.env` for each microservice. The `ENVIRONMENT` variable drives profile selection.

5. At container startup, init scripts run inside containers and perform the actual resource creation. PostgreSQL's `init-db.sh` reads `init-users.conf` to create users and databases; MinIO's `init-buckets.sh` creates S3 buckets; Redpanda's `bootstrap-user.sh` creates the SASL superuser.

`vault.yml` is never committed - it is generated at CI/CD time and exists only in the GitHub Actions runner's working directory.

## Application Structure

### Monorepo Layout

```
apps/
├── user-service/
│   ├── src/
│   │   ├── main.ts
│   │   ├── app.module.ts
│   │   └── user/
│   ├── test/
│   ├── package.json
│   └── tsconfig.json
libs/
└── (shared TypeScript packages)
```

Each `apps/*` directory is an independent `pnpm` workspace package and maps to one Docker container. Each `libs/*` package is consumed by services via `workspace:*` in `package.json` without publishing to npm.

The root `package.json` holds all shared dev tooling: ESLint, Prettier, Jest, SWC, `commitlint`, `husky`. Service-level `package.json` files hold only runtime dependencies specific to that service.

### Build Process

Development (watch mode):

```bash
pnpm dev:build
pnpm start:dev
```

`dev:build` runs `swc apps libs -d dist -w`. `start:dev` starts all services in parallel via `pnpm -r --parallel run start:dev`, where each service runs `nest start --watch` pointing at the compiled `dist/`.

Production - a single `Dockerfile` parameterized by `APP_NAME`:

```dockerfile
FROM node:22-alpine AS builder
ARG APP_NAME
WORKDIR /app
COPY . .
RUN pnpm install && pnpm build
# Isolate the monorepo service and its production dependencies
RUN pnpm deploy --filter=${APP_NAME} --prod /out
RUN cp -r dist/apps/${APP_NAME}/src /out/dist

FROM node:22-alpine AS runner
# Only the specific service and its dependencies are included
COPY --from=builder /out ./
CMD ["node", "dist/main.js"]
```

Used in `docker-compose.yml`:

```yaml
build:
  context: .
  dockerfile: Dockerfile
  args:
    APP_NAME: user-service
```

### Communication Patterns

Synchronous (HTTP):

```
Client -> Nginx -> NestJS Service -> another NestJS Service (HTTP)
```

Asynchronous (event-driven via Redpanda):

```
Service A publishes event -> Redpanda topic -> Service B subscribes
```

`@nestjs/microservices` with the Kafka transport connects to Redpanda. The Kafka transport is API-compatible with Redpanda; no code changes are needed if migrating to Apache Kafka.

## Data Storage Strategy

| Storage    | Use Cases                                                      |
| ---------- | -------------------------------------------------------------- |
| PostgreSQL | Transactional data: business entities, structured records      |
| MongoDB    | High write throughput, flexible schema: logs, events, metadata |
| Redis      | Caching, rate limiting, BullMQ job queues, session storage     |

All storage is behind service-level abstractions. Each microservice owns its own database (database-per-service pattern). Cross-service data access goes through events or HTTP, not shared databases.

## Build and Deployment Pipeline

### CI/CD Overview

Staging (push to `main`):

- `dorny/paths-filter` detects which `apps/` directories changed. Only changed services are built.
- Each Docker image is scanned with Trivy. CRITICAL and HIGH vulnerabilities fail the pipeline.
- Images are tagged `sha-{commit_hash}` and pushed to the container registry.
- Ansible deploys to the staging server automatically.

Production (Git tag `v*`):

- Identical build process to staging.
- Images tagged `v{major}.{minor}.{patch}`.
- Ansible deployment requires manual approval (GitHub environment protection).

### Ansible Deployment Process

1. Pre-flight checks: RAM >= 1GB, vCPU >= 1, Disk >= 5GB, DNS resolution valid, ports 80/443 available
2. Infrastructure setup: Docker installation, UFW firewall, SSL certificates via Certbot
3. File sync: rsync from CI/CD runner to target server (`compose/`, `config/`, `scripts/`, `makefiles/`, `Makefile`, `docker-compose.yml`, `.env.infra.example`)
4. Configuration generation: vault variables substituted into `.env.infra` and per-service `.env` files
5. `docker compose pull` for updated images
6. `docker compose up -d`
7. Health verification via `scripts/check-services.sh`

Source code (`apps/`, `libs/`) is never synced to the server - only compiled Docker images are pulled from the registry.

## Security

Authentication and authorization:

- Keycloak as centralized OAuth2/OIDC identity provider
- JWT tokens for service-to-service authentication
- RBAC via Keycloak roles and realm configuration

Secrets management:

- `.env.infra`, `vault.yml`, and `config/*/init-users.conf` are never committed
- All sensitive files get `0600` permissions on target servers set by Ansible

Network:

- Only ports 80 and 443 are exposed externally; UFW blocks everything else
- Database and service ports are bound to `127.0.0.1` only
- Docker internal network (`boilerplate_net`) for service-to-service communication
- Let's Encrypt SSL with automatic renewal via Certbot

Container:

- Trivy scans in CI (CRITICAL/HIGH block deployment)
- Non-root users in all containers
- Docker Compose health checks ensure dependencies are ready before dependents start

## Monitoring and Observability

Metrics (production only):

- Prometheus scrapes `/metrics` from all NestJS services (`prom-client` + `@willsoto/nestjs-prometheus`)
- Grafana with pre-configured dashboards via provisioning
- 7 days metric retention

Health checks:

- `@nestjs/terminus` exposes `/health` in each service
- Docker Compose `healthcheck` defined for every infrastructure container
- `scripts/check-services.sh` for manual status verification

Logging:

- `pino` for JSON-structured logging in all environments
- `pino-pretty` for human-readable output in `local-dev`
- Log level configurable via `LOG_LEVEL` environment variable

## Related Documentation

- [ADR-001: Monorepo Strategy](adr/001-monorepo.md)
- [ADR-002: Redpanda vs Kafka](adr/002-redpanda.md)
- [ADR-003: Docker Compose for Container Management](adr/003-docker-compose.md)
- [ADR-004: Git as Single Source of Truth](adr/004-git-as-single-source-of-truth.md)
- [ADR-005: Ansible for Deployment Automation](adr/005-ansible.md)
- [Makefile Reference](MAKEFILE.md)
- [Infrastructure Guide](../infrastructure/README.md)
