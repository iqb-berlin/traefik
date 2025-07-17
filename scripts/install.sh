#!/bin/bash
set -e

declare APP_DIR
declare APP_NAME='traefik'
declare REPO_URL="https://raw.githubusercontent.com/iqb-berlin/${APP_NAME}"
declare REPO_API="https://api.github.com/repos/iqb-berlin/${APP_NAME}"

declare INSTALL_SCRIPT_NAME="${0}"
declare TARGET_VERSION="${1}"
declare MAKE_BASE_DIR_NAME='TRAEFIK_BASE_DIR'
declare REQUIRED_PACKAGES=("docker -v" "docker compose version")
declare OPTIONAL_PACKAGES=("make -v")

get_release_version() {
  declare latest_release
  latest_release=$(curl --silent "${REPO_API}/releases/latest" | \
    grep tag_name | \
    cut -d : -f 2,3 | \
    tr -d \" | \
    tr -d , | \
    tr -d " ")

  while read -p '1. Please name the desired release tag: ' -er -i "${latest_release}" TARGET_VERSION; do
    if ! curl --head --silent --fail --output /dev/null "${REPO_URL}/${TARGET_VERSION}/README.md" 2>/dev/null; then
      printf "This version tag does not exist.\n"
    else
      break
    fi
  done

  # Check install script matches the selected release ...
  declare new_install_script="${REPO_URL}/${TARGET_VERSION}/scripts/install.sh"

  if ! curl --stderr /dev/null "${new_install_script}" | diff -q - "${INSTALL_SCRIPT_NAME}" &>/dev/null; then
    printf -- '- Current install script does not match the selected release install script!\n'
    printf '  Downloading a new install script for the selected release ...\n'
    mv "${INSTALL_SCRIPT_NAME}" "${INSTALL_SCRIPT_NAME}_old"
    if curl --silent --fail --output "install_${APP_NAME}.sh" "${new_install_script}"; then
      chmod +x "install_${APP_NAME}.sh"
      printf '  Download successful!\n\n'
    else
      printf '  Download failed!\n\n'
      printf "  '%s' install script finished with error.\n" "${APP_NAME}"
      exit 1
    fi

    printf "  The current install process will now execute the downloaded install script and terminate itself.\n"
    declare is_continue
    read -p "  Do you want to continue? [Y/n] " -er -n 1 is_continue
    if [[ ${is_continue} =~ ^[nN]$ ]]; then
      printf "\n  You can check the the new install script (e.g.: 'less %s') or " "install_${APP_NAME}.sh"
      printf "compare it with the old one (e.g.: 'diff %s %s').\n\n" \
        "install_${APP_NAME}.sh" "${INSTALL_SCRIPT_NAME}_old"

      printf "  If you want to resume this install process, please type: 'bash install_%s.sh %s'\n\n" \
        "${APP_NAME}" "${TARGET_VERSION}"

      printf "'%s' install script finished.\n" "${APP_NAME}"
      exit 0
    fi

    bash "install_${APP_NAME}.sh" "${TARGET_VERSION}"

    # remove old install script
    if [ -f "${INSTALL_SCRIPT_NAME}_old" ]; then
      rm "${INSTALL_SCRIPT_NAME}_old"
    fi

    exit ${?}
  fi

  printf "\n"
}

check_prerequisites() {
  printf "2. Checking prerequisites:\n\n"

  printf "2.1 Checking required packages ...\n"
  # Check required packages are installed
  declare req_package
  for req_package in "${REQUIRED_PACKAGES[@]}"; do
    if ${req_package} >/dev/null 2>&1; then
      printf -- "- '%s' is working.\n" "${req_package}"
    else
      printf "'%s' not working, please install the corresponding package before running!\n" "${req_package}"
      exit 1
    fi
  done
  printf "Required packages successfully checked.\n\n"

  # Check optional packages are installed
  declare opt_package
  printf "2.2 Checking optional packages ...\n"
  for opt_package in "${OPTIONAL_PACKAGES[@]}"; do
    if ${opt_package} >/dev/null 2>&1; then
      printf -- "- '%s' is working.\n" "${opt_package}"
    else
      printf "%s not working! It is recommended to have the corresponding package installed.\n" "${opt_package}"
      declare is_continue
      read -p 'Continue anyway? [y/N] ' -er -n 1 is_continue

      if [[ ! ${is_continue} =~ ^[yY]$ ]]; then
        exit 1
      fi
    fi
  done
  printf "Optional packages successfully checked.\n"

  printf "\nPrerequisites check finished successfully.\n\n"
}

prepare_installation_dir() {
  while read -p '3. Determine installation directory: ' -er -i "${PWD}/${APP_NAME}" APP_DIR; do
    if [ ! -e "${APP_DIR}" ]; then
      break

    elif [ -d "${APP_DIR}" ] && [ -z "$(find "${APP_DIR}" -maxdepth 0 -type d -empty 2>/dev/null)" ]; then
      declare is_continue
      read -p "You have selected a non empty directory. Continue anyway? [y/N] " -er -n 1 is_continue
      if [[ ! ${is_continue} =~ ^[yY]$ ]]; then
        printf "'%s' installation script finished.\n" "${APP_NAME}"
        exit 0
      fi

      break

    else
      printf "'%s' is not a directory!\n\n" "${APP_DIR}"
    fi

  done

  printf "\n"

  mkdir -p "${APP_DIR}/config/grafana/provisioning/dashboards"
  mkdir -p "${APP_DIR}/config/grafana/provisioning/datasources"
  mkdir -p "${APP_DIR}/config/keycloak"
  mkdir -p "${APP_DIR}/config/maintenance-page"
  mkdir -p "${APP_DIR}/config/prometheus"
  mkdir -p "${APP_DIR}/config/traefik"
  mkdir -p "${APP_DIR}/scripts/make"
  mkdir -p "${APP_DIR}/scripts/migration"
  mkdir -p "${APP_DIR}/secrets/traefik/certs/acme"

  cd "${APP_DIR}"
}

download_file() {
  declare local_file="${1}"
  declare remote_file="${REPO_URL}/${TARGET_VERSION}/${2}"

  if curl --silent --fail --output "${local_file}" "${remote_file}"; then
    printf -- "- File '%s' successfully downloaded.\n" "${1}"
  else
    printf -- "- File '%s' download failed.\n\n" "${1}"
    printf "'%s' installation script finished with error.\n\n" "${APP_NAME}"

    exit 1
  fi
}

download_files() {
  printf "4. Downloading files:\n"

  download_file "docker-compose.${APP_NAME}.yaml" docker-compose.yaml
  download_file "docker-compose.${APP_NAME}.prod.yaml" "docker-compose.${APP_NAME}.prod.yaml"
  download_file ".env.${APP_NAME}.template" ".env.${APP_NAME}.template"
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
  download_file "scripts/make/${APP_NAME}.mk" scripts/make/prod.mk
  download_file "scripts/update_${APP_NAME}.sh" scripts/update.sh
  chmod +x "scripts/update_${APP_NAME}.sh"

  printf "Downloads done!\n\n"
}

customize_settings() {
  # Activate environment file
  cp ".env.${APP_NAME}.template" ".env.${APP_NAME}"

  # Set Edge Router Directory
  sed -i.bak "s|^TRAEFIK_DIR.*|TRAEFIK_DIR=${TRAEFIK_DIR}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  # Load defaults
  # shellcheck source=.env.traefik
  source ".env.${APP_NAME}"

  # Setup environment variables
  printf "5. Set Environment variables (default passwords are generated randomly):\n\n"

  ## Version
  sed -i.bak "s|^IQB_TRAEFIK_VERSION_TAG=.*|IQB_TRAEFIK_VERSION_TAG=${TARGET_VERSION}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  ## Server
  printf "5.1 Server base domain name:\n"
  read -p "SERVER_NAME: " -er -i "${SERVER_NAME}" SERVER_NAME
  sed -i.bak "s|^SERVER_NAME=.*|SERVER_NAME=${SERVER_NAME}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  ## Ports
  printf "\n5.2 Ports:\n"
  read -p "HTTP_PORT: " -er -i "${HTTP_PORT}" HTTP_PORT
  sed -i.bak "s|^HTTP_PORT=.*|HTTP_PORT=${HTTP_PORT}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  read -p "HTTPS_PORT: " -er -i "${HTTPS_PORT}" HTTPS_PORT
  sed -i.bak "s|^HTTPS_PORT=.*|HTTPS_PORT=${HTTPS_PORT}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  ## Network
  printf "\n5.3 Network:\n"
  printf "Docker MTU have to be equal or less host network MTU!\n"
  printf "Current host network MTUs:\n"
  ip a | grep mtu | grep -v "lo:\|docker\|veth\|br-" | cut -f6- -d ' ' --complement
  read -p "DOCKER_DAEMON_MTU: " -er -i 1500 DOCKER_DAEMON_MTU
  sed -i.bak "s|^DOCKER_DAEMON_MTU=.*|DOCKER_DAEMON_MTU=${DOCKER_DAEMON_MTU}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  ## Super User
  printf "\n5.4 Super User (admin of admins):\n"
  read -p "ADMIN_NAME: " -er -i "${ADMIN_NAME}" ADMIN_NAME
  sed -i.bak "s|^ADMIN_NAME=.*|ADMIN_NAME=${ADMIN_NAME}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  read -p "ADMIN_EMAIL: " -er -i "${ADMIN_EMAIL}" ADMIN_EMAIL
  sed -i.bak "s|^ADMIN_EMAIL=.*|ADMIN_EMAIL=${ADMIN_EMAIL}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  ADMIN_PASSWORD=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 16 | head -n 1)
  read -p "ADMIN_PASSWORD: " -er -i "${ADMIN_PASSWORD}" ADMIN_PASSWORD
  sed -i.bak "s|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASSWORD}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  ADMIN_CREATED_TIMESTAMP=$(date -u +"%s")000
  sed -i.bak "s|ADMIN_CREATED_TIMESTAMP=.*|ADMIN_CREATED_TIMESTAMP=${ADMIN_CREATED_TIMESTAMP}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  printf "\n5.5 OpenID Connect with OAuth2 Authentication:\n"
  printf "5.5.1 Keycloak DB:\n"
  read -p "POSTGRES_USER: " -er -i "${POSTGRES_USER}" POSTGRES_USER
  sed -i.bak "s|^POSTGRES_USER=.*|POSTGRES_USER=${POSTGRES_USER}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  POSTGRES_PASSWORD=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 16 | head -n 1)
  read -p "POSTGRES_PASSWORD: " -er -i "${POSTGRES_PASSWORD}" POSTGRES_PASSWORD
  sed -i.bak "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  read -p "POSTGRES_DB: " -er -i "${POSTGRES_DB}" POSTGRES_DB
  sed -i.bak "s|^POSTGRES_DB=.*|POSTGRES_DB=${POSTGRES_DB}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  printf "\n5.5.2 OAuth2 Clients:\n"
  printf "Client IDs will be BASE64 encoded.\n"
  printf "\n5.5.2.1 Traefik Dashboard Client:\n"
  read -p "TRAEFIK_CLIENT_ID: " -er -i "${TRAEFIK_CLIENT_ID}" TRAEFIK_CLIENT_ID
  TRAEFIK_CLIENT_ID=$(printf '%s' "${TRAEFIK_CLIENT_ID}" | openssl base64)
  sed -i.bak "s|^TRAEFIK_CLIENT_ID=.*|TRAEFIK_CLIENT_ID=${TRAEFIK_CLIENT_ID}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  TRAEFIK_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  sed -i.bak "s|^TRAEFIK_CLIENT_SECRET=.*|TRAEFIK_CLIENT_SECRET=${TRAEFIK_CLIENT_SECRET}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  TRAEFIK_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  sed -i.bak "s|^TRAEFIK_COOKIE_SECRET=.*|TRAEFIK_COOKIE_SECRET=${TRAEFIK_COOKIE_SECRET}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  read -p "TRAEFIK_EMAIL_DOMAIN: " -er -i "${TRAEFIK_EMAIL_DOMAIN}" TRAEFIK_EMAIL_DOMAIN
  sed -i.bak "s|^TRAEFIK_EMAIL_DOMAIN=.*|TRAEFIK_EMAIL_DOMAIN=${TRAEFIK_EMAIL_DOMAIN}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  printf "\n5.5.2.2 Grafana Client:\n"
  read -p "GRAFANA_CLIENT_ID: " -er -i "${GRAFANA_CLIENT_ID}" GRAFANA_CLIENT_ID
  GRAFANA_CLIENT_ID=$(printf '%s' "${GRAFANA_CLIENT_ID}" | openssl base64)
  sed -i.bak "s|^GRAFANA_CLIENT_ID=.*|GRAFANA_CLIENT_ID=${GRAFANA_CLIENT_ID}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  GRAFANA_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  sed -i.bak "s|^GRAFANA_CLIENT_SECRET=.*|GRAFANA_CLIENT_SECRET=${GRAFANA_CLIENT_SECRET}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  printf "\n5.5.2.3 Prometheus Client:\n"
  read -p "PROMETHEUS_CLIENT_ID: " -er -i "${PROMETHEUS_CLIENT_ID}" PROMETHEUS_CLIENT_ID
  PROMETHEUS_CLIENT_ID=$(printf '%s' "${PROMETHEUS_CLIENT_ID}" | openssl base64)
  sed -i.bak "s|^PROMETHEUS_CLIENT_ID=.*|PROMETHEUS_CLIENT_ID=${PROMETHEUS_CLIENT_ID}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  PROMETHEUS_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  sed -i.bak "s|^PROMETHEUS_CLIENT_SECRET=.*|PROMETHEUS_CLIENT_SECRET=${PROMETHEUS_CLIENT_SECRET}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  PROMETHEUS_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  sed -i.bak "s|^PROMETHEUS_COOKIE_SECRET=.*|PROMETHEUS_COOKIE_SECRET=${PROMETHEUS_COOKIE_SECRET}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  read -p "PROMETHEUS_EMAIL_DOMAIN: " -er -i "${PROMETHEUS_EMAIL_DOMAIN}" PROMETHEUS_EMAIL_DOMAIN
  sed -i.bak "s|^PROMETHEUS_EMAIL_DOMAIN=.*|PROMETHEUS_EMAIL_DOMAIN=${PROMETHEUS_EMAIL_DOMAIN}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  printf "\n5.5.2.4 Node Exporter Client:\n"
  read -p "NODE_EXPORTER_CLIENT_ID: " -er -i "${NODE_EXPORTER_CLIENT_ID}" NODE_EXPORTER_CLIENT_ID
  NODE_EXPORTER_CLIENT_ID=$(printf '%s' "${NODE_EXPORTER_CLIENT_ID}" | openssl base64)
  sed -i.bak "s|^NODE_EXPORTER_CLIENT_ID=.*|NODE_EXPORTER_CLIENT_ID=${NODE_EXPORTER_CLIENT_ID}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  NODE_EXPORTER_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  sed -i.bak "s|^NODE_EXPORTER_CLIENT_SECRET=.*|NODE_EXPORTER_CLIENT_SECRET=${NODE_EXPORTER_CLIENT_SECRET}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  NODE_EXPORTER_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  sed -i.bak "s|^NODE_EXPORTER_COOKIE_SECRET=.*|NODE_EXPORTER_COOKIE_SECRET=${NODE_EXPORTER_COOKIE_SECRET}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  read -p "NODE_EXPORTER_EMAIL_DOMAIN: " -er -i "${NODE_EXPORTER_EMAIL_DOMAIN}" NODE_EXPORTER_EMAIL_DOMAIN
  sed -i.bak "s|^NODE_EXPORTER_EMAIL_DOMAIN=.*|NODE_EXPORTER_EMAIL_DOMAIN=${NODE_EXPORTER_EMAIL_DOMAIN}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  printf "\n5.5.2.5 cAdvisor Client:\n"
  read -p "CADVISOR_CLIENT_ID: " -er -i "${CADVISOR_CLIENT_ID}" CADVISOR_CLIENT_ID
  CADVISOR_CLIENT_ID=$(printf '%s' "${CADVISOR_CLIENT_ID}" | openssl base64)
  sed -i.bak "s|^CADVISOR_CLIENT_ID=.*|CADVISOR_CLIENT_ID=${CADVISOR_CLIENT_ID}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  CADVISOR_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  sed -i.bak "s|^CADVISOR_CLIENT_SECRET=.*|CADVISOR_CLIENT_SECRET=${CADVISOR_CLIENT_SECRET}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  CADVISOR_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  sed -i.bak "s|^CADVISOR_COOKIE_SECRET=.*|CADVISOR_COOKIE_SECRET=${CADVISOR_COOKIE_SECRET}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  read -p "CADVISOR_EMAIL_DOMAIN: " -er -i "${CADVISOR_EMAIL_DOMAIN}" CADVISOR_EMAIL_DOMAIN
  sed -i.bak "s|^CADVISOR_EMAIL_DOMAIN=.*|CADVISOR_EMAIL_DOMAIN=${CADVISOR_EMAIL_DOMAIN}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  printf "\n5.5.2.6 Dozzle Client:\n"
  read -p "DOZZLE_CLIENT_ID: " -er -i "${DOZZLE_CLIENT_ID}" DOZZLE_CLIENT_ID
  DOZZLE_CLIENT_ID=$(printf '%s' "${DOZZLE_CLIENT_ID}" | openssl base64)
  sed -i.bak "s|^DOZZLE_CLIENT_ID=.*|DOZZLE_CLIENT_ID=${DOZZLE_CLIENT_ID}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  DOZZLE_CLIENT_SECRET=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)
  sed -i.bak "s|^DOZZLE_CLIENT_SECRET=.*|DOZZLE_CLIENT_SECRET=${DOZZLE_CLIENT_SECRET}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  DOZZLE_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_')
  sed -i.bak "s|^DOZZLE_COOKIE_SECRET=.*|DOZZLE_COOKIE_SECRET=${DOZZLE_COOKIE_SECRET}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  read -p "DOZZLE_EMAIL_DOMAIN: " -er -i "${DOZZLE_EMAIL_DOMAIN}" DOZZLE_EMAIL_DOMAIN
  sed -i.bak "s|^DOZZLE_EMAIL_DOMAIN=.*|DOZZLE_EMAIL_DOMAIN=${DOZZLE_EMAIL_DOMAIN}|" \
    ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

  # Setup makefiles
  sed -i.bak "s|^${MAKE_BASE_DIR_NAME} :=.*|${MAKE_BASE_DIR_NAME} := \\${APP_DIR}|" \
    "scripts/make/${APP_NAME}.mk" && rm "scripts/make/${APP_NAME}.mk.bak"
  sed -i.bak "s|scripts/update.sh|scripts/update_${APP_NAME}.sh|" \
    "scripts/make/${APP_NAME}.mk" && rm "scripts/make/${APP_NAME}.mk.bak"

  if [ -f Makefile ]; then
    printf "include %s/scripts/make/%s.mk\n" "${APP_DIR}" "${APP_NAME}" >>Makefile
  else
    printf "include %s/scripts/make/%s.mk\n" "${APP_DIR}" "${APP_NAME}" >Makefile
  fi

  ## TLS Certificate Resolver Configuration
  printf "\n6 TLS Configuration:\n"
  printf "6.1 Automatic Certificate Management Environment (ACME):\n"
  read -p "Do you want to use an ACME-Provider like 'Let's encrypt' or 'Sectigo' instead of user-defined certificates? [Y/n]: " -r -n 1 -e TLS
  if [[ ! $TLS =~ ^[nN]$ ]]; then
    sed -i.bak "s|^TLS_CERTIFICATE_RESOLVER=.*|TLS_CERTIFICATE_RESOLVER=acme|" \
      ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

    read -p "TLS_ACME_CA_SERVER: " -er -i "${TLS_ACME_CA_SERVER}" TLS_ACME_CA_SERVER
    sed -i.bak "s|^TLS_ACME_CA_SERVER=.*|TLS_ACME_CA_SERVER=${TLS_ACME_CA_SERVER}|" \
      ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

    read -p "TLS_ACME_EAB_KID: " -er -i "${TLS_ACME_EAB_KID}" TLS_ACME_EAB_KID
    sed -i.bak "s|^TLS_ACME_EAB_KID=.*|TLS_ACME_EAB_KID=${TLS_ACME_EAB_KID}|" \
      ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

    read -p "TLS_ACME_EAB_HMAC_ENCODED: " -er -i "${TLS_ACME_EAB_HMAC_ENCODED}" TLS_ACME_EAB_HMAC_ENCODED
    sed -i.bak "s|^TLS_ACME_EAB_HMAC_ENCODED=.*|TLS_ACME_EAB_HMAC_ENCODED=${TLS_ACME_EAB_HMAC_ENCODED}|" \
      ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

    read -p "TLS_ACME_EMAIL: " -er -i "${TLS_ACME_EMAIL}" TLS_ACME_EMAIL
    sed -i.bak "s|^TLS_ACME_EMAIL=.*|TLS_ACME_EMAIL=${TLS_ACME_EMAIL}|" \
      ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

    # Turn on strict Server Name Indication (SNI)
    sed -i.bak "s|sniStrict:.*|sniStrict: true|" \
      config/traefik/tls-options.yaml && rm config/traefik/tls-options.yaml.bak
  else
    sed -i.bak "s|^TLS_CERTIFICATE_RESOLVER=.*|TLS_CERTIFICATE_RESOLVER=|" \
      ".env.${APP_NAME}" && rm ".env.${APP_NAME}.bak"

    # Generate TLS files
    printf "\n6.2 User-defined certificates:\n"
    read -p "Do you have a user-defined TLS certificate and private key? [y/N] " -er -n 1 IS_TLS
    if [[ ! ${IS_TLS} =~ ^[yY]$ ]]; then
      printf "\nAn unsecure self-signed TLS certificate valid for 30 days will be generated ...\n"
      openssl req \
        -newkey rsa:2048 -nodes -subj "/CN=${SERVER_NAME}" -keyout "${APP_DIR}/secrets/traefik/certs/private_key.pem" \
        -x509 -days 30 -out "${APP_DIR}/secrets/traefik/certs/certificate.pem"
      printf "A self-signed certificate file and a private key file have been generated.\n"

    else
      printf "Generated certificate placeholder file.\nReplace this text with real content if necessary.\n" \
        >"${APP_DIR}/secrets/traefik/certs/certificate.pem"
      printf "Generated key placeholder file.\nReplace this text with real content if necessary.\n" \
        >"${APP_DIR}/secrets/traefik/certs/private_key.pem"
      printf "\nA certificate placeholder file and a private key placeholder file have been generated.\n"
      printf "Please replace the content of the placeholder files 'secrets/traefik/certs/certificate.pem' "
      printf "and 'secrets/traefik/certs/private_key.pem' with your existing certificate and private key!\n"
    fi
  fi

  printf "\n"
}

application_start() {
  printf "'%s' installation done.\n\n" "${APP_NAME}"

    declare is_start_now
    read -p "Do you want to start ${APP_NAME} now? [Y/n] " -er -n 1 is_start_now
    printf '\n'
    if [[ ! ${is_start_now} =~ [nN] ]]; then
      if ! test "$(docker network ls -q --filter name=app-net)"; then
        docker network create app-net
      fi
      docker compose \
        --env-file ".env.${APP_NAME}" \
        --file "docker-compose.${APP_NAME}.yaml" \
        --file "docker-compose.${APP_NAME}.prod.yaml" \
        pull
      docker compose \
        --env-file ".env.${APP_NAME}" \
        --file "docker-compose.${APP_NAME}.yaml" \
        --file "docker-compose.${APP_NAME}.prod.yaml" \
        up -d
    else
      printf "'%s' installation script finished.\n" "${APP_NAME}"
      exit 0
    fi
}

main() {
  if [ -z "${TARGET_VERSION}" ]; then
    printf "\n==================================================\n"
    printf "'%s' installation script started ..." "${APP_NAME}" | tr '[:lower:]' '[:upper:]'
    printf "\n==================================================\n"
    printf "\n"

    get_release_version

    check_prerequisites

    prepare_installation_dir

    download_files

    customize_settings

    application_start

  else

    check_prerequisites

    prepare_installation_dir

    download_files

    customize_settings

    application_start

  fi
}

main
