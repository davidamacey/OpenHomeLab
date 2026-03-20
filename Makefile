# ===========================================================================
# OpenHomeLab — Makefile
# ===========================================================================
#
# Usage:
#   make up SERVICE=ai/comfyui             # start one service
#   make down SERVICE=ai/comfyui           # stop one service
#   make logs SERVICE=llm/open-webui       # tail logs
#   make restart SERVICE=media/immich      # restart a service
#   make pull SERVICE=ai/comfyui           # pull latest images
#   make up-category CATEGORY=ai           # start all services in a category
#   make up-all                            # start every service
#   make down-all                          # stop every service
#   make pull-all                          # pull all latest images
#   make status                            # list running containers
#   make gpu                               # show GPU status
#   make network                           # create the shared homelab network
# ===========================================================================

SERVICES_DIR := services
COMPOSE      := docker compose

.PHONY: up down logs restart pull status gpu network \
        up-category down-category \
        up-all down-all pull-all \
        help

# ---------------------------------------------------------------------------
# Single service targets — require SERVICE=<category>/<name>
# ---------------------------------------------------------------------------

## Start a single service: make up SERVICE=ai/comfyui
up:
ifndef SERVICE
	$(error SERVICE is required. Usage: make up SERVICE=ai/comfyui)
endif
	@echo "Starting $(SERVICE)..."
	@cd $(SERVICES_DIR)/$(SERVICE) && $(COMPOSE) up -d
	@echo "Done. Logs: make logs SERVICE=$(SERVICE)"

## Stop a single service: make down SERVICE=ai/comfyui
down:
ifndef SERVICE
	$(error SERVICE is required. Usage: make down SERVICE=ai/comfyui)
endif
	@echo "Stopping $(SERVICE)..."
	@cd $(SERVICES_DIR)/$(SERVICE) && $(COMPOSE) down
	@echo "Done."

## Tail logs: make logs SERVICE=llm/open-webui
logs:
ifndef SERVICE
	$(error SERVICE is required. Usage: make logs SERVICE=llm/open-webui)
endif
	@cd $(SERVICES_DIR)/$(SERVICE) && $(COMPOSE) logs -f

## Restart a service: make restart SERVICE=media/immich
restart:
ifndef SERVICE
	$(error SERVICE is required. Usage: make restart SERVICE=media/immich)
endif
	@cd $(SERVICES_DIR)/$(SERVICE) && $(COMPOSE) restart

## Pull latest images for a service: make pull SERVICE=ai/comfyui
pull:
ifndef SERVICE
	$(error SERVICE is required. Usage: make pull SERVICE=ai/comfyui)
endif
	@cd $(SERVICES_DIR)/$(SERVICE) && $(COMPOSE) pull

# ---------------------------------------------------------------------------
# Category targets — require CATEGORY=<category>
# ---------------------------------------------------------------------------

## Start all services in a category: make up-category CATEGORY=ai
up-category:
ifndef CATEGORY
	$(error CATEGORY is required. Usage: make up-category CATEGORY=ai)
endif
	@for dir in $(SERVICES_DIR)/$(CATEGORY)/*/; do \
		if [ -f "$${dir}docker-compose.yml" ]; then \
			echo "Starting $${dir}..."; \
			(cd $${dir} && $(COMPOSE) up -d) || echo "WARNING: $${dir} failed to start"; \
		fi \
	done
	@echo "Done starting category: $(CATEGORY)"

## Stop all services in a category: make down-category CATEGORY=ai
down-category:
ifndef CATEGORY
	$(error CATEGORY is required. Usage: make down-category CATEGORY=ai)
endif
	@for dir in $(SERVICES_DIR)/$(CATEGORY)/*/; do \
		if [ -f "$${dir}docker-compose.yml" ]; then \
			echo "Stopping $${dir}..."; \
			(cd $${dir} && $(COMPOSE) down) || true; \
		fi \
	done
	@echo "Done stopping category: $(CATEGORY)"

# ---------------------------------------------------------------------------
# Global targets
# ---------------------------------------------------------------------------

## Start all services
up-all:
	@echo "Starting all services..."
	@for dir in $(SERVICES_DIR)/*/*/; do \
		if [ -f "$${dir}docker-compose.yml" ]; then \
			echo "Starting $${dir}..."; \
			(cd $${dir} && $(COMPOSE) up -d) || echo "WARNING: $${dir} failed to start"; \
		fi \
	done
	@echo "All services started."

## Stop all services
down-all:
	@echo "Stopping all services..."
	@for dir in $(SERVICES_DIR)/*/*/; do \
		if [ -f "$${dir}docker-compose.yml" ]; then \
			echo "Stopping $${dir}..."; \
			(cd $${dir} && $(COMPOSE) down) || true; \
		fi \
	done
	@echo "All services stopped."

## Pull latest images for all services
pull-all:
	@echo "Pulling latest images..."
	@for dir in $(SERVICES_DIR)/*/*/; do \
		if [ -f "$${dir}docker-compose.yml" ]; then \
			echo "Pulling $${dir}..."; \
			(cd $${dir} && $(COMPOSE) pull) || echo "WARNING: $${dir} pull failed"; \
		fi \
	done
	@echo "All images updated."

# ---------------------------------------------------------------------------
# Status / monitoring
# ---------------------------------------------------------------------------

## Show all running containers
status:
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | sort

## Show GPU allocation
gpu:
	@nvidia-smi
	@echo ""
	@echo "=== Containers with GPU access ==="
	@docker ps --filter "label=gpu=true" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

# ---------------------------------------------------------------------------
# Network setup
# ---------------------------------------------------------------------------

## Create the shared homelab Docker network (run once)
network:
	@docker network inspect homelab >/dev/null 2>&1 \
		&& echo "Network 'homelab' already exists." \
		|| (docker network create homelab && echo "Network 'homelab' created.")

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

## Show this help message
help:
	@echo ""
	@echo "OpenHomeLab — Makefile targets"
	@echo "================================"
	@echo ""
	@echo "Single service (requires SERVICE=<category>/<name>):"
	@echo "  make up SERVICE=ai/comfyui"
	@echo "  make down SERVICE=ai/comfyui"
	@echo "  make logs SERVICE=llm/open-webui"
	@echo "  make restart SERVICE=media/immich"
	@echo "  make pull SERVICE=ai/comfyui"
	@echo ""
	@echo "Category (requires CATEGORY=<name>):"
	@echo "  make up-category CATEGORY=ai"
	@echo "  make down-category CATEGORY=ai"
	@echo ""
	@echo "Global:"
	@echo "  make up-all        Start all services"
	@echo "  make down-all      Stop all services"
	@echo "  make pull-all      Pull latest images"
	@echo "  make status        Show running containers"
	@echo "  make gpu           Show GPU allocation"
	@echo "  make network       Create homelab Docker network"
	@echo ""
	@echo "Available categories: ai, llm, media, home, utilities, infra"
	@echo ""

.DEFAULT_GOAL := help
