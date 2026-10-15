# A thin Margince instance that runs this extension from the repository root
# (../..) against one core version. Each infra/core-*/Makefile sets its ports,
# database and Redis number, then includes this file.
#
# go.mod is the one place that names the core version: it replaces core's
# modules with the fork's at that tag, and `make core` reads the backend's tag
# from it to fetch the matching core for composing and the web app. Until core
# publishes a `margince` CLI and its SPA as a package, that clone in
# .margince/core (ignored) is where both run.
#
# Infrastructure is the local dev Postgres, Redis and object store that
# `make dev` in core starts.

CORE         := .margince/core
CORE_URL     ?= https://github.com/taitran-gradion/margince
CORE_VERSION := $(shell awk '$$1 == "github.com/margince/margince/backend" && $$2 == "=>" {print $$NF}' go.mod)
EXT_ROOT     := $(abspath ../..)
EXT_MOD      := $(abspath extensions.mod)
OWNER_DSN    := postgres://margince_owner:dev@localhost:15432/$(DB)
APP_DSN      := postgres://margince_app:margince_app_dev@localhost:15432/$(DB)
PG           := docker exec -i margince-postgres-1 psql -q -U margince_owner
RUN          := .run
CORE_MAKE    := $(MAKE) -s -C $(CORE) EXTENSIONS_MOD=$(EXT_MOD) GOWORK= GOFLAGS=
COMPOSED     := GOWORK=$(abspath $(CORE))/build/composition/go.work

export MARGINCE_ENV                  := dev
export MARGINCE_KEYVAULT_ROOT_KEY    := bWFyZ2luY2UtZGV2LW9ubHkta2V5dmF1bHQtcm9vdGs=
export MARGINCE_CONNECTOR_STATE_KEY  := margince-dev-connector-state-key-0001
export MARGINCE_BLOBSTORE_ENDPOINT   := localhost:29000
export MARGINCE_BLOBSTORE_ACCESS_KEY := minioadmin
export MARGINCE_BLOBSTORE_SECRET_KEY := minioadmin
export MARGINCE_BLOBSTORE_REGION     := us-east-1
export MARGINCE_BLOBSTORE_BUCKET     := $(BUCKET)

.PHONY: help core install config compose build test typecheck db migrate run web up stop logs clean

help: ## List the targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

core: ## Fetch core at the version go.mod names (again only when it changes)
	@test -n "$(CORE_VERSION)" || { echo "go.mod replaces no github.com/margince/margince/backend version"; exit 1; }
	@if [ "$$(cat $(CORE)/.version 2>/dev/null)" != "$(CORE_VERSION)" ]; then \
	  echo "fetching core $(CORE_VERSION)"; rm -rf $(CORE) && git init -q $(CORE) \
	  && git -C $(CORE) fetch -q --depth 1 $(CORE_URL) refs/tags/backend/$(CORE_VERSION) \
	  && git -C $(CORE) -c advice.detachedHead=false checkout -q FETCH_HEAD \
	  && echo $(CORE_VERSION) > $(CORE)/.version; fi

install: core ## Once per core version: its frontend dependencies
	@$(CORE_MAKE) fe-install

config: core ## Seed config/ from this core version's examples (once)
	@mkdir -p config
	@[ -f config/margince.yaml ] || cp $(CORE)/config/margince.example.yaml config/margince.yaml
	@[ -f config/margince.dev.yaml ] || cp $(CORE)/config/margince.dev.yaml config/margince.dev.yaml
	@[ -f config/margince-admin-password ] || { printf 'instance-first-password' > config/margince-admin-password; chmod 600 config/margince-admin-password; }

compose: core ## Compose this core with the extension at ../..
	@$(CORE_MAKE) composition
	@echo "core $(CORE_VERSION): composed $$(grep -c 'mustBe("' $(CORE)/build/composition/backend/extensions_gen.go) extensions, $(notdir $(EXT_ROOT)) from $(EXT_ROOT)"

test: compose ## The extension's Go tests, compiled against this core
	@cd $(EXT_ROOT) && $(COMPOSED) go test ./...

typecheck: compose ## The composed SPA, the extension's screen included, type-checks
	@$(CORE_MAKE) fe-typecheck-composed > $(RUN).typecheck.log 2>&1 \
	  && echo "core $(CORE_VERSION): typecheck OK" \
	  || { grep -E 'error' $(RUN).typecheck.log | head; exit 1; }

build: compose ## Core's role binaries, built from this module
	@for role in api worker migrate; do \
	  GOWORK=off GOFLAGS=-mod=mod go build \
	    -ldflags "-X github.com/margince/margince/backend/internal/shared/buildinfo.Revision=ext-$(CORE_VERSION)" \
	    -o bin/$$role github.com/margince/margince/backend/cmd/$$role || exit 1; done

db: core ## Create this instance's database once
	@echo "SELECT 'CREATE DATABASE $(DB)' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$(DB)')\gexec" | $(PG) -d postgres
	@$(PG) -d $(DB) -v ON_ERROR_STOP=1 < $(CORE)/scripts/db-init.sql

migrate: ## Apply core and extension migrations
	@MARGINCE_OWNER_DSN=$(OWNER_DSN) ./bin/migrate up

run: config ## Start the api and the worker
	@mkdir -p $(RUN)
	@for p in api worker; do [ ! -f $(RUN)/$$p.pid ] || { kill $$(cat $(RUN)/$$p.pid) 2>/dev/null || true; rm -f $(RUN)/$$p.pid; }; done
	@MARGINCE_SCHEMA_DSN=$(OWNER_DSN) nohup ./bin/api --addr :$(API_PORT) --dsn $(APP_DSN) --config config/margince.yaml \
	  --redis $(REDIS) --public-base-url http://localhost:$(WEB_PORT) --ai-fake > $(RUN)/api.log 2>&1 & echo $$! > $(RUN)/api.pid
	@for i in $$(seq 60); do curl -sf localhost:$(API_PORT)/readyz >/dev/null && break; sleep 1; done; \
	  curl -sf localhost:$(API_PORT)/readyz >/dev/null || { echo "api not ready — see $(RUN)/api.log"; exit 1; }
	@nohup ./bin/worker --dsn $(APP_DSN) --redis $(REDIS) --config config/margince.yaml \
	  --public-base-url http://localhost:$(WEB_PORT) --ai-fake > $(RUN)/worker.log 2>&1 & echo $$! > $(RUN)/worker.pid

web: ## Serve the SPA with the extension's screen, live from ../../frontend
	@mkdir -p $(RUN)
	@[ ! -f $(RUN)/web.pid ] || { kill $$(cat $(RUN)/web.pid) 2>/dev/null || true; rm -f $(RUN)/web.pid; }
	@BACKEND_PORT=$(API_PORT) MARGINCE_BUILD_REVISION=ext-$(CORE_VERSION) \
	  MARGINCE_COMPOSITION_FRONTEND=$(abspath $(CORE))/build/composition/frontend \
	  nohup pnpm --dir $(CORE)/frontend exec vite --port $(WEB_PORT) --strictPort > $(RUN)/web.log 2>&1 & echo $$! > $(RUN)/web.pid
	@for i in $$(seq 30); do curl -sf -o /dev/null localhost:$(WEB_PORT) && break; sleep 1; done

up: install config build db migrate run web ## Everything, in order
	@echo "core $(CORE_VERSION): http://localhost:$(WEB_PORT)/#/ext/$(notdir $(EXT_ROOT))  (admin@demo.test / $$(cat config/margince-admin-password))"

stop: ## Stop what this instance started
	@for p in api worker web; do [ ! -f $(RUN)/$$p.pid ] || { kill $$(cat $(RUN)/$$p.pid) 2>/dev/null || true; rm -f $(RUN)/$$p.pid; }; done

logs: ## Tail the api and worker logs
	@tail -n 40 $(RUN)/api.log $(RUN)/worker.log

clean: stop ## Remove binaries and the core clone (keeps the database and config/)
	rm -rf bin $(RUN) $(RUN).typecheck.log .margince
