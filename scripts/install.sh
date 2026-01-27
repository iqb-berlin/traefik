#!/bin/bash
set -e

APP_NAME='traefik'

REPO_URL="https://raw.githubusercontent.com/iqb-berlin/$APP_NAME"
REPO_API="https://api.github.com/repos/iqb-berlin/$APP_NAME"
REQUIRED_PACKAGES=("docker -v" "docker compose version")
OPTIONAL_PACKAGES=("make -v")

check_prerequisites() {
  printf "1. Checking prerequisites:\n\n"

  printf "1.1 Checking required packages ...\n"
  # Check required packages are installed
  for REQ_PACKAGE in "${REQUIRED_PACKAGES[@]}"; do
    if $REQ_PACKAGE >/dev/null 2>&1; then
      printf -- "- '%s' is working.\n" "$REQ_PACKAGE"
    else
      printf "'%s' not working, please install the corresponding package before running!\n" "$REQ_PACKAGE"
      exit 1
    fi
  done
  printf "Required packages successfully checked.\n\n"

  # Check optional packages are installed
  printf "1.2 Checking optional packages ...\n"
  for OPT_PACKAGE in "${OPTIONAL_PACKAGES[@]}"; do
    if $OPT_PACKAGE >/dev/null 2>&1; then
      printf -- "- '%s' is working.\n" "$OPT_PACKAGE"
    else
      printf "%s not working! It is recommended to have the corresponding package installed.\n" "$OPT_PACKAGE"
      read -p 'Continue anyway? [y/N] ' -er -n 1 CONTINUE

      if [[ ! $CONTINUE =~ ^[yY]$ ]]; then
        exit 1
      fi
    fi
  done
  printf "Optional packages successfully checked.\n\n"

  printf "\nPrerequisites check finished successfully.\n\n"
}

get_release_version() {
  LATEST_RELEASE=$(curl -s "$REPO_API"/releases/latest | grep tag_name | cut -d : -f 2,3 | tr -d \" | tr -d , | tr -d " ")

  while read -p '2. Name the desired release tag: ' -er -i "$LATEST_RELEASE" TARGET_TAG; do
    if ! curl --head --silent --fail --output /dev/null $REPO_URL/"$TARGET_TAG"/README.md 2>/dev/null; then
      printf "This version tag does not exist.\n"
    else
      break
    fi
  done

  printf "\n"
}

prepare_installation_dir() {
  while read -p '3. Determine installation directory: ' -er -i "$PWD/$APP_NAME" TARGET_DIR; do
    if [ ! -e "$TARGET_DIR" ]; then
      break

    elif [ -d "$TARGET_DIR" ] && [ -z "$(find "$TARGET_DIR" -maxdepth 0 -type d -empty 2>/dev/null)" ]; then
      read -p "You have selected a non empty directory. Continue anyway? [y/N] " -er -n 1 CONTINUE
      if [[ ! $CONTINUE =~ ^[yY]$ ]]; then
        printf "'%s' installation script finished.\n" $APP_NAME
        exit 0
      fi

      break

    else
      printf "'%s' is not a directory!\n\n" "$TARGET_DIR"
    fi

  done

  printf "\n"

  mkdir -p "$TARGET_DIR"/config/grafana/provisioning/dashboards
  mkdir -p "$TARGET_DIR"/config/grafana/provisioning/datasources
  mkdir -p "$TARGET_DIR"/config/keycloak
  mkdir -p "$TARGET_DIR"/config/maintenance-page
  mkdir -p "$TARGET_DIR"/config/prometheus
  mkdir -p "$TARGET_DIR"/config/traefik
  mkdir -p "$TARGET_DIR"/scripts/make
  mkdir -p "$TARGET_DIR"/scripts/migration
  mkdir -p "$TARGET_DIR"/secrets/traefik/certs/acme

  cd "$TARGET_DIR"
}

download_file() {
  if wget -q -O "$1" $REPO_URL/"$TARGET_TAG"/"$2"; then
    printf -- "- File '%s' successfully downloaded.\n" "$1"

  else
    printf -- "- File '%s' download failed.\n\n" "$1"
    printf "'%s' installation script finished with error.\n" $APP_NAME
    exit 1
  fi
}

download_files() {
  printf "4. Downloading files:\n"

  download_file docker-compose.traefik.yaml docker-compose.yaml
  download_file docker-compose.traefik.prod.yaml docker-compose.traefik.prod.yaml
  download_file .env.traefik.template .env.traefik.template
  download_file config/grafana/provisioning/dashboards/dashboard.yaml config/grafana/provisioning/dashboards/dashboard.yaml
  download_file config/grafana/provisioning/dashboards/traefik_rev4.json config/grafana/provisioning/dashboards/traefik_rev4.json
  download_file config/grafana/provisioning/datasources/datasource.yaml config/grafana/provisioning/datasources/datasource.yaml
  download_file config/grafana/oauth2.config config/grafana/oauth2.config
  download_file config/keycloak/iqb-realm.config config/keycloak/iqb-realm.config
  download_file config/keycloak/iqb-realm.json config/keycloak/iqb-realm.json
  download_file config/maintenance-page/default.conf.template config/maintenance-page/default.conf.template
  download_file config/maintenance-page/maintenance.html config/maintenance-page/maintenance.html
  download_file config/prometheus/prometheus.yaml config/prometheus/prometheus.yaml
  download_file config/traefik/tls-acme.yaml config/traefik/tls-acme.yaml
  download_file config/traefik/tls-certificates.yaml config/traefik/tls-certificates.yaml
  download_file config/traefik/tls-options.yaml config/traefik/tls-options.yaml
  download_file scripts/make/traefik.mk scripts/make/prod.mk
  download_file scripts/update_${APP_NAME}.sh scripts/update.sh
  chmod +x scripts/update_${APP_NAME}.sh

  printf "Downloads done!\n\n"
}

customize_settings() {
  # Activate environment file
  cp .env.traefik.template .env.traefik

  # Setup environment variables
  printf "5. Set Environment variables (default passwords are generated randomly):\n"
  source .env.traefik

  ## Version
  sed -i "s#IQB_TRAEFIK_VERSION_TAG.*#IQB_TRAEFIK_VERSION_TAG=$TARGET_TAG#" .env.traefik

  ## Server
  printf "5.1 Server base domain name:\n"
  read -p "SERVER_NAME: " -er -i "${SERVER_NAME}" SERVER_NAME
  sed -i "s#SERVER_NAME.*#SERVER_NAME=$SERVER_NAME#" .env.traefik

  ## Ports
  printf "\n5.2 Ports:\n"
  read -p "HTTP_PORT: " -er -i "${HTTP_PORT}" HTTP_PORT
  sed -i "s#HTTP_PORT.*#HTTP_PORT=$HTTP_PORT#" .env.traefik

  read -p "HTTPS_PORT: " -er -i "${HTTPS_PORT}" HTTPS_PORT
  sed -i "s#HTTPS_PORT.*#HTTPS_PORT=$HTTPS_PORT#" .env.traefik

  ## Network
  printf "\n5.3 Network:\n"
  printf "Docker MTU have to be equal or less host network MTU!\n"
  printf "Current host network MTUs:\n"
  ip a | grep mtu | grep -v "lo:\|docker\|veth\|br-" | cut -f6- -d ' ' --complement
  read -p "DOCKER_DAEMON_MTU: " -er -i 1500 DOCKER_DAEMON_MTU
  sed -i "s#DOCKER_DAEMON_MTU.*#DOCKER_DAEMON_MTU=$DOCKER_DAEMON_MTU#" .env.traefik

  ## Super User
  printf "\n5.4 Super User (admin of admins):\n"
  read -p "ADMIN_NAME: " -er -i "${ADMIN_NAME}" ADMIN_NAME
  sed -i "s#ADMIN_NAME.*#ADMIN_NAME=$ADMIN_NAME#" .env.traefik

  read -p "ADMIN_EMAIL: " -er -i "${ADMIN_EMAIL}" ADMIN_EMAIL
  sed -i "s#ADMIN_EMAIL.*#ADMIN_EMAIL=$ADMIN_EMAIL#" .env.traefik

  ADMIN_PASSWORD=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 16 | head -n 1)
  read -p "ADMIN_PASSWORD: " -er -i "${ADMIN_PASSWORD}" ADMIN_PASSWORD
  sed -i "s#ADMIN_PASSWORD.*#ADMIN_PASSWORD=$ADMIN_PASSWORD#" .env.traefik

  ADMIN_CREATED_TIMESTAMP=$(date -u +"%s")000
  sed -i "s#ADMIN_CREATED_TIMESTAMP.*#ADMIN_CREATED_TIMESTAMP=$ADMIN_CREATED_TIMESTAMP#" .env.traefik

  printf "\n5.5 OpenID Connect with OAuth2 Authentication:\n"
  printf "5.5.1 Keycloak DB:\n"
  read -p "POSTGRES_USER: " -er -i "${POSTGRES_USER}" POSTGRES_USER
  sed -i "s#POSTGRES_USER.*#POSTGRES_USER=$POSTGRES_USER#" .env.traefik

  POSTGRES_PASSWORD=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 16 | head -n 1)
  read -p "POSTGRES_PASSWORD: " -er -i "${POSTGRES_PASSWORD}" POSTGRES_PASSWORD
  sed -i "s#POSTGRES_PASSWORD.*#POSTGRES_PASSWORD=$POSTGRES_PASSWORD#" .env.traefik

  read -p "POSTGRES_DB: " -er -i "${POSTGRES_DB}" POSTGRES_DB
  sed -i "s#POSTGRES_DB.*#POSTGRES_DB=$POSTGRES_DB#" .env.traefik

  printf "\n5.5.2 OAuth2 Clients:\n"
  printf "Client IDs will be BASE64 encoded.\n"
  printf "\n5.5.2.1 Traefik Dashboard Client:\n"
  read -p "TRAEFIK_CLIENT_ID: " -er -i "${TRAEFIK_CLIENT_ID}" TRAEFIK_CLIENT_ID
  TRAEFIK_CLIENT_ID=$(printf '%s' "${TRAEFIK_CLIENT_ID}" | openssl base64)
  sed -i "s#TRAEFIK_CLIENT_ID.*#TRAEFIK_CLIENT_ID=$TRAEFIK_CLIENT_ID#" .env.traefik

  TRAEFIK_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  sed -i "s#TRAEFIK_CLIENT_SECRET.*#TRAEFIK_CLIENT_SECRET=$TRAEFIK_CLIENT_SECRET#" .env.traefik

  TRAEFIK_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  sed -i "s#TRAEFIK_COOKIE_SECRET.*#TRAEFIK_COOKIE_SECRET=$TRAEFIK_COOKIE_SECRET#" .env.traefik

  read -p "TRAEFIK_EMAIL_DOMAIN: " -er -i "${TRAEFIK_EMAIL_DOMAIN}" TRAEFIK_EMAIL_DOMAIN
  sed -i "s#TRAEFIK_EMAIL_DOMAIN.*#TRAEFIK_EMAIL_DOMAIN=$TRAEFIK_EMAIL_DOMAIN#" .env.traefik

  printf "\n5.5.2.2 Grafana Client:\n"
  read -p "GRAFANA_CLIENT_ID: " -er -i "${GRAFANA_CLIENT_ID}" GRAFANA_CLIENT_ID
  GRAFANA_CLIENT_ID=$(printf '%s' "${GRAFANA_CLIENT_ID}" | openssl base64)
  sed -i "s#GRAFANA_CLIENT_ID.*#GRAFANA_CLIENT_ID=$GRAFANA_CLIENT_ID#" .env.traefik

  GRAFANA_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  sed -i "s#GRAFANA_CLIENT_SECRET.*#GRAFANA_CLIENT_SECRET=$GRAFANA_CLIENT_SECRET#" .env.traefik

  printf "\n5.5.2.3 Prometheus Client:\n"
  read -p "PROMETHEUS_CLIENT_ID: " -er -i "${PROMETHEUS_CLIENT_ID}" PROMETHEUS_CLIENT_ID
  PROMETHEUS_CLIENT_ID=$(printf '%s' "${PROMETHEUS_CLIENT_ID}" | openssl base64)
  sed -i "s#PROMETHEUS_CLIENT_ID.*#PROMETHEUS_CLIENT_ID=$PROMETHEUS_CLIENT_ID#" .env.traefik

  PROMETHEUS_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  sed -i "s#PROMETHEUS_CLIENT_SECRET.*#PROMETHEUS_CLIENT_SECRET=$PROMETHEUS_CLIENT_SECRET#" .env.traefik

  PROMETHEUS_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  sed -i "s#PROMETHEUS_COOKIE_SECRET.*#PROMETHEUS_COOKIE_SECRET=$PROMETHEUS_COOKIE_SECRET#" .env.traefik

  read -p "PROMETHEUS_EMAIL_DOMAIN: " -er -i "${PROMETHEUS_EMAIL_DOMAIN}" PROMETHEUS_EMAIL_DOMAIN
  sed -i "s#PROMETHEUS_EMAIL_DOMAIN.*#PROMETHEUS_EMAIL_DOMAIN=$PROMETHEUS_EMAIL_DOMAIN#" .env.traefik

  printf "\n5.5.2.4 Node Exporter Client:\n"
  read -p "NODE_EXPORTER_CLIENT_ID: " -er -i "${NODE_EXPORTER_CLIENT_ID}" NODE_EXPORTER_CLIENT_ID
  NODE_EXPORTER_CLIENT_ID=$(printf '%s' "${NODE_EXPORTER_CLIENT_ID}" | openssl base64)
  sed -i "s#NODE_EXPORTER_CLIENT_ID.*#NODE_EXPORTER_CLIENT_ID=$NODE_EXPORTER_CLIENT_ID#" .env.traefik

  NODE_EXPORTER_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  sed -i "s#NODE_EXPORTER_CLIENT_SECRET.*#NODE_EXPORTER_CLIENT_SECRET=$NODE_EXPORTER_CLIENT_SECRET#" .env.traefik

  NODE_EXPORTER_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  sed -i "s#NODE_EXPORTER_COOKIE_SECRET.*#NODE_EXPORTER_COOKIE_SECRET=$NODE_EXPORTER_COOKIE_SECRET#" .env.traefik

  read -p "NODE_EXPORTER_EMAIL_DOMAIN: " -er -i "${NODE_EXPORTER_EMAIL_DOMAIN}" NODE_EXPORTER_EMAIL_DOMAIN
  sed -i "s#NODE_EXPORTER_EMAIL_DOMAIN.*#NODE_EXPORTER_EMAIL_DOMAIN=$NODE_EXPORTER_EMAIL_DOMAIN#" .env.traefik

  printf "\n5.5.2.5 cAdvisor Client:\n"
  read -p "CADVISOR_CLIENT_ID: " -er -i "${CADVISOR_CLIENT_ID}" CADVISOR_CLIENT_ID
  CADVISOR_CLIENT_ID=$(printf '%s' "${CADVISOR_CLIENT_ID}" | openssl base64)
  sed -i "s#CADVISOR_CLIENT_ID.*#CADVISOR_CLIENT_ID=$CADVISOR_CLIENT_ID#" .env.traefik

  CADVISOR_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  sed -i "s#CADVISOR_CLIENT_SECRET.*#CADVISOR_CLIENT_SECRET=$CADVISOR_CLIENT_SECRET#" .env.traefik

  CADVISOR_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  sed -i "s#CADVISOR_COOKIE_SECRET.*#CADVISOR_COOKIE_SECRET=$CADVISOR_COOKIE_SECRET#" .env.traefik

  read -p "CADVISOR_EMAIL_DOMAIN: " -er -i "${CADVISOR_EMAIL_DOMAIN}" CADVISOR_EMAIL_DOMAIN
  sed -i "s#CADVISOR_EMAIL_DOMAIN.*#CADVISOR_EMAIL_DOMAIN=$CADVISOR_EMAIL_DOMAIN#" .env.traefik

  printf "\n5.5.2.6 Dozzle Client:\n"
  read -p "DOZZLE_CLIENT_ID: " -er -i "${DOZZLE_CLIENT_ID}" DOZZLE_CLIENT_ID
  DOZZLE_CLIENT_ID=$(printf '%s' "${DOZZLE_CLIENT_ID}" | openssl base64)
  sed -i "s#DOZZLE_CLIENT_ID.*#DOZZLE_CLIENT_ID=$DOZZLE_CLIENT_ID#" .env.traefik

  DOZZLE_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  sed -i "s#DOZZLE_CLIENT_SECRET.*#DOZZLE_CLIENT_SECRET=$DOZZLE_CLIENT_SECRET#" .env.traefik

  DOZZLE_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  sed -i "s#DOZZLE_COOKIE_SECRET.*#DOZZLE_COOKIE_SECRET=$DOZZLE_COOKIE_SECRET#" .env.traefik

  read -p "DOZZLE_EMAIL_DOMAIN: " -er -i "${DOZZLE_EMAIL_DOMAIN}" DOZZLE_EMAIL_DOMAIN
  sed -i "s#DOZZLE_EMAIL_DOMAIN.*#DOZZLE_EMAIL_DOMAIN=$DOZZLE_EMAIL_DOMAIN#" .env.traefik

  # Setup makefiles
  sed -i "s#TRAEFIK_BASE_DIR :=.*#TRAEFIK_BASE_DIR := \\$TARGET_DIR#" scripts/make/traefik.mk
  sed -i "s#scripts/update.sh#scripts/update_${APP_NAME}.sh#" scripts/make/traefik.mk

  if [ -f Makefile ]; then
    printf "include %s/scripts/make/traefik.mk\n" "$TARGET_DIR" >>Makefile
  else
    printf "include %s/scripts/make/traefik.mk\n" "$TARGET_DIR" >Makefile
  fi

  ## TLS Certificate Resolver Configuration
  printf "\n6 TLS Configuration:\n"
  printf "6.1 Automatic Certificate Management Environment (ACME):\n"
  read -p "Do you want to use an ACME-Provider like 'Let's encrypt' or 'Sectigo' instead of user-defined certificates? [Y/n]: " -r -n 1 -e TLS
  if [[ ! $TLS =~ ^[nN]$ ]]; then
    sed -i.bak "s|TLS_CERTIFICATE_RESOLVER.*|TLS_CERTIFICATE_RESOLVER=acme|" .env.traefik && rm .env.traefik.bak

    read -p "TLS_ACME_CA_SERVER: " -er -i "${TLS_ACME_CA_SERVER}" TLS_ACME_CA_SERVER
    sed -i.bak "s|TLS_ACME_CA_SERVER.*|TLS_ACME_CA_SERVER=${TLS_ACME_CA_SERVER}|" .env.traefik && rm .env.traefik.bak

    read -p "TLS_ACME_EAB_KID: " -er -i "${TLS_ACME_EAB_KID}" TLS_ACME_EAB_KID
    sed -i.bak "s|TLS_ACME_EAB_KID.*|TLS_ACME_EAB_KID=${TLS_ACME_EAB_KID}|" .env.traefik && rm .env.traefik.bak

    read -p "TLS_ACME_EAB_HMAC_ENCODED: " -er -i "${TLS_ACME_EAB_HMAC_ENCODED}" TLS_ACME_EAB_HMAC_ENCODED
    sed -i.bak "s|TLS_ACME_EAB_HMAC_ENCODED.*|TLS_ACME_EAB_HMAC_ENCODED=${TLS_ACME_EAB_HMAC_ENCODED}|" .env.traefik &&
      rm .env.traefik.bak

    read -p "TLS_ACME_EMAIL: " -er -i "${TLS_ACME_EMAIL}" TLS_ACME_EMAIL
    sed -i.bak "s|TLS_ACME_EMAIL.*|TLS_ACME_EMAIL=${TLS_ACME_EMAIL}|" .env.traefik && rm .env.traefik.bak
  else
    sed -i.bak "s|TLS_CERTIFICATE_RESOLVER.*|TLS_CERTIFICATE_RESOLVER=|" .env.traefik && rm .env.traefik.bak

    # Generate TLS files
    printf "\n6.2 User-defined certificates:\n"
    read -p "Do you have a user-defined TLS certificate and private key? [y/N] " -er -n 1 IS_TLS
    if [[ ! $IS_TLS =~ ^[yY]$ ]]; then
      printf "\nAn unsecure self-signed TLS certificate valid for 30 days will be generated ...\n"
      openssl req \
        -newkey rsa:2048 -nodes -subj "/CN=$SERVER_NAME" -keyout "$TARGET_DIR"/secrets/traefik/certs/private_key.pem \
        -x509 -days 30 -out "$TARGET_DIR"/secrets/traefik/certs/certificate.pem
      printf "A self-signed certificate file and a private key file have been generated.\n"

    else
      printf "Generated certificate placeholder file.\nReplace this text with real content if necessary.\n" \
        >"$TARGET_DIR"/secrets/traefik/certs/certificate.pem
      printf "Generated key placeholder file.\nReplace this text with real content if necessary.\n" \
        >"$TARGET_DIR"/secrets/traefik/certs/private_key.pem
      printf "\nA certificate placeholder file and a private key placeholder file have been generated.\n"
      printf "Please replace the content of the placeholder files 'secrets/traefik/certs/certificate.pem' "
      printf "and 'secrets/traefik/certs/private_key.pem' with your existing certificate and private key!\n"
    fi
  fi

  printf "\n"
}

application_start() {
  printf "'%s' installation done.\n\n" $APP_NAME

  if command make -v >/dev/null 2>&1; then
    read -p "Do you want to start $APP_NAME now? [Y/n] " -er -n 1 START_NOW
    printf '\n'
    if [[ ! $START_NOW =~ [nN] ]]; then
      make traefik-up
    else
      printf "'%s' installation script finished.\n" $APP_NAME
      exit 0
    fi

  else
    printf 'You can start the docker services now.\n\n'
    printf "'%s' installation script finished.\n" $APP_NAME
    exit 0
  fi
}

main() {
  printf "\n============================================================\n"
  printf "'%s' installation script started ..." $APP_NAME | tr '[:lower:]' '[:upper:]'
  printf "\n============================================================\n"
  printf "\n"

  check_prerequisites

  get_release_version

  prepare_installation_dir

  download_files

  customize_settings

  application_start
}

main
