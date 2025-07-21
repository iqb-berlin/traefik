#!/bin/bash

declare TARGET_VERSION="2.4.0"
declare PROJECT_NAME

delete_iqb_realm() {
  printf "      Deleting IQB realm ...\n"
  source .env.traefik

  docker exec -it "${PROJECT_NAME}-keycloak-1" \
    /opt/keycloak/bin/kcadm.sh delete realms/iqb \
      --server http://localhost:8080 \
      --realm master \
      --user ${ADMIN_NAME} \
      --password ${ADMIN_PASSWORD}
  printf "      IQB realm deleted.\n\n"

}

clean_up() {
  printf "      Deleting IQB realm source files ...\n"
  rm -f ${PROJECT_NAME}/config/keycloak/iqb-realm.config
  rm -f ${PROJECT_NAME}/config/keycloak/iqb-realm.json
  printf "      IQB realm source files deleted.\n\n"
}

main() {
  PROJECT_NAME="$(basename ${PWD})"

  printf "    Applying patch: %s ...\n" ${TARGET_VERSION}

  delete_iqb_realm
  clean_up

  printf "    Patch %s applied.\n" ${TARGET_VERSION}
}

main
