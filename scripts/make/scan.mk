BASE_DIR := $(shell git rev-parse --show-toplevel)
TRAEFIK_IMAGE := $(shell docker compose --env-file $(BASE_DIR)/.env.dev config --images | grep traefik)
PROMETHEUS_IMAGE := $(shell docker compose --env-file $(BASE_DIR)/.env.dev config --images | grep prometheus)
GRAFANA_IMAGE := $(shell docker compose --env-file $(BASE_DIR)/.env.dev config --images | grep grafana)
TRIVY_VERSION := aquasec/trivy:0.41.0

include $(BASE_DIR)/.env.dev

## exports all variables (especially those of the included .env.prod file!)
.EXPORT_ALL_VARIABLES:

## prevents collisions of make target names with possible file names
.PHONY: scan-all scan-traefik scan-prometheus scan-grafana

## scans infrastructure images for security vulnerabilities
scan-all: scan-traefik scan-prometheus scan-grafana

## scans traefik image for security vulnerabilities
scan-traefik:
	docker run\
		--rm -v /var/run/docker.sock:/var/run/docker.sock -v ${HOME}/Library/Caches:/root/.cache/\
	  $(TRIVY_VERSION) image\
	  	--scanners vuln --ignore-unfixed --severity CRITICAL\
	  $(TRAEFIK_IMAGE)

## scans prometheus image for security vulnerabilities
scan-prometheus:
	docker run\
		--rm -v /var/run/docker.sock:/var/run/docker.sock -v ${HOME}/Library/Caches:/root/.cache/\
	  $(TRIVY_VERSION) image\
	  	--scanners vuln --ignore-unfixed --severity CRITICAL\
	  $(PROMETHEUS_IMAGE)

## scans grafana image for security vulnerabilities
scan-grafana:
	docker run\
		--rm -v /var/run/docker.sock:/var/run/docker.sock -v ${HOME}/Library/Caches:/root/.cache/\
	  $(TRIVY_VERSION) image\
	  	--scanners vuln --ignore-unfixed --severity CRITICAL\
	  $(GRAFANA_IMAGE)
