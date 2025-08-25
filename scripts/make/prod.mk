TRAEFIK_BASE_DIR := $(shell git rev-parse --show-toplevel)
REALM := monitoring

include $(TRAEFIK_BASE_DIR)/.env.traefik

# exports all variables (especially those of the included .env.traefik file!)
.EXPORT_ALL_VARIABLES:

# prevents collisions of make target names with possible file names
.PHONY: traefik-up traefik-down traefik-start traefik-stop traefik-status traefik-logs traefik-config\
	traefik-system-prune traefik-volumes-prune traefik-images-clean traefik-connect-keycloak-db\
	traefik-dump-keycloak-db-server traefik-restore-keycloak-db-server traefik-dump-keycloak-db\
	traefik-restore-keycloak-db traefik-export-keycloak-realm traefik-import-keycloak-realm traefik-update

# disables printing the recipe of a make target before executing it
.SILENT: traefik-images-clean

# Pull newest images, create and start docker containers
traefik-up:
	@if\
		! test -f $(TRAEFIK_BASE_DIR)/secrets/traefik/certs/certificate.pem ||\
		! test -f $(TRAEFIK_BASE_DIR)/secrets/traefik/certs/private_key.pem ||\
		! command openssl x509 -in $(TRAEFIK_BASE_DIR)/secrets/traefik/certs/certificate.pem -text -noout >/dev/null 2>&1 ||\
		! command openssl rsa -in $(TRAEFIK_BASE_DIR)/secrets/traefik/certs/private_key.pem -check >/dev/null 2>&1;\
				then\
					echo "===============================================";\
					echo "No SSL certificate and/or key available!";\
					echo "Generating a 1-day self-signed certificate ...";\
					openssl req\
							 -newkey rsa:2048 -nodes -subj "/CN=$(SERVER_NAME)"\
							 -keyout $(TRAEFIK_BASE_DIR)/secrets/traefik/certs/private_key.pem\
							 -x509 -days 1 -out $(TRAEFIK_BASE_DIR)/secrets/traefik/certs/certificate.pem;\
					echo "Self-signed 1-day certificate created.";\
					echo "===============================================";\
	fi
	docker compose\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
		pull
	docker compose\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
		up -d

# Stop and remove docker containers
traefik-down:
	docker compose\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
		down

# Start docker containers
## Param (optional): SERVICE - Start the specified service only, e.g. `make traefik-start SERVICE=grafana`
traefik-start:
	docker compose\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
		start $(SERVICE)

# Stop docker containers
traefik-stop:
	docker compose\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
		stop $(SERVICE)

# Show status of containers
## Param (optional): SERVICE - Show status of the specified service only, e.g. `make traefik-status SERVICE=grafana`
traefik-status:
	docker compose\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
		ps -a $(SERVICE)

# Show service logs
## Param (optional): SERVICE - Show log of the specified service only, e.g. `make traefik-logs SERVICE=grafana`
traefik-logs:
	docker compose\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
		logs -f $(SERVICE)

# Show services configuration
## Param (optional): SERVICE - Show config of the specified service only, e.g. `make traefik-config SERVICE=grafana`
traefik-config:
	docker compose\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			-f $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
		config $(SERVICE)

# Remove unused dangling images, containers, networks, etc. Data volumes will stay untouched!
traefik-system-prune:
	docker system prune

# Remove all anonymous local volumes not used by at least one container.
traefik-volumes-prune:
	docker volume prune

# Remove all unused (not just dangling) images!
traefik-images-clean:
	if test "$(shell docker images -f reference=postgres -q)"; then docker rmi $(shell docker images -f reference=postgres -q); fi
	if test "$(shell docker images -f reference=*/keycloak -q)"; then docker rmi $(shell docker images -f reference=*/keycloak -q); fi
	if test "$(shell docker images -f reference=*/dozzle -q)"; then docker rmi $(shell docker images -f reference=*/dozzle -q); fi
	if test "$(shell docker images -f reference=*/cadvisor -q)"; then docker rmi $(shell docker images -f reference=*/cadvisor -q); fi
	if test "$(shell docker images -f reference=*/node-exporter -q)"; then docker rmi $(shell docker images -f reference=*/node-exporter -q); fi
	if test "$(shell docker images -f reference=*/prometheus -q)"; then docker rmi $(shell docker images -f reference=*/prometheus -q); fi
	if test "$(shell docker images -f reference=*/grafana -q)"; then docker rmi $(shell docker images -f reference=*/grafana -q); fi
	if test "$(shell docker images -f reference=nginx -q)"; then docker rmi $(shell docker images -f reference=nginx -q); fi
	if test "$(shell docker images -f reference=traefik -q)"; then docker rmi $(shell docker images -f reference=traefik -q); fi

# Open keycloak-db console
traefik-connect-keycloak-db: .EXPORT_ALL_VARIABLES
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		up -d keycloak-db
	sleep 5 ## wait until keycloak-db startup is completed
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		exec -it keycloak-db\
			psql --username=$(POSTGRES_USER) --dbname=$(POSTGRES_DB)

# Extract a database cluster into a script file
## (https://www.postgresql.org/docs/current/app-pg-dumpall.html)
traefik-dump-keycloak-db-server: .EXPORT_ALL_VARIABLES
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		up -d keycloak-db
	sleep 5 ## wait until keycloak-db startup is completed
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		exec -it keycloak-db\
			pg_dumpall --verbose --username=$(POSTGRES_USER) > $(TRAEFIK_BASE_DIR)/backup/temp/all.sql

# PostgreSQL interactive terminal reads commands from the dump file all.sql
## (https://www.postgresql.org/docs/14/app-psql.html)
## Before restoring, delete the keycloak-db volume and any existing block storage.
traefik-restore-keycloak-db-server: .EXPORT_ALL_VARIABLES
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		up -d keycloak-db
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		cp $(TRAEFIK_BASE_DIR)/backup/temp/all.sql keycloak-db:/tmp/
	sleep 10	## wait until file upload is completed
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		exec -it keycloak-db\
			psql --username=$(POSTGRES_USER) --file=/tmp/all.sql postgres

# Extract a database into a script file or other archive file
## (https://www.postgresql.org/docs/current/app-pgdump.html)
traefik-dump-keycloak-db: .EXPORT_ALL_VARIABLES
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		up -d keycloak-db
	sleep 5 ## wait until keycloak-db startup is completed
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		exec -it keycloak-db\
			pg_dump\
					--verbose\
					--username=$(POSTGRES_USER)\
					--format=c\
				$(POSTGRES_DB) > $(TRAEFIK_BASE_DIR)/backup/temp/$(POSTGRES_DB)_dump

# Restore a database from an archive file created by pg_dump
## (https://www.postgresql.org/docs/current/app-pgrestore.html)
traefik-restore-keycloak-db: .EXPORT_ALL_VARIABLES
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		up -d keycloak-db
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		cp $(TRAEFIK_BASE_DIR)/backup/temp/$(POSTGRES_DB)_dump keycloak-db:/tmp/
	sleep 10	## wait until file upload is completed
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		exec -it keycloak-db\
			pg_restore\
					--verbose\
					--single-transaction\
					--username=$(POSTGRES_USER)\
					--dbname=$(POSTGRES_DB)\
					--clean\
					--if-exists\
				/tmp/$(POSTGRES_DB)_dump

# Exports keycloak realm 'monitoring'
## Param (optional): REALM - Exports the specified realm, e.g. `make traefik-export-keycloak-realm REALM=master`
## (https://www.keycloak.org/server/importExport)
traefik-export-keycloak-realm:
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		down keycloak keycloak-db
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		run --rm --name traefik-keycloak-realm-export\
			keycloak\
				export --dir /opt/keycloak/data/export --realm $(REALM)
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		up --detach keycloak

# Imports all keycloak realm content out of './config/keycloak/export' directory
## (https://www.keycloak.org/server/importExport)
traefik-import-keycloak-realm:
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		down keycloak keycloak-db
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		run --rm --name traefik-keycloak-realm-import\
			keycloak\
				import --dir /opt/keycloak/data/export
	docker compose\
			--env-file $(TRAEFIK_BASE_DIR)/.env.traefik\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.yaml\
			--file $(TRAEFIK_BASE_DIR)/docker-compose.traefik.prod.yaml\
		up --detach keycloak

# Start application update procedure
traefik-update:
	bash $(TRAEFIK_BASE_DIR)/scripts/update.sh
