TRAEFIK_BASE_DIR := $(shell git rev-parse --show-toplevel)
TRAEFIK_IMAGE := $(shell docker compose --env-file $(TRAEFIK_BASE_DIR)/.env.dev config --images | grep traefik)
NGINX_IMAGE := $(shell docker compose --env-file $(TRAEFIK_BASE_DIR)/.env.dev config --images | grep nginx)
KEYCLOAK_IMAGE := $(shell docker compose --env-file $(TRAEFIK_BASE_DIR)/.env.dev config --images | grep keycloak)
POSTGRES_IMAGE := $(shell docker compose --env-file $(TRAEFIK_BASE_DIR)/.env.dev config --images | grep postgres)
OAUTH2_PROXY_IMAGE := $(shell docker compose --env-file $(TRAEFIK_BASE_DIR)/.env.dev config --images | grep oauth2-proxy | head -1)
GRAFANA_IMAGE := $(shell docker compose --env-file $(TRAEFIK_BASE_DIR)/.env.dev config --images | grep grafana)
PROMETHEUS_IMAGE := $(shell docker compose --env-file $(TRAEFIK_BASE_DIR)/.env.dev config --images | grep prometheus)
NODE_EXPORTER_IMAGE := $(shell docker compose --env-file $(TRAEFIK_BASE_DIR)/.env.dev config --images | grep node-exporter)
CADVISOR_IMAGE := $(shell docker compose --env-file $(TRAEFIK_BASE_DIR)/.env.dev config --images | grep cadvisor)
DOZZLE_IMAGE := $(shell docker compose --env-file $(TRAEFIK_BASE_DIR)/.env.dev config --images | grep dozzle)
TRIVY_VERSION := aquasec/trivy:latest

include $(TRAEFIK_BASE_DIR)/.env.dev

## exports all variables (especially those of the included .env.dev file!)
.EXPORT_ALL_VARIABLES:

## prevents collisions of make target names with possible file names
.PHONY: scan-all scan-traefik scan-nginx scan-keycloak scan-postgres scan-oauth2-proxy scan-grafana scan-prometheus\
	scan-node-exporter scan-cadvisor scan-dozzle

## scans infrastructure images for security vulnerabilities
scan-all: scan-traefik scan-nginx scan-keycloak scan-postgres scan-oauth2-proxy scan-grafana scan-prometheus\
	scan-node-exporter scan-cadvisor scan-dozzle

## scans traefik image for security vulnerabilities
scan-traefik:
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION) --version
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image --download-db-only --no-progress --timeout 30m0s
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image\
					--scanners vuln\
					--ignore-unfixed\
					--severity CRITICAL\
				$(TRAEFIK_IMAGE)

## scans nginx image for security vulnerabilities
scan-nginx:
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION) --version
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image --download-db-only --no-progress --timeout 30m0s
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image\
					--scanners vuln\
					--ignore-unfixed\
					--severity CRITICAL\
				$(NGINX_IMAGE)

## scans keycloak image for security vulnerabilities
scan-keycloak:
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION) --version
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image --download-db-only --no-progress --timeout 30m0s
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image\
					--scanners vuln\
					--ignore-unfixed\
					--severity CRITICAL\
				$(KEYCLOAK_IMAGE)

## scans postgres image for security vulnerabilities
scan-postgres:
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION) --version
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image --download-db-only --no-progress --timeout 30m0s
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image\
					--scanners vuln\
					--ignore-unfixed\
					--severity CRITICAL\
				$(POSTGRES_IMAGE)

## scans oauth2-proxy image for security vulnerabilities
scan-oauth2-proxy:
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION) --version
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image --download-db-only --no-progress --timeout 30m0s
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image\
					--scanners vuln\
					--ignore-unfixed\
					--severity CRITICAL\
				$(OAUTH2_PROXY_IMAGE)


## scans grafana image for security vulnerabilities
scan-grafana:
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION) --version
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image --download-db-only --no-progress --timeout 30m0s
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image\
					--scanners vuln\
					--ignore-unfixed\
					--severity CRITICAL\
				$(GRAFANA_IMAGE)

## scans prometheus image for security vulnerabilities
scan-prometheus:
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION) --version
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image --download-db-only --no-progress --timeout 30m0s
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image\
					--scanners vuln\
					--ignore-unfixed\
					--severity CRITICAL\
				$(PROMETHEUS_IMAGE)

## scans node-exporter image for security vulnerabilities
scan-node-exporter:
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION) --version
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image --download-db-only --no-progress --timeout 30m0s
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image\
					--scanners vuln\
					--ignore-unfixed\
					--severity CRITICAL\
				$(NODE_EXPORTER_IMAGE)

## scans cadvisor image for security vulnerabilities
scan-cadvisor:
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION) --version
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image --download-db-only --no-progress --timeout 30m0s
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image\
					--scanners vuln\
					--ignore-unfixed\
					--severity CRITICAL\
				$(CADVISOR_IMAGE)

## scans dozzle image for security vulnerabilities
scan-dozzle:
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION) --version
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image --download-db-only --no-progress --timeout 30m0s
	docker run\
			--rm\
			--volume /var/run/docker.sock:/var/run/docker.sock\
			--volume ${HOME}/Library/Caches:/root/.cache/\
		$(TRIVY_VERSION)\
			image\
					--scanners vuln\
					--ignore-unfixed\
					--severity CRITICAL\
				$(DOZZLE_IMAGE)
