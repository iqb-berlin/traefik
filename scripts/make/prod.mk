BASE_DIR := $(shell git rev-parse --show-toplevel)

## prevents collisions of make target names with possible file names
.PHONY: traefik-up traefik-down traefik-start traefik-stop traefik-status traefik-logs traefik-config\
	traefik-system-prune traefik-volumes-prune traefik-images-clean

## disables printing the recipe of a make target before executing it
.SILENT: traefik-images-clean

## Pull newest images, create and start docker containers
traefik-up:
	@if\
		! test -f $(BASE_DIR)/secrets/traefik/certificate.pem ||\
		! test -f $(BASE_DIR)/secrets/traefik/privkey.pem ||\
		! command openssl x509 -in $(BASE_DIR)/secrets/traefik/certificate.pem -text -noout >/dev/null 2>&1 ||\
		! command openssl rsa -in $(BASE_DIR)/secrets/traefik/privkey.pem -check >/dev/null 2>&1;\
				then\
					echo "===============================================";\
					echo "No SSL certificate and/or key available!";\
					echo "Generating a 1-day self-signed certificate ...";\
					openssl req\
							 -newkey rsa:2048 -nodes -subj "/CN=$(SERVER_NAME)"\
							 -keyout $(BASE_DIR)/secrets/traefik/privkey.pem\
							 -x509 -days 1 -out $(BASE_DIR)/secrets/traefik/certificate.pem;\
					echo "Self-signed 1-day certificate created.";\
					echo "===============================================";\
	fi
	docker compose\
			-f $(BASE_DIR)/docker-compose.traefik.yml\
			-f $(BASE_DIR)/docker-compose.traefik.prod.yml\
			--env-file $(BASE_DIR)/.env.traefik\
		pull
	docker compose\
			-f $(BASE_DIR)/docker-compose.traefik.yml\
			-f $(BASE_DIR)/docker-compose.traefik.prod.yml\
			--env-file $(BASE_DIR)/.env.traefik\
		up -d

## Stop and remove docker containers
traefik-down:
	docker compose\
			-f $(BASE_DIR)/docker-compose.traefik.yml\
			-f $(BASE_DIR)/docker-compose.traefik.prod.yml\
			--env-file $(BASE_DIR)/.env.traefik\
		down

## Start docker containers
# Param (optional): SERVICE - Start the specified service only, e.g. `make traefik-start SERVICE=grafana`
traefik-start:
	docker compose\
			-f $(BASE_DIR)/docker-compose.traefik.yml\
			-f $(BASE_DIR)/docker-compose.traefik.prod.yml\
			--env-file $(BASE_DIR)/.env.traefik\
		start $(SERVICE)

## Stop docker containers
traefik-stop:
	docker compose\
			-f $(BASE_DIR)/docker-compose.traefik.yml\
			-f $(BASE_DIR)/docker-compose.traefik.prod.yml\
			--env-file $(BASE_DIR)/.env.traefik\
		stop $(SERVICE)

## Show status of containers
# Param (optional): SERVICE - Show status of the specified service only, e.g. `make traefik-status SERVICE=grafana`
traefik-status:
	docker compose\
			-f $(BASE_DIR)/docker-compose.traefik.yml\
			-f $(BASE_DIR)/docker-compose.traefik.prod.yml\
			--env-file $(BASE_DIR)/.env.traefik\
		ps -a $(SERVICE)

## Show service logs
# Param (optional): SERVICE - Show log of the specified service only, e.g. `make traefik-logs SERVICE=grafana`
traefik-logs:
	docker compose\
			-f $(BASE_DIR)/docker-compose.traefik.yml\
			-f $(BASE_DIR)/docker-compose.traefik.prod.yml\
			--env-file $(BASE_DIR)/.env.traefik\
		logs -f $(SERVICE)

## Show services configuration
# Param (optional): SERVICE - Show config of the specified service only, e.g. `make traefik-config SERVICE=grafana`
traefik-config:
	docker compose\
			-f $(BASE_DIR)/docker-compose.traefik.yml\
			-f $(BASE_DIR)/docker-compose.traefik.prod.yml\
			--env-file $(BASE_DIR)/.env.traefik\
		config $(SERVICE)

## Remove unused dangling images, containers, networks, etc. Data volumes will stay untouched!
traefik-system-prune:
	docker system prune

## Remove all anonymous local volumes not used by at least one container.
traefik-volumes-prune:
	docker volume prune

## Remove all unused (not just dangling) images!
traefik-images-clean:
	if test "$(shell docker images -q grafana/grafana)"; then docker rmi $(shell docker images -q grafana/grafana); fi
	if test "$(shell docker images -q prom/prometheus)"; then docker rmi $(shell docker images -q prom/prometheus); fi
	if test "$(shell docker images -q traefik)"; then docker rmi $(shell docker images -q traefik); fi
