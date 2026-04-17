# IQB Traefik Infrastructure

Docker-based edge and monitoring stack for IQB services. The project combines routing, identity, and observability components and provides make targets for development, production operation, maintenance, and updates.

## What This Project Provides

This repository orchestrates the following platform services:

- `traefik` as edge router and dashboard
- `keycloak` + `postgres` as identity provider and persistence
- `oauth2-proxy` sidecars for protected service access (production)
- `grafana` for dashboards
- `prometheus` + exporters (`node-exporter`, `cadvisor`) for metrics
- `dozzle` for container log inspection
- `maintenance-page` fallback page for unavailable upstreams

## Architecture At A Glance

Two runtime modes are supported:

- Development mode (`.env.dev`): HTTP-focused, simplified routing for local use
- Traefik/production mode (`.env.traefik`): TLS, domain-based routing, OAuth2-protected endpoints

Core compose files:

- `docker-compose.yaml`: base services
- `docker-compose.override.yaml`: development-specific labels and settings
- `docker-compose.traefik.prod.yaml`: production TLS and OAuth2 proxy setup
- `docker-compose.traefik.yaml`: symlink to `docker-compose.yaml`

## Prerequisites

Required:

- Docker Engine
- Docker Compose v2 plugin (`docker compose`)

Recommended:

- GNU Make (for the provided command wrapper targets)

## Quick Start (Development)

1. Review `.env.dev` and adapt ports/credentials if required.
2. Start the stack:

```bash
make dev-up
```

3. Check status/logs:

```bash
make dev-status
make dev-logs
```

4. Stop and remove containers:

```bash
make dev-down
```

### Typical Local URLs

With default `.env.dev` values (`SERVER_NAME=localhost`, `HTTP_PORT=4200`, `TRAEFIK_PORT=80`):

- `http://traefik.localhost` (Traefik dashboard)
- `http://keycloak.localhost:4200`
- `http://grafana.localhost:4200`
- `http://prometheus.localhost:4200`
- `http://node-exporter.localhost:4200`
- `http://cadvisor.localhost:4200`
- `http://dozzle.localhost:4200`

Note: host-based routing is used. If your environment does not resolve `*.localhost` automatically, add matching host entries.

## Quick Start (Traefik / Production Mode)

1. Create the production environment file from template:

```bash
cp .env.traefik.template .env.traefik
```

2. Edit `.env.traefik` and set at least:

- `SERVER_NAME`
- `HTTP_PORT`, `HTTPS_PORT`
- admin and database credentials
- OAuth2 client secrets
- TLS options (`TLS_CERTIFICATE_RESOLVER`, ACME settings if used)

3. Start the stack:

```bash
make traefik-up
```

4. Inspect status/logs:

```bash
make traefik-status
make traefik-logs
```

5. Stop/remove containers:

```bash
make traefik-down
```

### TLS Behavior

- If `TLS_CERTIFICATE_RESOLVER=acme`, Traefik uses ACME settings from `.env.traefik`.
- If no valid certificate/key is present for manual mode, `make traefik-up` generates a short-lived self-signed certificate in `secrets/traefik/certs/`.

## Most Important Make Targets

### Development Targets

- `make dev-up` / `make dev-down`
- `make dev-start SERVICE=<name>`
- `make dev-stop SERVICE=<name>`
- `make dev-status [SERVICE=<name>]`
- `make dev-logs [SERVICE=<name>]`
- `make dev-config [SERVICE=<name>]`

### Production/Traefik Targets

- `make traefik-up` / `make traefik-down`
- `make traefik-start SERVICE=<name>`
- `make traefik-stop SERVICE=<name>`
- `make traefik-status [SERVICE=<name>]`
- `make traefik-logs [SERVICE=<name>]`
- `make traefik-config [SERVICE=<name>]`

### Database & Realm Operations

- `make traefik-connect-keycloak-db`
- `make traefik-dump-keycloak-db`
- `make traefik-restore-keycloak-db`
- `make traefik-dump-keycloak-db-server`
- `make traefik-restore-keycloak-db-server`
- `make traefik-export-keycloak-realm [REALM=<realm>]`
- `make traefik-import-keycloak-realm`

### Maintenance / Cleanup

- `make dev-system-prune`, `make traefik-system-prune`
- `make dev-volumes-prune`, `make traefik-volumes-prune`
- `make dev-images-clean`, `make traefik-images-clean`
- `make dev-clean-all` (destructive cleanup)

### Quality & Security

- `make lint-all`
- `make scan-all` (Trivy image scans)

## Update Workflow

To run the update procedure for a deployed installation:

```bash
make traefik-update
```

The update script (`scripts/update.sh`) supports release selection, optional backups, and migration scripts where available.

## Relevant Directories

- `config/`: service-specific configuration (Traefik, Prometheus, Grafana, Keycloak)
- `secrets/`: certificate material
- `backup/`: dumps and release backups
- `scripts/make/`: task implementation (`dev.mk`, `prod.mk`, `lint.mk`, `scan.mk`)
- `scripts/migration/`: version migration scripts

## Troubleshooting

- Port conflicts: adapt ports in `.env.dev` or `.env.traefik`.
- Routing does not work: verify `SERVER_NAME` and DNS/host resolution.
- TLS problems: verify resolver settings and certificate files under `secrets/traefik/certs/`.
- OAuth login issues: verify Keycloak realm import and OAuth client values in `.env.traefik`.
