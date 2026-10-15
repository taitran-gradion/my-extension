# This repository is one Margince extension unit; its root IS the unit.
#
# Core composes only units that sit, as real folders, under its own extensions/
# (a symlinked unit is refused). So every target fetches core at the pinned commit
# into .margince/core and syncs this folder to .margince/core/extensions/$(NAME).
# Edit here, never in the copy: the next sync overwrites it.

NAME     := my-extension
CORE     := .margince/core
UNIT     := $(CORE)/extensions/$(NAME)
REF      := $(shell cat margince.ref)
# The fork that carries the extensions.mod POC (margince/margince#7727).
CORE_URL ?= https://github.com/taitran-gradion/margince
# A separate clone is a primary worktree, which would take the shared `margince`
# database and :8080; a slug gives this stack its own.
CORE_MAKE = $(MAKE) -C $(CORE) DEV_SLUG=$(NAME)

.PHONY: help core install sync compose dev test check stop clean

help: ## List the targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-8s %s\n", $$1, $$2}'

core: ## Fetch core at the commit in margince.ref (again only when it changes)
	@if [ "$$(git -C $(CORE) rev-parse HEAD 2>/dev/null)" != "$(REF)" ]; then \
	  rm -rf $(CORE) && git init -q $(CORE) && git -C $(CORE) fetch -q --depth 1 $(CORE_URL) $(REF) \
	  && git -C $(CORE) -c advice.detachedHead=false checkout -q FETCH_HEAD; \
	fi
	@test -f go.work || go work init . ./$(CORE)/backend

install: core ## One-time core toolchain and frontend install
	$(CORE_MAKE) fe-install tools

sync: core
	@mkdir -p $(UNIT)
	@# Core's gates refuse a git-ignored unit, and core ignores /extensions/* but its own.
	@grep -qxF '!/extensions/$(NAME)' $(CORE)/.gitignore || echo '!/extensions/$(NAME)' >> $(CORE)/.gitignore
	@rsync -a --delete --exclude=/.margince/ --exclude=/.git/ --exclude=node_modules/ \
	  --exclude=/go.work --exclude=/go.work.sum --exclude=/manifest.generated.json ./ $(UNIT)/

compose: sync ## Compose core with this unit and bring its manifest back here
	$(CORE_MAKE) composition
	@cp $(UNIT)/manifest.generated.json .

dev: compose ## Run core with this unit (re-run after a Go change)
	$(CORE_MAKE) dev

test: compose ## This unit's own tests
	$(CORE_MAKE) test-extensions

check: compose ## Every core gate, the extension gates included, against this unit
	$(CORE_MAKE) check

stop: ## Stop this unit's dev stack
	@test ! -d $(CORE) || $(CORE_MAKE) dev-stop

clean: stop ## Remove the fetched core
	rm -rf .margince go.work go.work.sum
