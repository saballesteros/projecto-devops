VENV := .venv
PYTHON := $(VENV)/bin/python
PIP := $(PYTHON) -m pip
PYTEST := $(PYTHON) -m pytest
DATABASE_URL ?= postgresql://postgres:postgres@localhost:5433/blacklist_db
STATIC_TOKEN ?= default-dev-token
ARTIFACT := blacklist-api-artifact.zip
DEPLOY_CMD ?= eb deploy

.PHONY: help setup test build deploy run clean .db-up FORCE

help:
	@echo "Etapas disponibles:"
	@echo "  make setup   - Crea .venv e instala dependencias"
	@echo "  make test    - Ejecuta pruebas unitarias"
	@echo "  make build   - Valida pruebas y genera $(ARTIFACT)"
	@echo "  make deploy  - Ejecuta build y despliega con DEPLOY_CMD='$(DEPLOY_CMD)'"
	@echo "  make run     - Levanta PostgreSQL y ejecuta la API localmente"
	@echo "  make clean   - Elimina caches y artefactos locales"

$(PYTHON):
	python -m venv $(VENV)

setup: $(PYTHON)
	$(PIP) install -r requirements.txt

test: setup
	$(PYTEST) tests/ -v --tb=short

build: test $(ARTIFACT)

deploy: build
	$(DEPLOY_CMD)

run: setup .db-up
	DATABASE_URL="$(DATABASE_URL)" STATIC_TOKEN="$(STATIC_TOKEN)" $(PYTHON) application.py

clean:
	find . -type d -name "__pycache__" -prune -exec rm -rf {} +
	rm -rf .pytest_cache $(ARTIFACT)

$(ARTIFACT): FORCE
	rm -f $(ARTIFACT)
	zip -r $(ARTIFACT) . \
		-x "*.git*" \
		-x "$(VENV)/*" \
		-x ".pytest_cache/*" \
		-x "__pycache__/*" \
		-x "*/__pycache__/*" \
		-x "tests/*" \
		-x ".ebignore" \
		-x ".gitignore" \
		-x "postman/*" \
		-x ".env*" \
		-x ".codex" \
		-x "instance/*" \
		-x "docker-compose.yml" \
		-x "$(ARTIFACT)"

.db-up:
	docker compose up -d db
	@echo "Esperando PostgreSQL..."
	@until docker compose exec -T db pg_isready -U postgres -d blacklist_db >/dev/null 2>&1; do sleep 1; done
	@echo "PostgreSQL listo en localhost:5433"
