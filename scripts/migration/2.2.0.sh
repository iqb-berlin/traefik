#!/bin/bash

migrate_file_structure() {
    if [ -f secrets/traefik/certificate.pem ]; then
      mv secrets/traefik/certificate.pem secrets/traefik/certs/certificate.pem
    fi
    if [ -f secrets/traefik/privkey.pem ]; then
      mv secrets/traefik/privkey.pem secrets/traefik/certs/private_key.pem
    fi
}

update_environment_file() {
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
  sed -i.bak "/TLS_ACME_EAB_HMAC_ENCODED=.*/a\TLS_ACME_EMAIL=admin.name@organisation.org\n" \
    .env.traefik && rm .env.traefik.bak
}

clean_up() {
  if [ -f config/traefik/tls-config.yaml ]; then
    rm config/traefik/tls-config.yaml
  fi
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
