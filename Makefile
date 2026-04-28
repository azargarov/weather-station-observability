SHELL := /bin/bash

.DEFAULT_GOAL := help

COMPOSE := docker compose
PROM_IMAGE := prom/prometheus

ENV_FILE := .env
SECRETS_DIR := secrets
PVE_SECRET_FILE := $(SECRETS_DIR)/pve_token_value

TEMPLATES_DIR := templates
GENERATED_DIR := generated

PROM_SOURCE_CONFIG := prometheus/prometheus.yml
PROM_SOURCE_RULES_DIR := prometheus/rules

PROM_GENERATED_DIR := $(GENERATED_DIR)/prometheus
PROM_CONFIG := $(PROM_GENERATED_DIR)/prometheus.yml
PROM_RULES_DIR := $(PROM_GENERATED_DIR)/rules
PROM_TARGETS_DIR := $(PROM_GENERATED_DIR)/targets

GRAFANA_DIR := grafana

PROM_CONTAINER_CONFIG := /etc/prometheus/prometheus.yml
PROM_CONTAINER_RULES := /etc/prometheus/rules
PROM_CONTAINER_TARGETS := /etc/prometheus/targets

RULE_FILES := $(wildcard $(PROM_RULES_DIR)/*.yml)

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make init                Create local .env and secrets placeholders"
	@echo "  make render              Generate runtime configs from templates"
	@echo "  make up                  Render, validate, and start the stack"
	@echo "  make down                Stop the stack"
	@echo "  make restart             Restart the stack"
	@echo "  make ps                  Show containers"
	@echo "  make logs                Follow all logs"
	@echo "  make logs-prometheus     Follow Prometheus logs"
	@echo "  make logs-grafana        Follow Grafana logs"
	@echo "  make check-config        Validate generated prometheus.yml"
	@echo "  make check-rules         Validate generated Prometheus rule files"
	@echo "  make check               Render and run all validation"
	@echo "  make reload-prometheus   Reload Prometheus config"
	@echo "  make targets             Show active scrape targets URL"
	@echo "  make clean               Stop stack and remove volumes"
	@echo "  make clean-generated     Remove generated local configs"
	@echo "  make secret-scan         Search tracked files for obvious secrets"

.PHONY: init
init:
	@if [ ! -f "$(ENV_FILE)" ]; then \
	  cp .env.example "$(ENV_FILE)"; \
	  echo "Created $(ENV_FILE) from .env.example"; \
	else \
	  echo "$(ENV_FILE) already exists"; \
	fi
	@mkdir -p "$(SECRETS_DIR)"
	@if [ ! -f "$(PVE_SECRET_FILE)" ]; then \
	  printf '%s\n' 'REPLACE_WITH_REAL_PVE_TOKEN_VALUE' > "$(PVE_SECRET_FILE)"; \
	  chmod 600 "$(PVE_SECRET_FILE)"; \
	  echo "Created $(PVE_SECRET_FILE)"; \
	else \
	  echo "$(PVE_SECRET_FILE) already exists"; \
	fi

.PHONY: ensure-local-config
ensure-local-config:
	@test -f "$(ENV_FILE)" || { echo "Missing $(ENV_FILE). Run: make init"; exit 1; }
	@test -f "$(PVE_SECRET_FILE)" || { echo "Missing $(PVE_SECRET_FILE). Run: make init"; exit 1; }

.PHONY: render
render: ensure-local-config
	./scripts/render-config.sh

.PHONY: up
up: render check-config check-rules
	$(COMPOSE) up -d

.PHONY: down
down:
	$(COMPOSE) down

.PHONY: clean
clean:
	$(COMPOSE) down -v --remove-orphans
	docker volume prune -f

.PHONY: clean-generated
clean-generated:
	rm -rf "$(GENERATED_DIR)"

.PHONY: restart
restart: down up

.PHONY: ps
ps:
	$(COMPOSE) ps

.PHONY: logs
logs:
	$(COMPOSE) logs -f

.PHONY: logs-prometheus
logs-prometheus:
	$(COMPOSE) logs -f prometheus

.PHONY: logs-grafana
logs-grafana:
	$(COMPOSE) logs -f grafana

.PHONY: check-config
check-config: render
	docker run --rm \
	  --entrypoint /bin/promtool \
	  -v "$(PWD)/$(PROM_CONFIG):$(PROM_CONTAINER_CONFIG):ro" \
	  -v "$(PWD)/$(PROM_RULES_DIR):$(PROM_CONTAINER_RULES):ro" \
	  -v "$(PWD)/$(PROM_TARGETS_DIR):$(PROM_CONTAINER_TARGETS):ro" \
	  $(PROM_IMAGE) \
	  check config $(PROM_CONTAINER_CONFIG)

.PHONY: check-rules
check-rules: render
	@files="$$(find "$(PROM_RULES_DIR)" -type f -name '*.yml' 2>/dev/null)"; \
	if [ -z "$$files" ]; then \
	  echo "No rule files found in $(PROM_RULES_DIR)"; \
	  exit 1; \
	fi; \
	for file in $$files; do \
	  echo "Checking $$file"; \
	  docker run --rm \
	    --entrypoint /bin/promtool \
	    -v "$(PWD)/$(PROM_RULES_DIR):$(PROM_CONTAINER_RULES):ro" \
	    $(PROM_IMAGE) \
	    check rules "$(PROM_CONTAINER_RULES)/$$(basename "$$file")" || exit 1; \
	done

.PHONY: check
check: render check-config check-rules

.PHONY: reload-prometheus
reload-prometheus:
	curl -X POST http://localhost:9090/-/reload

.PHONY: targets
targets:
	@echo "Prometheus targets:"
	@echo "  http://localhost:9090/targets"

