BASE_DIR := $(shell git rev-parse --show-toplevel)

include $(BASE_DIR)/.env.prod

## exports all variables (especially those of the included .env.prod file!)
.EXPORT_ALL_VARIABLES:

## prevents collisions of make target names with possible file names
.PHONY: prod-ramp-up prod-shut-down prod-start prod-stop prod-status prod-logs prod-config prod-system-prune\
	prod-volumes-prune prod-images-clean

## disables printing the recipe of a make target before executing it
.SILENT: prod-images-clean

## Pull newest images, create and start docker containers
prod-ramp-up:
	@if\
		! test -f $(BASE_DIR)/secrets/traefik/studio-lite.crt ||\
		! test -f $(BASE_DIR)/secrets/traefik/studio-lite.key ||\
		! command openssl x509 -in $(BASE_DIR)/secrets/traefik/studio-lite.crt -text -noout >/dev/null 2>&1 ||\
		! command openssl rsa -in $(BASE_DIR)/secrets/traefik/studio-lite.key -check >/dev/null 2>&1;\
				then\
					echo "===============================================";\
					echo "No SSL certificate and/or key available!";\
					echo "Generating a 1-day self-signed certificate ...";\
					openssl req\
							 -newkey rsa:2048 -nodes -subj "/CN=$(SERVER_NAME)"\
							 -keyout $(BASE_DIR)/secrets/traefik/studio-lite.key\
							 -x509 -days 1 -out $(BASE_DIR)/secrets/traefik/studio-lite.crt;\
					echo "Self-signed 1-day certificate created.";\
					echo "===============================================";\
	fi
	docker compose\
			-f $(BASE_DIR)/docker-compose.yml\
			-f $(BASE_DIR)/docker-compose.prod.yml\
			--env-file $(BASE_DIR)/.env.prod\
		pull
	docker compose\
			-f $(BASE_DIR)/docker-compose.yml\
			-f $(BASE_DIR)/docker-compose.prod.yml\
			--env-file $(BASE_DIR)/.env.prod\
		up -d

## Stop and remove docker containers
prod-shut-down:
	docker compose\
  		-f $(BASE_DIR)/docker-compose.yml\
  		-f $(BASE_DIR)/docker-compose.prod.yml\
  		--env-file $(BASE_DIR)/.env.prod\
  	down

## Start docker containers
# Param (optional): SERVICE - Start the specified service only, e.g. `make prod-start SERVICE=grafana`
prod-start:
	docker compose\
			-f $(BASE_DIR)/docker-compose.yml\
			-f $(BASE_DIR)/docker-compose.prod.yml\
		 	--env-file $(BASE_DIR)/.env.prod\
		start $(SERVICE)

## Stop docker containers
prod-stop:
	docker compose\
			-f $(BASE_DIR)/docker-compose.yml\
			-f $(BASE_DIR)/docker-compose.prod.yml\
		 	--env-file $(BASE_DIR)/.env.prod\
		stop $(SERVICE)

## Show status of containers
# Param (optional): SERVICE - Show status of the specified service only, e.g. `make prod-status SERVICE=grafana`
prod-status:
	docker compose\
			-f $(BASE_DIR)/docker-compose.yml\
			-f $(BASE_DIR)/docker-compose.prod.yml\
		 	--env-file $(BASE_DIR)/.env.prod\
		ps -a $(SERVICE)

## Show service logs
# Param (optional): SERVICE - Show log of the specified service only, e.g. `make prod-logs SERVICE=grafana`
prod-logs:
	docker compose\
			-f $(BASE_DIR)/docker-compose.yml\
			-f $(BASE_DIR)/docker-compose.prod.yml\
		 	--env-file $(BASE_DIR)/.env.prod\
		logs -f $(SERVICE)

## Show services configuration
# Param (optional): SERVICE - Show config of the specified service only, e.g. `make prod-config SERVICE=grafana`
prod-config:
	docker compose\
			-f $(BASE_DIR)/docker-compose.yml\
			-f $(BASE_DIR)/docker-compose.prod.yml\
			--env-file $(BASE_DIR)/.env.prod\
		config $(SERVICE)

## Remove unused dangling images, containers, networks, etc. Data volumes will stay untouched!
prod-system-prune:
	docker system prune

## Remove all anonymous local volumes not used by at least one container.
prod-volumes-prune:
	docker volume prune

## Remove all unused (not just dangling) images!
prod-images-clean:
	if test "$(shell docker images -q grafana/grafana)"; then docker rmi $(shell docker images -q grafana/grafana); fi
	if test "$(shell docker images -q prom/prometheus)"; then docker rmi $(shell docker images -q prom/prometheus); fi
	if test "$(shell docker images -q traefik)"; then docker rmi $(shell docker images -q traefik); fi
