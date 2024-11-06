#!/bin/bash

migrate_file_structure() {
  printf "Migrate application file structure ...\n"
  if [ -f secrets/traefik/certificate.pem ]; then
    mv secrets/traefik/certificate.pem secrets/traefik/certs/certificate.pem
  fi
  if [ -f secrets/traefik/privkey.pem ]; then
    mv secrets/traefik/privkey.pem secrets/traefik/certs/private_key.pem
  fi
  if ! [ -f Makefile ]; then
    printf "include %s/scripts/make/traefik.mk\n" "$(pwd)" >"$(pwd)/Makefile"
  fi
  printf "Application file structure migrated.\n\n"
}

update_environment_file() {
  printf "Update docker environment file ...\n"
  sed -i.bak "/HTTPS_PORT=.*/a\\\n## TLS Certificates Resolvers" .env.traefik && rm .env.traefik.bak
  sed -i.bak "/## TLS Certificates Resolvers/a\# Choose '', if you handle certificates manually, or" \
    .env.traefik && rm .env.traefik.bak
  sed -i.bak "/# Choose ''.*/a\# choose 'acme', if you want to use an acme-provider, like 'Let's Encrypt' or 'Sectigo'" \
    .env.traefik && rm .env.traefik.bak
  sed -i.bak "/# choose 'acme'.*/a\TLS_CERTIFICATE_RESOLVER=" .env.traefik && rm .env.traefik.bak
  sed -i.bak "/TLS_CERTIFICATE_RESOLVER=.*/a\TLS_ACME_CA_SERVER=https://acme-v02.api.letsencrypt.org/directory" \
    .env.traefik && rm .env.traefik.bak
  sed -i.bak "/TLS_ACME_CA_SERVER=.*/a\TLS_ACME_EAB_KID=''\nTLS_ACME_EAB_HMAC_ENCODED=''" \
    .env.traefik && rm .env.traefik.bak
  sed -i.bak "/TLS_ACME_EAB_HMAC_ENCODED=.*/a\TLS_ACME_EMAIL=admin.name@organisation.org" \
    .env.traefik && rm .env.traefik.bak
  printf "Docker environment file updated.\n\n"
}

clean_up() {
  printf "Clean up obsolete files ...\n"
  if [ -f config/traefik/tls-config.yaml ]; then
    rm config/traefik/tls-config.yaml
  fi
  printf "Obsolete files cleaned up.\n\n"
}

main() {
  printf "\n============================================================\n"
  printf "Migration script '%s' started ..." "$0"
  printf "\n------------------------------------------------------------\n"
  printf "\n"

  migrate_file_structure
  update_environment_file
  clean_up

  printf "\n------------------------------------------------------------\n"
  printf "Migration script '%s' finished." "$0"
  printf "\n============================================================\n"
  printf "\n"
}

main
