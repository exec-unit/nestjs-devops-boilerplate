# Makefile Reference

Complete guide to all `make` commands available in the project.

## Quick Reference

```bash
make <command>
make help
```

## Environment Management

### Starting & Stopping

| Command                         | Description                                                      |
| ------------------------------- | ---------------------------------------------------------------- |
| `make up`                       | Start all services for current `ENVIRONMENT` (from `.env.infra`) |
| `make up SERVICES=<names>`      | Start specific service(s)                                        |
| `make down`                     | Stop all running services                                        |
| `make down SERVICES=<names>`    | Stop specific service(s)                                         |
| `make restart`                  | Restart all services                                             |
| `make restart SERVICES=<names>` | Restart specific service(s)                                      |
| `make restart-db`               | Restart database containers to apply new user configurations     |
| `make ps`                       | List running containers with status                              |

### Initialization

| Command              | Description                                                                                  |
| -------------------- | -------------------------------------------------------------------------------------------- |
| `make init`          | Copy all `.example` files to their real counterparts (`.env.infra`, `init-users.conf`, etc.) |
| `make init-env`      | Initialize `.env.infra` only                                                                 |
| `make init-db-users` | Initialize database user config files only                                                   |
| `make check-env`     | Verify `.env.infra` exists before running compose commands                                   |

## Service Interaction

### Exec into Containers

| Command                | Description                          |
| ---------------------- | ------------------------------------ |
| `make exec-postgres`   | `psql` shell as the configured user  |
| `make exec-mongo`      | `mongosh` shell as root              |
| `make exec-redis`      | `redis-cli` shell                    |
| `make exec-redpanda`   | `rpk cluster info` in the container  |
| `make exec-keycloak`   | Bash shell in the Keycloak container |
| `make exec-minio`      | Shell in the MinIO container (`mc`)  |
| `make exec-nginx`      | Shell in the Nginx container         |
| `make exec-certbot`    | Shell in the Certbot container       |
| `make exec-prometheus` | Shell in the Prometheus container    |
| `make exec-grafana`    | Shell in the Grafana container       |

### Logs

| Command                          | Description                         |
| -------------------------------- | ----------------------------------- |
| `make logs`                      | Follow logs from all services       |
| `make logs SERVICE=user-service` | Follow logs from a specific service |

## Database Management

### Backups

`make backup-postgres` and `make backup-mongo` use `pg_dump` and `mongodump` inside the running containers and copy the output to `./backups/`.

| Command                | Description                                           |
| ---------------------- | ----------------------------------------------------- |
| `make backup-postgres` | `pg_dump` to `backups/postgres_YYYYMMDD_HHMMSS.sql`   |
| `make backup-mongo`    | `mongodump` to `backups/mongo_YYYYMMDD_HHMMSS.tar.gz` |

These are ad-hoc dumps for development use. For production backup automation with deduplication, encryption, and remote storage, configure [Restic](https://restic.net/) separately - the Ansible `backup` role provides the hooks.

## SSL Certificate Management

| Command               | Description                                        |
| --------------------- | -------------------------------------------------- |
| `make ssl-cert-init`  | Obtain initial SSL certificates from Let's Encrypt |
| `make ssl-cert-renew` | Manually renew SSL certificates                    |
| `make ssl-setup-cron` | Setup automatic renewal via systemd/cron           |

Requires `ENVIRONMENT=stage` or `prod`, valid `SSL_EMAIL`, `API_DOMAIN_NAME`, `KEYCLOAK_DOMAIN_NAME` in `.env.infra`, and DNS records pointing to the server.

## Cleanup

| Command              | Description                                       |
| -------------------- | ------------------------------------------------- |
| `make clean`         | Remove containers and networks (volumes are kept) |
| `make clean-volumes` | Remove ALL volumes - deletes all database data    |
| `make prune`         | `docker system prune` to reclaim disk space       |

`make clean-volumes` prompts for confirmation before proceeding.

## Testing & Linting

| Command                                     | Description                                     |
| ------------------------------------------- | ----------------------------------------------- |
| `make test`                                 | Run all Ansible tests (Molecule + ansible-lint) |
| `make test-ansible`                         | Run Molecule tests for all roles                |
| `make test-ansible-role ROLE=nestjs_deploy` | Test a specific Ansible role                    |
| `make test-ansible-lint`                    | Run ansible-lint on playbooks and roles         |

Node.js tests run via pnpm, not make:

```bash
pnpm test
pnpm test:e2e
```

## Utilities

| Command               | Description                                                        |
| --------------------- | ------------------------------------------------------------------ |
| `make check-services` | Run `scripts/check-services.sh` to verify health of all containers |

## Environment-Specific Behavior

The `ENVIRONMENT` variable in `.env.infra` determines which Docker Compose profiles are activated. See [Architecture Overview](ARCHITECTURE.md#deployment-model) for the exact profile-to-environment mapping.

### local-dev

Starts: Postgres, MongoDB, Redis, MinIO

Does not start: Keycloak, Redpanda, Nginx, Certbot, Prometheus, Grafana

Keycloak and Redpanda are expected to be available on the shared-dev VDS; configure their connection details in the service `.env` files.

### shared-dev

Starts: Keycloak, Redpanda, Nginx, Certbot

Postgres is also started on shared-dev (Keycloak depends on it). MongoDB is not started on shared-dev - developers run it locally.

### stage

Starts: Full stack except MinIO (cloud S3 used instead)

### prod

Starts: Full stack (no MinIO) + Prometheus + Grafana

## Troubleshooting

### Services won't start

```bash
make ps
make check-services
make logs SERVICE=user-service
```

### Database connection issues

```bash
make exec-postgres
```

Inside psql: `\l` lists databases, `\du` lists users.

### SSL certificate issues

```bash
make exec-certbot
make ssl-cert-renew
```
