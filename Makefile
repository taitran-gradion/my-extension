# This repository is one Margince extension; its root IS the extension module.
#
# infra/ holds one thin instance per core version the extension supports. Each
# loads the extension from this root (replace => ../..) and fetches its own
# core, so the same working copy is tested against every version. infra/ is a
# set of nested Go modules, so none of it ships in the extension's module zip.

INSTANCES := $(patsubst infra/%/Makefile,%,$(wildcard infra/*/Makefile))
# The newest instance answers editor lookups (go.work) when no V= is given.
V ?= $(lastword $(INSTANCES))

.PHONY: help test typecheck check up stop work clean

help: ## List the targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'
	@echo "  instances: $(INSTANCES)"

test: ## The extension's Go tests, against every core version
	@for i in $(INSTANCES); do echo "== $$i"; $(MAKE) -s -C infra/$$i test || exit 1; done

typecheck: ## The composed SPA with this screen type-checks, against every core version
	@for i in $(INSTANCES); do $(MAKE) -s -C infra/$$i install typecheck || exit 1; done

check: test typecheck ## Both, before a release

up: ## Run one instance: make up V=core-v0.0.6 (default: the newest)
	@$(MAKE) -s -C infra/$(V) up

stop: ## Stop every instance
	@for i in $(INSTANCES); do $(MAKE) -s -C infra/$$i stop; done

work: ## Write go.work so an editor resolves core from instance V
	@$(MAKE) -s -C infra/$(V) core
	@rm -f go.work go.work.sum && go work init . ./infra/$(V)/.margince/core/backend
	@echo "go.work: core from infra/$(V)"

clean: ## Stop and remove every instance's core clone and binaries
	@for i in $(INSTANCES); do $(MAKE) -s -C infra/$$i clean; done
	rm -f go.work go.work.sum
