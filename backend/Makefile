.PHONY: run build test vet fmt up down logs reseed env smoke

# Local dev: requires a running MySQL (see `make up` for one via Docker) and
# a .env file (run `make env`).
run:
	go run ./cmd/api

build:
	go build -o bin/api ./cmd/api

test:
	go test ./...

vet:
	go vet ./...

fmt:
	gofmt -l .

# --- Docker Compose (MySQL + API together) ---

# Creates backend/.env with random local secrets (never overwrites an existing one).
env:
	sh scripts/init-env.sh

up: env
	docker compose up --build -d
	@echo "API:    http://127.0.0.1:8080/api/v1/health"
	@echo "MySQL:  127.0.0.1:3307 (credentials in backend/.env)"

smoke:
	sh scripts/smoke.sh

down:
	docker compose down

logs:
	docker compose logs -f api

# Wipes the MySQL volume so db/init/*.sql reruns from scratch on next `up`.
# Use after editing 04-schema.sql or seed.sql during development.
reseed:
	docker compose down -v
	$(MAKE) up
