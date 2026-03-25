.PHONY: dev setup install build db migrate clean stop help

# Load .env if it exists
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# ─── Main commands ───────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

dev: setup ## Start everything for local development
	@echo ""
	@echo "  Starting Hanzi dev environment..."
	@echo ""
	@$(MAKE) db
	@sleep 2
	@$(MAKE) migrate
	@echo ""
	@echo "  ✓ Postgres running on localhost:5433"
	@echo "  ✓ Schema migrated"
	@echo ""
	@echo "  Starting managed server on http://localhost:3456"
	@echo "  Dashboard at http://localhost:3456/dashboard"
	@echo "  Docs at http://localhost:3456/docs.html"
	@echo ""
	@cd server && node dist/managed/deploy.js

setup: .env install build symlinks ## Install deps + build + create symlinks
	@echo "  ✓ Setup complete"

install: ## Install all dependencies
	@echo "  Installing dependencies..."
	@command -v docker >/dev/null 2>&1 || (echo "  ✗ Docker not found. Install: https://docs.docker.com/get-docker/" && exit 1)
	@command -v node >/dev/null 2>&1 || (echo "  ✗ Node.js not found. Install Node 18+." && exit 1)
	@npm install --silent 2>/dev/null || true
	@cd server && npm install --silent 2>/dev/null || true
	@cd server/dashboard && npm install --silent 2>/dev/null || true
	@echo "  ✓ Dependencies installed"

build: ## Build server + dashboard + extension
	@echo "  Building..."
	@cd server && npm run build 2>&1 | tail -1
	@echo "  ✓ Build complete"

symlinks: ## Create symlinks for local serving (landing, sdk)
	@ln -sf ../landing server/landing 2>/dev/null || true
	@ln -sf ../sdk server/sdk 2>/dev/null || true

db: ## Start Postgres (Docker)
	@docker compose up -d postgres 2>/dev/null || docker-compose up -d postgres 2>/dev/null || (echo "  ✗ Docker Compose failed. Is Docker running?" && exit 1)

migrate: ## Run database migrations
	@PGPASSWORD=hanzi_dev psql -h localhost -p 5433 -U hanzi -d hanzi -f server/src/managed/schema.sql -q 2>/dev/null || echo "  ⚠ Migration failed (is Postgres running? try: make db)"

stop: ## Stop all services
	@docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
	@echo "  ✓ Services stopped"

clean: stop ## Stop services and remove data
	@docker compose down -v 2>/dev/null || docker-compose down -v 2>/dev/null || true
	@echo "  ✓ Cleaned up"

test: ## Run tests
	@cd server && npx vitest run

# ─── Helpers ─────────────────────────────────────────

.env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "  Created .env from .env.example — edit it with your credentials"; \
	fi
