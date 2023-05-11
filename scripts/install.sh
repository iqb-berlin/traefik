#!/bin/bash
set -e

APP_NAME='traefik'

REPO_URL="https://raw.githubusercontent.com/iqb-berlin/$APP_NAME"
REPO_API="https://api.github.com/repos/iqb-berlin/$APP_NAME"
REQUIRED_PACKAGES=("docker -v" "docker compose version")
OPTIONAL_PACKAGES=("make -v")

check_prerequisites() {
  for APP in "${REQUIRED_PACKAGES[@]}"; do
    {
      $APP >/dev/null 2>&1
    } || {
      echo "$APP not found, please install before running!"
      exit 1
    }
  done
  for APP in "${OPTIONAL_PACKAGES[@]}"; do
    {
      $APP >/dev/null 2>&1
    } || {
      echo "$APP not found! It is recommended to have it installed."
      read -p 'Continue anyway [y/N]? ' -er -n 1 CONTINUE

      if [[ ! $CONTINUE =~ ^[yY]$ ]]; then
        exit 1
      fi
    }
  done
}

get_release_version() {
  LATEST_RELEASE=$(curl -s "$REPO_API"/releases/latest | grep tag_name | cut -d : -f 2,3 | tr -d \" | tr -d , | tr -d " ")

  while read -p '1. Name the desired release tag: ' -er -i "$LATEST_RELEASE" TARGET_TAG; do
    if ! curl --head --silent --fail --output /dev/null $REPO_URL/"$TARGET_TAG"/README.md 2>/dev/null; then
      echo "This version tag does not exist."
    else
      break
    fi
  done
}

prepare_installation_dir() {
  while read -p '2. Determine installation directory: ' -er -i "$PWD/$APP_NAME" TARGET_DIR; do
    if [ ! -e "$TARGET_DIR" ]; then
      break
    elif [ -d "$TARGET_DIR" ] && [ -z "$(find "$TARGET_DIR" -maxdepth 0 -type d -empty 2>/dev/null)" ]; then
      read -p "You have selected a non empty directory. Continue anyway [y/N]? " -er -n 1 CONTINUE
      if [[ ! $CONTINUE =~ ^[yY]$ ]]; then
        echo 'Installation script finished.'
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
    echo 'Install script finished with error'
    exit 1
  fi
}

download_files() {
  echo "Downloading files..."
  download_file docker-compose.traefik.yml docker-compose.yml
  download_file docker-compose.traefik.prod.yml docker-compose.traefik.prod.yml
  download_file .env.traefik.template .env.traefik.template
  download_file config/traefik/tls-config.yml config/traefik/tls-config.yml
  download_file config/prometheus/prometheus.yml config/prometheus/prometheus.yml
  download_file config/grafana/config.monitoring config/grafana/config.monitoring
  download_file config/grafana/provisioning/dashboards/dashboard.yml config/grafana/provisioning/dashboards/dashboard.yml
  download_file config/grafana/provisioning/dashboards/traefik_rev4.json config/grafana/provisioning/dashboards/traefik_rev4.json
  download_file config/grafana/provisioning/datasources/datasource.yml config/grafana/provisioning/datasources/datasource.yml
  download_file scripts/traefik.mk scripts/make/prod.mk
  download_file update_traefik.sh scripts/update.sh
  chmod +x update_traefik.sh
  printf "Download done!\n\n"
}

customize_settings() {
  # Activate environment file
  cp .env.traefik.template .env.traefik
  source .env.traefik

  # Setup makefiles
  sed -i "s#BASE_DIR :=.*#BASE_DIR := \.#" scripts/traefik.mk
  echo "include scripts/traefik.mk" >Makefile

  # Set environment variables in .env file
  printf "3. Set Environment variables (default postgres password is generated randomly):\n\n"
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

  # Generate TLS files
  printf "\n"
  read -p "4. Do you have a TLS certificate and private key [y/N]? " -er -n 1 IS_TLS
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
  printf "Installation done.\n\n"
  if command make -v >/dev/null 2>&1; then
    read -p "Do you want to start $APP_NAME now [Y/n]? " -er -n 1 START_NOW
    if [[ ! $START_NOW =~ [nN] ]]; then
      make traefik-up
    else
      echo 'Installation script finished.'
      exit 0
    fi
  else
    printf 'You can start the docker services now.\n\n'
    echo 'Installation script finished.'
    exit 0
  fi
}

check_prerequisites

get_release_version

prepare_installation_dir

download_files

customize_settings

application_start
