#!/usr/bin/env bash

declare TARGET_VERSION="2.5.0"

update_environment_file() {
  printf "      Updating docker environment file '%s' ...\n" ".env.traefik"
  sed -i.bak "s|^# Choose ''|# Leave it empty|" .env.traefik && rm .env.traefik.bak
  sed -i.bak "s|^TLS_ACME_EAB_KID=''|TLS_ACME_EAB_KID=|" .env.traefik && rm .env.traefik.bak
  sed -i.bak "s|^TLS_ACME_EAB_HMAC_ENCODED=''|TLS_ACME_EAB_HMAC_ENCODED=|" .env.traefik && rm .env.traefik.bak
  printf "      Docker environment file update done.\n\n"
}

clean_up() {
  printf "      Deleting outdated keycloak realm import files ...\n"
  declare realm_file=config/keycloak/import/monitoring-realm.json
  declare realm_config=config/keycloak/import/monitoring-realm.config
  if test -f ${realm_file}; then
    if rm ${realm_file}; then
      printf -- "- File '%s' deleted.\n" ${realm_file}
    fi
  fi
  if test -f ${realm_config}; then
    if rm ${realm_config}; then
      printf -- "- File '%s' deleted.\n" ${realm_config}
    fi
  fi
  printf "      Outdated keycloak realm import files deletion done.\n"
}

main() {
  printf "    Applying patch: %s ...\n" ${TARGET_VERSION}

  update_environment_file

  clean_up

  printf "    Patch %s applied.\n" ${TARGET_VERSION}
}

main
