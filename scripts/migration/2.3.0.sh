#!/usr/bin/env bash

declare TARGET_VERSION="2.3.0"
declare PROJECT_NAME

start_keycloak() {
    printf "      Check Keycloak status: "

    if [ "$(docker compose \
        --env-file "${PWD}/.env.traefik" \
        --file "${PWD}/docker-compose.traefik.yaml" \
        --file "${PWD}/docker-compose.traefik.prod.yaml" \
      ps -q keycloak keycloak-db | wc -l)" != 2 ]; then

      printf "Keycloak is down.\n\n"

      printf "      Starting Keycloak ...\n"
      docker compose \
        --progress quiet \
        --env-file "${PWD}/.env.traefik" \
        --file "${PWD}/docker-compose.traefik.yaml" \
        --file "${PWD}/docker-compose.traefik.prod.yaml" \
        up -d keycloak keycloak-db
      sleep 15  # waiting keycloak started completely
      printf "      Keycloak started.\n\n"
    else
      printf "Keycloak is up.\n\n"
      ARE_KEYCLOAK_SERVICES_UP=true
    fi
}

delete_iqb_realm() {
  printf "      Deleting IQB realm ...\n"
  source .env.traefik

  printf "      - " && docker exec -it "${PROJECT_NAME}-keycloak-1" \
    /opt/keycloak/bin/kcadm.sh delete realms/iqb \
      --server http://localhost:8080 \
      --realm master \
      --user "${ADMIN_NAME}" \
      --password "${ADMIN_PASSWORD}"
  printf "      IQB realm deleted.\n\n"

}

stop_keycloak() {
  if ! ${ARE_KEYCLOAK_SERVICES_UP}; then
    printf "      Stopping Keycloak ...\n"
    docker compose \
        --progress quiet \
        --env-file "${PWD}/.env.traefik" \
        --file "${PWD}/docker-compose.traefik.yaml" \
        --file "${PWD}/docker-compose.traefik.prod.yaml" \
      down keycloak keycloak-db
    printf "      Keycloak stopped.\n\n"
  fi
}

clean_up() {
  printf "      Deleting IQB realm source files ...\n"
  printf "      - " && rm -v config/keycloak/iqb-realm.config
  printf "      - " && rm -v config/keycloak/iqb-realm.json
  printf "      IQB realm source files deleted.\n\n"
}

main() {
  PROJECT_NAME="$(basename "${PWD}")"

  printf "    Applying patch: %s ...\n" ${TARGET_VERSION}

  start_keycloak
  delete_iqb_realm
  stop_keycloak
  clean_up

  printf "    Patch %s applied.\n" ${TARGET_VERSION}
}

main
