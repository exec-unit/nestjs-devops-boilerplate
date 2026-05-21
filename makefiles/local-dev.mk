# ============================================================================
# Local Development Environment Management
# ============================================================================

.PHONY: init-service-envs init-local



## init-service-envs: Initialize .env files for all services from .env.example
init-service-envs:
	@echo "$(CYAN)→ Initializing service environment files...$(RESET)"
	@if [ ! -d "apps" ]; then \
		echo "$(YELLOW)⚠ apps/ directory not found, skipping$(RESET)"; \
		exit 0; \
	fi
	@service_count=0; \
	for dir in apps/*/; do \
		if [ -d "$$dir" ]; then \
			service=$$(basename "$$dir"); \
			if [ -f "$$dir/.env.example" ]; then \
				if [ ! -f "$$dir/.env" ]; then \
					cp "$$dir/.env.example" "$$dir/.env"; \
					echo "$(GREEN)  ✓ Created apps/$$service/.env$(RESET)"; \
					service_count=$$((service_count + 1)); \
				else \
					echo "$(YELLOW)  ⚠ apps/$$service/.env already exists$(RESET)"; \
				fi; \
			else \
				echo "$(YELLOW)  ⚠ apps/$$service/.env.example not found$(RESET)"; \
			fi; \
		fi; \
	done; \
	if [ $$service_count -eq 0 ]; then \
		echo "$(YELLOW)⚠ No service .env files created (either already exist or no .env.example found)$(RESET)"; \
	else \
		echo "$(GREEN)✓ Created $$service_count service environment file(s)$(RESET)"; \
	fi

## init-local: Complete local development environment setup
init-local: init-env init-microservices init-db-users init-minio-users init-service-envs
	@echo ""
	@echo "$(GREEN)╔════════════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(GREEN)║     Local Development Environment Initialized                  ║$(RESET)"
	@echo "$(GREEN)╚════════════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(CYAN)Next steps:$(RESET)"
	@echo "  1. Edit infrastructure config: $(YELLOW).env.infra$(RESET)"
	@echo "  2. Edit service configs: $(YELLOW)apps/*/.env$(RESET)"
	@echo "  3. Start environment: $(YELLOW)make up$(RESET)"
	@echo ""
