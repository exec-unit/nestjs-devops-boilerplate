# NestJS DevOps Boilerplate

[![Node.js](https://img.shields.io/badge/Node.js-22-green.svg)](https://nodejs.org/)
[![NestJS](https://img.shields.io/badge/NestJS-11-E0234E.svg)](https://nestjs.com/)
[![pnpm](https://img.shields.io/badge/pnpm-11+-orange.svg)](https://pnpm.io/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED.svg)](https://www.docker.com/)

NestJS monorepo template with a pre-configured DevOps foundation.

Most NestJS projects start from a `nest new` and then incrementally add Docker Compose, CI/CD, secrets management, and deployment automation - each requiring separate setup and maintenance. This repository provides that foundation already assembled: environment separation via Docker Compose profiles, a GitHub Actions pipeline with incremental builds and image scanning, Ansible playbooks for provisioning and deployment to a VPS, and a NestJS monorepo structure with tooling configured.

What is pre-configured out of the box:

- Four environments via Docker Compose profiles (local-dev / shared-dev / stage / prod)
- Incremental CI/CD via `dorny/paths-filter` - only changed services rebuild; Trivy scans every image
- Ansible IaC: `generate-vault.py` converts GitHub Secrets to Ansible Vault, playbooks provision and deploy to VPS
- NestJS monorepo with `pnpm` workspaces, SWC, strict ESLint/Prettier, Husky, commitlint, `@nestjs/terminus`, `prom-client`

## Table of Contents

- [Quick Start](#quick-start)
- [Environment Strategy](#environment-strategy)
- [What Is Pre-configured](#what-is-pre-configured)
- [Repository Structure](#repository-structure)
- [Configuration Management](#configuration-management)
- [Common Commands](#common-commands)
- [Documentation](#documentation)
- [Technology Stack](#technology-stack)
- [Testing](#testing)
- [Adding a New Microservice](#adding-a-new-microservice)
- [Troubleshooting](#troubleshooting)

## Quick Start

Prerequisites:

- Docker & Docker Compose v2+
- Node.js 22+
- pnpm 11+
- Make

First time setup:

```bash
# 1. Initialize configuration files from examples
make init

# 2. Edit the generated .env.infra
# Set ENVIRONMENT=local-dev
# Set passwords for databases

# 3. Install dependencies and register git hooks
pnpm install
pnpm prepare

# 4. Start infrastructure
make up
```

### Verify Everything Works

```bash
make check-services
make logs
```

## Environment Strategy

| Environment  | Active Services                      | Use Case                                      |
| ------------ | ------------------------------------ | --------------------------------------------- |
| `local-dev`  | Postgres, MongoDB, Redis, MinIO      | Developer laptop                              |
| `shared-dev` | + Keycloak, Redpanda, Nginx          | Shared VDS; local devs connect to it remotely |
| `stage`      | Full stack, no MinIO (uses cloud S3) | Pre-production testing                        |
| `prod`       | Full stack + Prometheus/Grafana      | Production                                    |

`ENVIRONMENT` is read from `.env.infra`. On `local-dev`, Keycloak and Redpanda are not started - they run on the shared VDS and local services connect via the external port. This means a developer laptop only runs lightweight infra.

The Docker Compose profiles that `make up` activates are not 1:1 with environment names. The `prod` environment, for example, activates both the `prod` and `monitoring` profiles. See [Architecture Overview](docs/ARCHITECTURE.md#deployment-model) for the exact mapping.

## What Is Pre-configured

Infrastructure & DevOps:

- Docker Compose multi-environment orchestration with profiles
- Ansible deployment automation for `shared-dev`, `stage`, `prod`
- GitHub Actions CI/CD: path-based incremental builds, Trivy vulnerability scanning, `ansible-lint`
- Secrets: Ansible Vault + GitHub Secrets pipeline
- SSL/TLS: Let's Encrypt with auto-renewal via Certbot
- Monitoring: Prometheus + Grafana (prod only)

NestJS application layer:

- Node.js v22, NestJS v11, TypeScript with strict mode
- `swc` compiler for builds and Jest transforms
- `pnpm` workspaces: `apps/*` for services, `libs/*` for shared code
- ESLint (flat config), Prettier, `lint-staged`, `husky` pre-commit hooks
- `commitlint` with Conventional Commits config
- `pino` for JSON logging, `@nestjs/terminus` for healthchecks, `prom-client` for Prometheus metrics

## Repository Structure

```
.
├── apps/
│   └── user-service/
├── libs/
├── infrastructure/
│   ├── ansible/
│   └── keycloak/
├── compose/
│   ├── infra.yml
│   └── monitoring.yml
├── config/
│   ├── postgres/
│   ├── mongodb/
│   ├── redpanda/
│   ├── nginx/
│   └── minio/
├── scripts/
├── makefiles/
└── docs/
```

- `apps/` - NestJS microservices (one per subdirectory, each is an independent pnpm workspace package)
- `libs/` - Shared TypeScript libraries consumed by services
- `infrastructure/` - Ansible playbooks, roles, Keycloak realm customization
- `compose/` - Docker Compose files for infra services and monitoring
- `config/` - Init scripts and templates for databases and infrastructure services
- `scripts/` - Health check, backup, SSL utility scripts
- `makefiles/` - Modular Makefile includes split by concern
- `docs/` - Architecture docs and ADRs

## Configuration Management

### The `config/` Directory

Initialization scripts and configuration templates for infrastructure services. Handles environment-aware service initialization and secrets injection at container startup.

Structure:

```
config/
├── postgres/
│   ├── init-db.sh
│   ├── check-and-init.sh
│   ├── init-users.conf           (gitignored, generated from .example)
│   └── init-users.conf.example
├── mongodb/
├── redpanda/
├── nginx/
└── minio/
```

Example - `config/postgres/init-users.conf`:

```
user_service:USER_SERVICE_DB_PASSWORD:users
```

Format: `username:ENV_VAR_NAME:database`. When the container starts, `init-db.sh` reads this file, resolves `$USER_SERVICE_DB_PASSWORD` from the environment, and creates the user and database if they do not exist. Adding a new service database is a one-line change in this file.

The Nginx config works the same way: `config/nginx/default.conf.template` contains `$VARIABLE` placeholders that are substituted at container startup via `envsubst` from values in `.env.infra`.

### Secrets Management

Local development:

1. Run `make init` to copy all `.example` files
2. Edit `.env.infra` with database passwords
3. Edit `config/postgres/init-users.conf` to map service users to env vars

Production:

```
GitHub Secrets -> generate-vault.py -> vault.yml -> Ansible -> .env.infra on server
```

See [infrastructure/README.md](infrastructure/README.md) for the full Ansible flow.

## Common Commands

```bash
# Start infrastructure for current ENVIRONMENT
make up

# Stop services
make down

# View logs
make logs

# Build all NestJS apps
pnpm build

# Run all workspace tests
pnpm test

# Health check all containers
make check-services
```

Service-specific:

```bash
make up SERVICES=user-service
make restart SERVICES=user-service
make logs SERVICE=user-service
```

For complete command reference, see [docs/MAKEFILE.md](docs/MAKEFILE.md).

## Documentation

- [Architecture Overview](docs/ARCHITECTURE.md) - Deployment model, environment strategy, secrets flow
- [Makefile Reference](docs/MAKEFILE.md) - All `make` commands
- [Infrastructure Guide](infrastructure/README.md) - Ansible deployment process
- [ADRs](docs/adr/) - Architecture decision records

## Technology Stack

Backend:

- Node.js 22, NestJS 11, TypeScript (strict)
- `pnpm` 11 workspaces
- `swc` (compilation and Jest transforms)

Infrastructure:

- PostgreSQL, MongoDB, Redis
- Redpanda (Kafka-compatible, single-binary, no Zookeeper)
- Keycloak (OAuth2/OIDC identity provider)
- MinIO (S3-compatible, local-dev only)
- Nginx (reverse proxy with SSL termination)

DevOps:

- Docker Compose with profiles
- Ansible (deployment automation, see [ADR-005](docs/adr/005-ansible.md))
- GitHub Actions (CI/CD)
- Prometheus + Grafana (prod only)

Docker Compose was chosen over Kubernetes to avoid cluster management overhead at this scale. See [ADR-003](docs/adr/003-docker-compose.md) for the rationale and defined migration triggers.

## Testing

```bash
# Unit tests across all workspace packages
pnpm test

# E2E tests
pnpm test:e2e

# Ansible role tests (Molecule)
make test-ansible
```

## Adding a New Microservice

1. Generate the app: `nest generate app your-service`
2. Add a service definition to `docker-compose.yml` following the `user-service` example
3. Create `apps/your-service/.env` (based on `.env.infra.example` pattern)
4. Add the path to `dorny/paths-filter` in the CI workflow so incremental builds detect it
5. Add database users to `config/postgres/init-users.conf` if needed

## Troubleshooting

Services won't start:

```bash
make check-services
make logs SERVICE=user-service
```

Database connection issues:

```bash
make exec-postgres
# inside psql: \l to list databases, \du to list users
```

Port conflicts:

```bash
make down
make clean
make up
```
