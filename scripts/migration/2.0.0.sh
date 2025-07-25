#!/usr/bin/env bash

update_environment_file() {
  source .env.traefik.template
  sed -i "s/# Version/## Version/" .env.traefik
  sed -i "s/# Server/## Server/" .env.traefik
  sed -i "s/# Ports/## Ports/" .env.traefik
  sed -i "s/# Network/## Network/" .env.traefik
  sed -i "s/# Default is 1500, but Openstack actual uses 1442/# Default is 1500, but Openstack currently uses 1442/" .env.traefik

  sed -i "/# Authentication/d" .env.traefik
  sed -i "/# https.*/d" .env.traefik
  sed -i "/# echo .*/d" .env.traefik

  ## Super User
  printf "## Super User\n" | tee -a .env.traefik
  ADMIN_NAME="$(sed -n -e 's/^TRAEFIK_AUTH=\(.*\)\:.*$/\1/p' .env.traefik)"
  read -p "ADMIN_NAME: " -er -i "$ADMIN_NAME" ADMIN_NAME
  printf "ADMIN_NAME=%s\n" "$ADMIN_NAME" >>.env.traefik
  sed -i "/TRAEFIK_AUTH=.*/d" .env.traefik

  read -p "ADMIN_EMAIL: " -er -i "$ADMIN_EMAIL" ADMIN_EMAIL
  printf "ADMIN_EMAIL=%s\n" "$ADMIN_EMAIL" >>.env.traefik

  ADMIN_PASSWORD=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 16 | head -n 1)
  read -p "ADMIN_PASSWORD: " -er -i "${ADMIN_PASSWORD}" ADMIN_PASSWORD
  printf "ADMIN_PASSWORD=%s\n" "$ADMIN_PASSWORD" >>.env.traefik

  ADMIN_CREATED_TIMESTAMP=$(date -u +"%s")000
  printf "ADMIN_CREATED_TIMESTAMP=%s\n" "$ADMIN_CREATED_TIMESTAMP" >>.env.traefik

  printf "\n## OAuth2 Authentication (OpenID Connect)\n" | tee -a .env.traefik
  printf "# Keycloak DB\n" | tee -a .env.traefik
  read -p "POSTGRES_USER: " -er -i "${POSTGRES_USER}" POSTGRES_USER
  printf "POSTGRES_USER=%s\n" "$POSTGRES_USER" >>.env.traefik

  POSTGRES_PASSWORD=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 16 | head -n 1)
  read -p "POSTGRES_PASSWORD: " -er -i "${POSTGRES_PASSWORD}" POSTGRES_PASSWORD
  printf "POSTGRES_PASSWORD=%s\n" "$POSTGRES_PASSWORD" >>.env.traefik

  read -p "POSTGRES_DB: " -er -i "${POSTGRES_DB}" POSTGRES_DB
  printf "POSTGRES_DB=%s\n" "$POSTGRES_DB" >>.env.traefik

  printf "\n# OAuth2 Clients\n" | tee -a .env.traefik
  printf "Client IDs will be BASE64 encoded.\n"
  printf "\nI. Traefik Dashboard Client\n"
  read -p "TRAEFIK_CLIENT_ID: " -er -i "${TRAEFIK_CLIENT_ID}" TRAEFIK_CLIENT_ID
  TRAEFIK_CLIENT_ID=$(printf '%s' "${TRAEFIK_CLIENT_ID}" | openssl base64)
  printf "TRAEFIK_CLIENT_ID=%s\n" "$TRAEFIK_CLIENT_ID" >>.env.traefik

  TRAEFIK_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  printf "TRAEFIK_CLIENT_SECRET=%s\n" "$TRAEFIK_CLIENT_SECRET" >>.env.traefik

  TRAEFIK_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  printf "TRAEFIK_COOKIE_SECRET=%s\n" "$TRAEFIK_COOKIE_SECRET" >>.env.traefik

  read -p "TRAEFIK_EMAIL_DOMAIN: " -er -i "${TRAEFIK_EMAIL_DOMAIN}" TRAEFIK_EMAIL_DOMAIN
  printf "TRAEFIK_EMAIL_DOMAIN=%s\n" "$TRAEFIK_EMAIL_DOMAIN" >>.env.traefik

  printf "\nII. Grafana Client\n"
  read -p "GRAFANA_CLIENT_ID: " -er -i "${GRAFANA_CLIENT_ID}" GRAFANA_CLIENT_ID
  GRAFANA_CLIENT_ID=$(printf '%s' "${GRAFANA_CLIENT_ID}" | openssl base64)
  printf "\nGRAFANA_CLIENT_ID=%s\n" "$GRAFANA_CLIENT_ID" >>.env.traefik

  GRAFANA_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  printf "GRAFANA_CLIENT_SECRET=%s\n" "$GRAFANA_CLIENT_SECRET" >>.env.traefik

  printf "\nIII. Prometheus Client\n"
  read -p "PROMETHEUS_CLIENT_ID: " -er -i "${PROMETHEUS_CLIENT_ID}" PROMETHEUS_CLIENT_ID
  PROMETHEUS_CLIENT_ID=$(printf '%s' "${PROMETHEUS_CLIENT_ID}" | openssl base64)
  printf "\nPROMETHEUS_CLIENT_ID=%s\n" "$PROMETHEUS_CLIENT_ID" >>.env.traefik

  PROMETHEUS_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  printf "PROMETHEUS_CLIENT_SECRET=%s\n" "$PROMETHEUS_CLIENT_SECRET" >>.env.traefik

  PROMETHEUS_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  printf "PROMETHEUS_COOKIE_SECRET=%s\n" "$PROMETHEUS_COOKIE_SECRET" >>.env.traefik

  read -p "PROMETHEUS_EMAIL_DOMAIN: " -er -i "${PROMETHEUS_EMAIL_DOMAIN}" PROMETHEUS_EMAIL_DOMAIN
  printf "PROMETHEUS_EMAIL_DOMAIN=%s\n" "$PROMETHEUS_EMAIL_DOMAIN" >>.env.traefik

  printf "\nIV. Node Exporter Client\n"
  read -p "NODE_EXPORTER_CLIENT_ID: " -er -i "${NODE_EXPORTER_CLIENT_ID}" NODE_EXPORTER_CLIENT_ID
  NODE_EXPORTER_CLIENT_ID=$(printf '%s' "${NODE_EXPORTER_CLIENT_ID}" | openssl base64)
  printf "\nNODE_EXPORTER_CLIENT_ID=%s\n" "$NODE_EXPORTER_CLIENT_ID" >>.env.traefik

  NODE_EXPORTER_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  printf "NODE_EXPORTER_CLIENT_SECRET=%s\n" "$NODE_EXPORTER_CLIENT_SECRET" >>.env.traefik

  NODE_EXPORTER_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  printf "NODE_EXPORTER_COOKIE_SECRET=%s\n" "$NODE_EXPORTER_COOKIE_SECRET" >>.env.traefik

  read -p "NODE_EXPORTER_EMAIL_DOMAIN: " -er -i "${NODE_EXPORTER_EMAIL_DOMAIN}" NODE_EXPORTER_EMAIL_DOMAIN
  printf "NODE_EXPORTER_EMAIL_DOMAIN=%s\n" "$NODE_EXPORTER_EMAIL_DOMAIN" >>.env.traefik

  printf "\nV. cAdvisor Client\n"
  read -p "CADVISOR_CLIENT_ID: " -er -i "${CADVISOR_CLIENT_ID}" CADVISOR_CLIENT_ID
  CADVISOR_CLIENT_ID=$(printf '%s' "${CADVISOR_CLIENT_ID}" | openssl base64)
  printf "\nCADVISOR_CLIENT_ID=%s\n" "$CADVISOR_CLIENT_ID" >>.env.traefik

  CADVISOR_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  printf "CADVISOR_CLIENT_SECRET=%s\n" "$CADVISOR_CLIENT_SECRET" >>.env.traefik

  CADVISOR_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  printf "CADVISOR_COOKIE_SECRET=%s\n" "$CADVISOR_COOKIE_SECRET" >>.env.traefik

  read -p "CADVISOR_EMAIL_DOMAIN: " -er -i "${CADVISOR_EMAIL_DOMAIN}" CADVISOR_EMAIL_DOMAIN
  printf "CADVISOR_EMAIL_DOMAIN=%s\n" "$CADVISOR_EMAIL_DOMAIN" >>.env.traefik

  printf "\nVI. Dozzle Client\n"
  read -p "DOZZLE_CLIENT_ID: " -er -i "${DOZZLE_CLIENT_ID}" DOZZLE_CLIENT_ID
  DOZZLE_CLIENT_ID=$(printf '%s' "${DOZZLE_CLIENT_ID}" | openssl base64)
  printf "\nDOZZLE_CLIENT_ID=%s\n" "$DOZZLE_CLIENT_ID" >>.env.traefik

  DOZZLE_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  printf "DOZZLE_CLIENT_SECRET=%s\n" "$DOZZLE_CLIENT_SECRET" >>.env.traefik

  DOZZLE_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  printf "DOZZLE_COOKIE_SECRET=%s\n" "$DOZZLE_COOKIE_SECRET" >>.env.traefik

  read -p "DOZZLE_EMAIL_DOMAIN: " -er -i "${DOZZLE_EMAIL_DOMAIN}" DOZZLE_EMAIL_DOMAIN
  printf "DOZZLE_EMAIL_DOMAIN=%s\n" "$DOZZLE_EMAIL_DOMAIN" >>.env.traefik
}

clean_up() {
  rm config/grafana/config.monitoring

  if [ -d ./grafana/ ]; then
    mv ./grafana/ ./config/grafana/
  fi

  if [ -d ./prometheus/ ]; then
    mv ./prometheus/ ./config/prometheus/
  fi

  rm scripts/traefik.mk
  mv update_traefik.sh scripts/update_traefik.sh
}

main() {
  printf "\n============================================================\n"
  printf "Migration script '%s' started ..." "$0"
  printf "\n------------------------------------------------------------\n"
  printf "\n"

  update_environment_file
  clean_up

  printf "\n------------------------------------------------------------\n"
  printf "Migration script '%s' finished." "$0"
  printf "\n============================================================\n"
  printf "\n"
}

main
