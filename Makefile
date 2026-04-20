VENV := .venv
PYTHON := $(VENV)/bin/python
PIP := $(PYTHON) -m pip
PYTEST := $(PYTHON) -m pytest
DATABASE_URL ?= postgresql://postgres:postgres@localhost:5433/blacklist_db
STATIC_TOKEN ?= default-dev-token

.PHONY: help venv install test db-up db-down run run-sqlite clean

help:
	@echo "Comandos disponibles:"
	@echo "  make install  - Crea .venv e instala dependencias dentro del entorno virtual"
	@echo "  make test     - Ejecuta pruebas con pytest usando .venv"
	@echo "  make db-up    - Levanta PostgreSQL con Docker"
	@echo "  make db-down  - Detiene PostgreSQL con Docker"
	@echo "  make run      - Levanta PostgreSQL y ejecuta la aplicacion usando .venv"
	@echo "  make run-sqlite - Ejecuta la aplicacion con SQLite local, sin Docker"
	@echo "  make clean    - Elimina caches de Python y pytest"

$(PYTHON):
	python -m venv $(VENV)

venv: $(PYTHON)

install: venv
	$(PIP) install -r requirements.txt

test: venv
	$(PYTEST) tests/ -v --tb=short

db-up:
	docker compose up -d db
	@echo "Esperando PostgreSQL..."
	@until docker compose exec -T db pg_isready -U postgres -d blacklist_db >/dev/null 2>&1; do sleep 1; done
	@echo "PostgreSQL listo en localhost:5433"

db-down:
	docker compose down

run: venv db-up
	DATABASE_URL="$(DATABASE_URL)" STATIC_TOKEN="$(STATIC_TOKEN)" $(PYTHON) application.py

run-sqlite: venv
	DATABASE_URL="sqlite:///local.db" STATIC_TOKEN="$(STATIC_TOKEN)" $(PYTHON) application.py

clean:
	find . -type d -name "__pycache__" -prune -exec rm -rf {} +
	rm -rf .pytest_cache
