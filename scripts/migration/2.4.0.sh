#!/bin/bash

declare TARGET_VERSION="2.4.0"
declare PROJECT_NAME
declare ARE_KEYCLOAK_SERVICES_UP=false

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
      sleep 30  # waiting keycloak started completely
      printf "      Keycloak started.\n\n"
    else
      printf "Keycloak is up.\n\n"
      ARE_KEYCLOAK_SERVICES_UP=true
    fi
}

set_iqb_theme_as_realm_default() {
  printf "      Set IQB theme as default for monitoring realm ...\n"
  source .env.traefik

   printf "      - " && docker exec -i "${PROJECT_NAME}-keycloak-1" \
    /opt/keycloak/bin/kcadm.sh update realms/monitoring \
      --server http://localhost:8080 \
      --realm master \
      --user "${ADMIN_NAME}" \
      --password "${ADMIN_PASSWORD}" \
      --file - <<EOF
{
  "loginTheme": "iqb"
}
EOF
  printf "      IQB theme setting done.\n\n"

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

main() {
  PROJECT_NAME="$(basename "${PWD}")"

  printf "    Applying patch: %s ...\n" ${TARGET_VERSION}

  start_keycloak
  set_iqb_theme_as_realm_default
  stop_keycloak

  printf "    Patch %s applied.\n" ${TARGET_VERSION}
}

main
