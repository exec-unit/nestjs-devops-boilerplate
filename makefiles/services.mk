# ============================================================================
# Service Utilities (exec, backup)
# ============================================================================

.PHONY: exec-postgres exec-mongo exec-redis exec-redpanda exec-keycloak exec-minio exec-nginx exec-certbot exec-prometheus exec-grafana
.PHONY: backup-postgres backup-mongo

# ============================================================================
# Service Exec Commands
# ============================================================================

## exec-postgres: Connect to PostgreSQL
exec-postgres:
	@docker exec -it $${CONTAINER_PREFIX:-boilerplate}-postgres psql -U $${POSTGRES_USER:-postgres} -d $${POSTGRES_DB:-boilerplate}

## exec-mongo: Connect to MongoDB
exec-mongo:
	@docker exec -it $${CONTAINER_PREFIX:-boilerplate}-mongodb mongosh -u $${MONGO_ROOT_USERNAME:-root} -p

## exec-redis: Connect to Redis CLI
exec-redis:
	@docker exec -it $${CONTAINER_PREFIX:-boilerplate}-redis redis-cli

## exec-redpanda: Connect to Redpanda (Kafka) CLI
exec-redpanda:
	@docker exec -it $${CONTAINER_PREFIX:-boilerplate}-redpanda rpk cluster info

## exec-keycloak: Connect to Keycloak container shell
exec-keycloak:
	@docker exec -it $${CONTAINER_PREFIX:-boilerplate}-keycloak /bin/bash

## exec-minio: Connect to MinIO container shell
exec-minio:
	@docker exec -it $${CONTAINER_PREFIX:-boilerplate}-minio sh

## exec-nginx: Connect to Nginx container shell
exec-nginx:
	@docker exec -it $${CONTAINER_PREFIX:-boilerplate}-nginx sh

## exec-certbot: Connect to Certbot container shell
exec-certbot:
	@docker exec -it $${CONTAINER_PREFIX:-boilerplate}-certbot sh

## exec-prometheus: Connect to Prometheus container shell
exec-prometheus:
	@docker exec -it $${CONTAINER_PREFIX:-boilerplate}-prometheus sh

## exec-grafana: Connect to Grafana container shell
exec-grafana:
	@docker exec -it $${CONTAINER_PREFIX:-boilerplate}-grafana sh

# ============================================================================
# Backup Commands
# ============================================================================

## backup-postgres: Create PostgreSQL backup
backup-postgres:
	@echo "$(GREEN)→ Creating PostgreSQL backup...$(RESET)"
	@mkdir -p ./backups
	@docker exec -T $${CONTAINER_PREFIX:-boilerplate}-postgres pg_dump -U $${POSTGRES_USER:-postgres} -d $${POSTGRES_DB:-boilerplate} > ./backups/postgres_$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)✓ Backup created in ./backups/$(RESET)"

## backup-mongo: Create MongoDB backup
backup-mongo:
	@echo "$(GREEN)→ Creating MongoDB backup...$(RESET)"
	@mkdir -p ./backups
	@docker exec -T $${CONTAINER_PREFIX:-boilerplate}-mongodb sh -c 'mongodump --username="$$MONGO_INITDB_ROOT_USERNAME" --password="$$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --out /tmp/backup'
	@docker exec -T $${CONTAINER_PREFIX:-boilerplate}-mongodb tar -czf /tmp/mongo_backup.tar.gz -C /tmp backup
	@docker cp $${CONTAINER_PREFIX:-boilerplate}-mongodb:/tmp/mongo_backup.tar.gz ./backups/mongo_$$(date +%Y%m%d_%H%M%S).tar.gz
	@echo "$(GREEN)✓ Backup created in ./backups/$(RESET)"
