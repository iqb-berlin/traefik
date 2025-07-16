#!/usr/bin/env bash

declare TARGET_VERSION="2.5.0"

update_environment_file() {
  printf "      Updating docker environment file '%s' ...\n" ".env.traefik"
  sed -i.bak "s|^# Choose ''|# Leave it empty|" .env.traefik && rm .env.traefik.bak
  sed -i.bak "s|^TLS_ACME_EAB_KID=''|TLS_ACME_EAB_KID=|" .env.traefik && rm .env.traefik.bak
  sed -i.bak "s|^TLS_ACME_EAB_HMAC_ENCODED=''|TLS_ACME_EAB_HMAC_ENCODED=|" .env.traefik && rm .env.traefik.bak
  printf "      Docker environment file update done.\n"
}

main() {
  printf "    Applying patch: %s ...\n" ${TARGET_VERSION}

  update_environment_file

  printf "    Patch %s applied.\n" ${TARGET_VERSION}
}

main
