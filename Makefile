# Makefile for Docker Swarm Deployment

# Variables
COMPOSE_FILE = docker-compose.yml
STACK_NAME = brianrepro
REGISTRY = alpenglow411
TIMESTAMP_FILE = .timestamp
TIMESTAMP = $(shell cat $(TIMESTAMP_FILE) 2>/dev/null || echo "latest")
IMAGE_TAG = $(TIMESTAMP)

# Generate timestamp file
generate-timestamp:
	@echo "$(shell date +%Y%m%d%H%M%S)" > $(TIMESTAMP_FILE)
	@echo "$(BLUE)Generated timestamp: $(shell cat $(TIMESTAMP_FILE))$(NC)"

# Ensure timestamp is consistent across all targets
.PHONY: help build deploy undeploy logs status scale restart clean prune generate-timestamp

# Default target
help: ## Show this help message
	@echo "$(BLUE)Docker Swarm Deployment Makefile$(NC)"
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'

# Build targets
build: generate-timestamp ## Build all services
	@echo "$(BLUE)Building Docker images with tag $(IMAGE_TAG)...$(NC)"
	@echo "$(YELLOW)Using Docker context: builds$(NC)"
	docker context use builds
	docker compose -f $(COMPOSE_FILE) build
	@echo "$(BLUE)Tagging images with timestamp $(IMAGE_TAG)...$(NC)"
	docker tag $(REGISTRY)/ping:latest $(REGISTRY)/ping:$(IMAGE_TAG)
	docker tag $(REGISTRY)/pong:latest $(REGISTRY)/pong:$(IMAGE_TAG)
	docker tag $(REGISTRY)/caddy:latest $(REGISTRY)/caddy:$(IMAGE_TAG)
	@echo "$(GREEN)Build completed with tag $(IMAGE_TAG)!$(NC)"

build-no-cache: generate-timestamp ## Build all services without cache
	@echo "$(BLUE)Building Docker images (no cache) with tag $(IMAGE_TAG)...$(NC)"
	@echo "$(YELLOW)Using Docker context: builds$(NC)"
	docker context use builds
	docker compose -f $(COMPOSE_FILE) build --no-cache
	@echo "$(BLUE)Tagging images with timestamp $(IMAGE_TAG)...$(NC)"
	docker tag $(REGISTRY)/ping:latest $(REGISTRY)/ping:$(IMAGE_TAG)
	docker tag $(REGISTRY)/pong:latest $(REGISTRY)/pong:$(IMAGE_TAG)
	docker tag $(REGISTRY)/caddy:latest $(REGISTRY)/caddy:$(IMAGE_TAG)
	@echo "$(GREEN)Build completed with tag $(IMAGE_TAG)!$(NC)"

# Swarm management
init-swarm: ## Initialize Docker Swarm
	@echo "$(BLUE)Initializing Docker Swarm...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	docker swarm init || echo "$(YELLOW)Swarm already initialized$(NC)"
	@echo "$(GREEN)Swarm initialized!$(NC)"

leave-swarm: ## Leave Docker Swarm
	@echo "$(RED)Leaving Docker Swarm...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	docker swarm leave --force
	@echo "$(GREEN)Left swarm!$(NC)"

# Update compose file with timestamped tags
update-compose: ## Update docker-compose.yml with timestamped image tags
	@echo "$(BLUE)Updating docker-compose.yml with tag $(IMAGE_TAG)...$(NC)"
	@sed -i.bak 's|alpenglow411/ping:latest|alpenglow411/ping:$(IMAGE_TAG)|g' $(COMPOSE_FILE)
	@sed -i.bak 's|alpenglow411/pong:latest|alpenglow411/pong:$(IMAGE_TAG)|g' $(COMPOSE_FILE)
	@sed -i.bak 's|alpenglow411/caddy:latest|alpenglow411/caddy:$(IMAGE_TAG)|g' $(COMPOSE_FILE)
	@rm -f $(COMPOSE_FILE).bak
	@echo "$(GREEN)Docker-compose.yml updated with tag $(IMAGE_TAG)!$(NC)"

# Deployment targets
deploy: update-compose ## Deploy stack to Docker Swarm
	@echo "$(BLUE)Deploying stack '$(STACK_NAME)' to Docker Swarm with tag $(IMAGE_TAG)...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	docker stack deploy -c $(COMPOSE_FILE) $(STACK_NAME) --with-registry-auth
	@echo "$(GREEN)Stack deployed with tag $(IMAGE_TAG)!$(NC)"

deploy-force: update-compose ## Force deploy stack (recreate services)
	@echo "$(BLUE)Force deploying stack '$(STACK_NAME)' with tag $(IMAGE_TAG)...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	docker stack deploy -c $(COMPOSE_FILE) $(STACK_NAME) --with-registry-auth
	@echo "$(GREEN)Stack force deployed with tag $(IMAGE_TAG)!$(NC)"

undeploy: ## Remove stack from Docker Swarm
	@echo "$(RED)Removing stack '$(STACK_NAME)' from Docker Swarm...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	docker stack rm $(STACK_NAME)
	@echo "$(GREEN)Stack removed!$(NC)"

# Monitoring and management
status: ## Show stack status
	@echo "$(BLUE)Stack Status:$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	@docker stack ls
	@echo ""
	@echo "$(BLUE)Service Status:$(NC)"
	@docker stack services $(STACK_NAME) || echo "$(YELLOW)Stack not found$(NC)"

logs: ## Show logs for all services
	@echo "$(BLUE)Showing logs for all services...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	@docker service logs -f $(STACK_NAME)_ping || echo "$(YELLOW)Ping service not found$(NC)"

logs-ping: ## Show logs for ping service
	@echo "$(BLUE)Showing logs for ping service...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	@docker service logs -f $(STACK_NAME)_ping

logs-pong: ## Show logs for pong service
	@echo "$(BLUE)Showing logs for pong service...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	@docker service logs -f $(STACK_NAME)_pong


logs-caddy: ## Show logs for Caddy service
	@echo "$(BLUE)Showing logs for Caddy service...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	@docker service logs -f $(STACK_NAME)_caddy

# Scaling
scale-ping: ## Scale ping service (usage: make scale-ping REPLICAS=3)
	@echo "$(BLUE)Scaling ping service to $(REPLICAS) replicas...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	@docker service scale $(STACK_NAME)_ping=$(REPLICAS)
	@echo "$(GREEN)Ping service scaled!$(NC)"

scale-pong: ## Scale pong service (usage: make scale-pong REPLICAS=3)
	@echo "$(BLUE)Scaling pong service to $(REPLICAS) replicas...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	@docker service scale $(STACK_NAME)_pong=$(REPLICAS)
	@echo "$(GREEN)Pong service scaled!$(NC)"

scale-caddy: ## Scale Caddy service (usage: make scale-caddy REPLICAS=2)
	@echo "$(BLUE)Scaling Caddy service to $(REPLICAS) replicas...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	@docker service scale $(STACK_NAME)_caddy=$(REPLICAS)
	@echo "$(GREEN)Caddy service scaled!$(NC)"

# Service management
restart: ## Restart all services
	@echo "$(BLUE)Restarting all services...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	@docker service update --force $(STACK_NAME)_ping || echo "$(YELLOW)Ping service not found$(NC)"
	@docker service update --force $(STACK_NAME)_pong || echo "$(YELLOW)Pong service not found$(NC)"
	@docker service update --force $(STACK_NAME)_caddy || echo "$(YELLOW)Caddy service not found$(NC)"
	@echo "$(GREEN)Services restarted!$(NC)"

restart-ping: ## Restart ping service
	@echo "$(BLUE)Restarting ping service...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	@docker service update --force $(STACK_NAME)_ping
	@echo "$(GREEN)Ping service restarted!$(NC)"

restart-pong: ## Restart pong service
	@echo "$(BLUE)Restarting pong service...$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	@docker service update --force $(STACK_NAME)_pong
	@echo "$(GREEN)Pong service restarted!$(NC)"

# Health checks
health: ## Check health of all services
	@echo "$(BLUE)Health Check:$(NC)"
	@echo "$(YELLOW)Using Docker context: dev$(NC)"
	docker context use dev
	@docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}\t{{.Ports}}"

# Cleanup
clean: ## Clean up unused resources
	@echo "$(BLUE)Cleaning up unused resources...$(NC)"
	@echo "$(YELLOW)Using Docker context: builds$(NC)"
	docker context use builds
	docker system prune -f
	@echo "$(GREEN)Cleanup completed!$(NC)"

prune: ## Prune all unused Docker resources
	@echo "$(RED)Pruning all unused Docker resources...$(NC)"
	@echo "$(YELLOW)Using Docker context: builds$(NC)"
	docker context use builds
	docker system prune -a -f --volumes
	@echo "$(GREEN)Prune completed!$(NC)"

# Development helpers
dev-up: ## Start services locally for development
	@echo "$(BLUE)Starting services locally for development...$(NC)"
	@echo "$(YELLOW)Using Docker context: builds$(NC)"
	docker context use builds
	docker compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)Services started locally!$(NC)"

dev-down: ## Stop local development services
	@echo "$(BLUE)Stopping local development services...$(NC)"
	@echo "$(YELLOW)Using Docker context: builds$(NC)"
	docker context use builds
	docker compose -f $(COMPOSE_FILE) down
	@echo "$(GREEN)Local services stopped!$(NC)"

dev-logs: ## Show logs for local development
	@echo "$(BLUE)Showing logs for local development...$(NC)"
	@echo "$(YELLOW)Using Docker context: builds$(NC)"
	docker context use builds
	docker compose -f $(COMPOSE_FILE) logs -f

# Registry management
push: ## Push images to registry
	@echo "$(BLUE)Pushing images to registry with tag $(IMAGE_TAG)...$(NC)"
	@echo "$(YELLOW)Using Docker context: builds$(NC)"
	@echo "$(YELLOW)Note: Make sure you're logged into the registry first$(NC)"
	docker context use builds
	docker compose -f $(COMPOSE_FILE) push
	@echo "$(BLUE)Pushing timestamped images...$(NC)"
	docker push $(REGISTRY)/ping:$(IMAGE_TAG)
	docker push $(REGISTRY)/pong:$(IMAGE_TAG)
	docker push $(REGISTRY)/caddy:$(IMAGE_TAG)
	@echo "$(GREEN)Images pushed with tag $(IMAGE_TAG)!$(NC)"

pull: ## Pull images from registry
	@echo "$(BLUE)Pulling images from registry...$(NC)"
	@echo "$(YELLOW)Using Docker context: builds$(NC)"
	@echo "$(YELLOW)Note: Make sure you're logged into the registry first$(NC)"
	docker context use builds
	docker compose -f $(COMPOSE_FILE) pull
	@echo "$(GREEN)Images pulled!$(NC)"

login: ## Login to Docker Hub
	@echo "$(BLUE)Logging into Docker Hub...$(NC)"
	@echo "$(YELLOW)Using Docker context: builds$(NC)"
	docker context use builds
	docker login
	@echo "$(GREEN)Logged in to Docker Hub!$(NC)"

# Restore compose file to latest tags
restore-compose: ## Restore docker-compose.yml to latest image tags
	@echo "$(BLUE)Restoring docker-compose.yml to latest tags...$(NC)"
	@sed -i.bak 's|alpenglow411/ping:[0-9]*|alpenglow411/ping:latest|g' $(COMPOSE_FILE)
	@sed -i.bak 's|alpenglow411/pong:[0-9]*|alpenglow411/pong:latest|g' $(COMPOSE_FILE)
	@sed -i.bak 's|alpenglow411/caddy:[0-9]*|alpenglow411/caddy:latest|g' $(COMPOSE_FILE)
	@rm -f $(COMPOSE_FILE).bak
	@echo "$(GREEN)Docker-compose.yml restored to latest tags!$(NC)"

# Clean targets

# Quick deployment workflow
quick-deploy: build push deploy ## Build, push, and deploy in one command
	@echo "$(GREEN)Quick deployment completed with tag $(IMAGE_TAG)!$(NC)"

# Show current timestamp
show-timestamp: generate-timestamp ## Show current timestamp that would be used for tagging
	@echo "$(BLUE)Current timestamp: $(IMAGE_TAG)$(NC)"
	@echo "$(BLUE)Image tag: $(IMAGE_TAG)$(NC)"

# Show service endpoints
endpoints: ## Show service endpoints
	@echo "$(BLUE)Service Endpoints:$(NC)"
	@echo "Application: http://localhost"
	@echo "Health Check: http://localhost/health"
