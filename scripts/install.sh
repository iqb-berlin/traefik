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
  mkdir -p "$TARGET_DIR"/config/maintenance-page
  mkdir -p "$TARGET_DIR"/config/prometheus
  mkdir -p "$TARGET_DIR"/config/traefik
  mkdir -p "$TARGET_DIR"/scripts
  mkdir -p "$TARGET_DIR"/secrets/traefik

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
  download_file config/traefik/tls-config.yaml config/traefik/tls-config.yaml
  download_file config/maintenance-page/default.conf.template config/maintenance-page/default.conf.template
  download_file config/maintenance-page/maintenance.html config/maintenance-page/maintenance.html
  download_file config/prometheus/prometheus.yaml config/prometheus/prometheus.yaml
  download_file config/grafana/config.monitoring config/grafana/config.monitoring
  download_file config/grafana/provisioning/dashboards/dashboard.yaml config/grafana/provisioning/dashboards/dashboard.yaml
  download_file config/grafana/provisioning/dashboards/traefik_rev4.json config/grafana/provisioning/dashboards/traefik_rev4.json
  download_file config/grafana/provisioning/datasources/datasource.yaml config/grafana/provisioning/datasources/datasource.yaml
  download_file scripts/traefik.mk scripts/make/prod.mk
  download_file update_$APP_NAME.sh scripts/update.sh
  chmod +x update_$APP_NAME.sh

  printf "Downloads done!\n\n"
}

customize_settings() {
  # Activate environment file
  cp .env.traefik.template .env.traefik
  source .env.traefik

  # Setup environment variables
  printf "5. Set Environment variables (default postgres password is generated randomly):\n\n"

  read -p "SERVER_NAME: " -er -i "$SERVER_NAME" SERVER_NAME
  sed -i "s#SERVER_NAME.*#SERVER_NAME=$SERVER_NAME#" .env.traefik

  read -p "HTTP_PORT: " -er -i "$HTTP_PORT" HTTP_PORT
  sed -i "s#HTTP_PORT.*#HTTP_PORT=$HTTP_PORT#" .env.traefik

  read -p "HTTPS_PORT: " -er -i "$HTTPS_PORT" HTTPS_PORT
  sed -i "s#HTTPS_PORT.*#HTTPS_PORT=$HTTPS_PORT#" .env.traefik

  read -p "Traefik administrator name: " -er TRAEFIK_ADMIN_NAME
  read -p "Traefik administrator password: " -er TRAEFIK_ADMIN_PASSWORD
  BASIC_AUTH_CRED=$TRAEFIK_ADMIN_NAME:$(openssl passwd -apr1 "$TRAEFIK_ADMIN_PASSWORD" | sed -e s/\\$/\\$\\$/g)
  printf "TRAEFIK_AUTH: %s\n" "$BASIC_AUTH_CRED"
  sed -i "s#TRAEFIK_AUTH.*#TRAEFIK_AUTH=$BASIC_AUTH_CRED#" .env.traefik

  sed -i "s#IQB_TRAEFIK_VERSION_TAG.*#IQB_TRAEFIK_VERSION_TAG=$TARGET_TAG#" .env.traefik

  # Setup makefiles
  sed -i "s#TRAEFIK_BASE_DIR :=.*#TRAEFIK_BASE_DIR := \\$TARGET_DIR#" scripts/traefik.mk
  if [ -f Makefile ]; then
    printf "include %s/scripts/traefik.mk\n" "$TARGET_DIR" >>Makefile
  else
    printf "include %s/scripts/traefik.mk\n" "$TARGET_DIR" >Makefile
  fi

  # Generate TLS files
  printf "\n"
  read -p "6. Do you have a TLS certificate and private key? [y/N] " -er -n 1 IS_TLS
  if [[ ! $IS_TLS =~ ^[yY]$ ]]; then
    printf "\nAn unsecure self-signed TLS certificate valid for 30 days will be generated ...\n"
    openssl req \
      -newkey rsa:2048 -nodes -subj "/CN=$SERVER_NAME" -keyout "$TARGET_DIR"/secrets/traefik/privkey.pem \
      -x509 -days 30 -out "$TARGET_DIR"/secrets/traefik/certificate.pem
    printf "A self-signed certificate file and a private key file have been generated.\n"

  else
    printf "Generated certificate placeholder file.\nReplace this text with real content if necessary.\n" \
      >"$TARGET_DIR"/secrets/traefik/certificate.pem
    printf "Generated key placeholder file.\nReplace this text with real content if necessary.\n" \
      >"$TARGET_DIR"/secrets/traefik/privkey.pem
    printf "\nA certificate placeholder file and a private key placeholder file have been generated.\n"
    printf "Please replace the content of the placeholder files 'secrets/traefik/certificate.pem' "
    printf "and 'secrets/traefik/privkey.pem' with your existing certificate and private key!\n"
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
  printf "\n==================================================\n"
  printf "'%s' installation script started ..." $APP_NAME | tr '[:lower:]' '[:upper:]'
  printf "\n==================================================\n"
  printf "\n"

  check_prerequisites

  get_release_version

  prepare_installation_dir

  download_files

  customize_settings

  application_start
}

main
