# Traefik - IQB Application Infrastructure
The IQB Application Infrastructure Project, named after its main component, Traefik (https://doc.traefik.io/traefik/),
consists of an edge router, an identity provider, monitoring components, and a maintenance page web server as fallback
for unavailable services.

It provides make targets for development, production operation, maintenance, and updates.

## What This Project Provides

This repository orchestrates the following platform services:

- `traefik` as edge router and dashboard
- `keycloak` + `postgres` as identity provider and persistence
- `oauth2-proxy` sidecars for protected service access (production)
- `grafana` for dashboards
- `prometheus`, `node-exporter`and `cadvisor` for metrics
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
- `docker-compose.traefik.yaml`: production symlink to `docker-compose.yaml`

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
- `http://keycloak.localhost`
- `http://grafana.localhost`
- `http://prometheus.localhost`
- `http://node-exporter.localhost`
- `http://cadvisor.localhost`
- `http://dozzle.localhost`

Note: host-based routing is used. If your environment does not resolve `*.localhost` automatically, add matching host entries.

## Quick Start (Traefik / Production Mode)

1. Use install script of the preferred release to create the production environment.
```bash
wget https://github.com/iqb-berlin/traefik/releases/download/<RELEASE>/install.sh
bash install.sh
```

2. Follow the instructions in the installation script and adjust the values of individual environment variables as needed.


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

#### Standard Operations
- `make dev-up [SERVICE=<name>]`
- `make dev-down [SERVICE=<name>]`
- `make dev-start [SERVICE=<name>]`
- `make dev-stop [SERVICE=<name>]`
- `make dev-status [SERVICE=<name>]`
- `make dev-logs [SERVICE=<name>]`
- `make dev-config [SERVICE=<name>]`


#### Maintenance / Cleanup
- `make dev-system-prune`
- `make dev-volumes-prune`
- `make dev-images-clean`
- `make dev-clean-all` (destructive cleanup)


#### Quality & Security
- `make lint-all`
- `make scan-all` (Trivy image scans)


### Production/Traefik Targets

#### Standard Operations
- `make traefik-up [SERVICE=<name>]`
- `make traefik-down [SERVICE=<name>]`
- `make traefik-start [SERVICE=<name>]`
- `make traefik-stop [SERVICE=<name>]`
- `make traefik-status [SERVICE=<name>]`
- `make traefik-logs [SERVICE=<name>]`
- `make traefik-config [SERVICE=<name>]`


#### Database & Realm Operations
- `make traefik-connect-keycloak-db`
- `make traefik-dump-keycloak-db`
- `make traefik-restore-keycloak-db`
- `make traefik-dump-keycloak-db-server`
- `make traefik-restore-keycloak-db-server`
- `make traefik-export-keycloak-realm [REALM=<name>]`
- `make traefik-import-keycloak-realm`


#### Maintenance / Cleanup
- `make traefik-system-prune`
- `make traefik-volumes-prune`
- `make traefik-images-clean`


#### Update Workflow
To run the update procedure for a deployed installation:

```bash
make traefik-update
```

The update script (`scripts/update.sh`) supports release selection, optional backups, and migration scripts where available.


## Relevant Directories

- `config/`: service-specific configuration (Traefik, Prometheus, Grafana, Keycloak)
- `secrets/`: certificate material
- `backup/`: dumps and release backups
- `scripts/make/`: task implementation
- `scripts/migration/`: version migration scripts

## Troubleshooting

- Port conflicts: adapt ports in `.env.dev` or `.env.traefik`.
- Routing does not work: verify `SERVER_NAME` and DNS/host resolution.
- TLS problems: verify resolver settings and certificate files under `secrets/traefik/certs/`.
- OAuth login issues: verify Keycloak realm import and OAuth client values in `.env.traefik`.
