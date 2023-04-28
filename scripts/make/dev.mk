BASE_DIR := $(shell git rev-parse --show-toplevel)

## prevents collisions of make target names with possible file names
.PHONY: dev-up dev-down dev-start dev-stop dev-status dev-logs dev-config dev-system-prune dev-volumes-prune\
	dev-volumes-clean dev-images-clean dev-clean-all

## disables printing the recipe of a make target before executing it
.SILENT: dev-volumes-clean dev-images-clean

## Create and start all docker containers
dev-up:
	docker compose --env-file $(BASE_DIR)/.env.dev up -d

## Stop and remove all docker containers, preserve data volumes
dev-down:
	docker compose --env-file $(BASE_DIR)/.env.dev down

## Start docker containers
# Param (optional): SERVICE - Start the specified service only, e.g. `make dev-start SERVICE=grafana`
dev-start:
	docker compose --env-file $(BASE_DIR)/.env.dev start $(SERVICE)

## Stop docker containers
# Param (optional): SERVICE - Stop the specified service only, e.g. `make dev-stop SERVICE=grafana`
dev-stop:
	docker compose --env-file $(BASE_DIR)/.env.dev stop $(SERVICE)

## Show status of containers
# Param (optional): SERVICE - Show status of the specified service only, e.g. `make dev-status SERVICE=grafana`
dev-status:
	docker compose --env-file $(BASE_DIR)/.env.dev ps -a $(SERVICE)

## Show service logs
# Param (optional): SERVICE - Show log of the specified service only, e.g. `make dev-logs SERVICE=grafana`
dev-logs:
	docker compose --env-file $(BASE_DIR)/.env.dev logs -f $(SERVICE)

## Show services configuration
# Param (optional): SERVICE - Show config of the specified service only, e.g. `make dev-config SERVICE=grafana`
dev-config:
	docker compose --env-file $(BASE_DIR)/.env.dev config $(SERVICE)

## Remove all stopped containers, all unused networks, all dangling images, and all dangling cache
dev-system-prune:
	docker system prune

## Remove all anonymous local volumes not used by at least one container.
dev-volumes-prune:
	docker volume prune

## Remove all unused data volumes
# Be very careful, all data could be lost!!!
dev-volumes-clean:
	if test "$(shell docker volume ls -f name=grafana -f name=prometheus -q)";\
		then docker volume rm $(shell docker volume ls -f name=grafana -f name=prometheus -q);\
	fi

## Remove all unused (not just dangling) images!
dev-images-clean:
	if test "$(shell docker images -q grafana/grafana)"; then docker rmi $(shell docker images -q grafana/grafana); fi
	if test "$(shell docker images -q prom/prometheus)"; then docker rmi $(shell docker images -q prom/prometheus); fi
	if test "$(shell docker images -q traefik)"; then docker rmi $(shell docker images -q traefik); fi

## Remove all unused data volumes, images, containers, networks, and cache.
# Be careful, it cleans all!
dev-clean-all:
	docker system prune --all --volumes
