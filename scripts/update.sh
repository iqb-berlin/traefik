#!/bin/bash

APP_NAME='traefik'

SELECTED_VERSION=$1
REPO_URL="https://raw.githubusercontent.com/iqb-berlin/$APP_NAME"
REPO_API="https://api.github.com/repos/iqb-berlin/$APP_NAME"
HAS_ENV_FILE_UPDATE=false
HAS_CONFIG_FILE_UPDATE=false

get_new_release_version() {
  LATEST_RELEASE=$(curl -s "$REPO_API"/releases/latest | grep tag_name | cut -d : -f 2,3 | tr -d \" | tr -d , | tr -d " ")

  if [ "$SOURCE_TAG" = "latest" ]; then
    SOURCE_TAG="$LATEST_RELEASE"
  fi

  printf "Installed version: %s\n" "$SOURCE_TAG"
  printf "Latest available release: %s\n\n" "$LATEST_RELEASE"

  if [ "$SOURCE_TAG" = "$LATEST_RELEASE" ]; then
    echo "Latest release is already installed!"
    read -p "Continue anyway? [Y/n] " -er -n 1 CONTINUE

    if [[ $CONTINUE =~ ^[nN]$ ]]; then
      echo 'Update script finished.'
      exit 0
    fi

    printf "\n"
  fi

  while read -p 'Name the desired version: ' -er -i "${LATEST_RELEASE}" TARGET_TAG; do
    if ! curl --head --silent --fail --output /dev/null $REPO_URL/"$TARGET_TAG"/README.md 2>/dev/null; then
      echo "This version tag does not exist."

    else
      break
    fi

  done
}

create_backup() {
  mkdir -p ./backup/release/"$SOURCE_TAG"
  tar -cf - --exclude='./backup' . | tar -xf - -C ./backup/release/"$SOURCE_TAG"
  printf "\nBackup created!\nCurrent release files have been saved at: '%s'\n\n" "$PWD/backup/release/$SOURCE_TAG"
}

run_update_script_in_selected_version() {
  CURRENT_UPDATE_SCRIPT=./backup/release/"$SOURCE_TAG"/update_$APP_NAME.sh
  NEW_UPDATE_SCRIPT=$REPO_URL/"$TARGET_TAG"/scripts/update.sh

  if [ ! -f "$CURRENT_UPDATE_SCRIPT" ] || ! curl --stderr /dev/null "$NEW_UPDATE_SCRIPT" | diff -q - "$CURRENT_UPDATE_SCRIPT" &>/dev/null; then
    if [ ! -f "$CURRENT_UPDATE_SCRIPT" ]; then
      echo "Update script 'update_$APP_NAME.sh' does not exist!"

    elif ! curl --stderr /dev/null "$NEW_UPDATE_SCRIPT" | diff -q - "$CURRENT_UPDATE_SCRIPT" &>/dev/null; then
      echo 'Update script has been modified in newer version!'
    fi

    printf "The running update script will download the desired update script, terminate itself, and start the new one!\n\n"
    echo 'Downloading the desired update script ...'
    if wget -q -O update_$APP_NAME.sh "$NEW_UPDATE_SCRIPT"; then
      chmod +x update_$APP_NAME.sh
      echo 'Download successful!'
    else
      echo 'Download failed!'
      echo 'Update script finished with error'
      exit 1
    fi

    printf "\nDownloaded update script version %s will be started now.\n\n" "$TARGET_TAG"
    ./update_$APP_NAME.sh "$TARGET_TAG"
    exit $?
  fi
}

prepare_installation_dir() {
  if [ -d ./grafana/ ]; then
    mv ./grafana/ ./config/grafana/
  else
    mkdir -p ./config/grafana/provisioning/dashboards
    mkdir -p ./config/grafana/provisioning/datasources
  fi
  if [ -d ./prometheus/ ]; then
    mv ./prometheus/ ./config/prometheus/
  else
    mkdir -p ./config/prometheus
  fi
  mkdir -p ./config/traefik
  mkdir -p ./scripts
  mkdir -p ./secrets/traefik
}

download_file() {
  if wget -q -O "$1" $REPO_URL/"$TARGET_TAG"/"$2"; then
    printf -- "- File '%s' successfully downloaded.\n" "$1"
  else
    printf -- "- File '%s' download failed.\n\n" "$1"
    echo 'Update script finished with error'
    exit 1
  fi
}

update_files() {
  echo "Downloading files ..."

  download_file docker-compose.traefik.yml docker-compose.yml
  download_file docker-compose.traefik.prod.yml docker-compose.traefik.prod.yml
  download_file scripts/traefik.mk scripts/make/prod.mk

  printf "Downloads done!\n\n"
}

get_modified_file() {
  SOURCE_FILE=./backup/release/"$SOURCE_TAG"/"$1"
  TARGET_FILE=$REPO_URL/"$TARGET_TAG"/"$2"
  CURRENT_ENV_FILE=.env.traefik
  CURRENT_CONFIG_FILE=config/frontend/default.conf.template

  if [ ! -f "$SOURCE_FILE" ] || ! (curl --stderr /dev/null "$TARGET_FILE" | diff -q - "$SOURCE_FILE" &>/dev/null); then

    # no source file exists anymore
    if [ ! -f "$SOURCE_FILE" ]; then
      if [ "$3" == "env-file" ]; then
        printf -- "- Environment template file '%s' does not exist anymore!\n" "$1"
        printf "  A version %s environment template file will be downloaded now.\n" "$TARGET_TAG"
        printf "  Please compare your current '%s' file with the new template file and update it with new environment variables, or delete obsolete variables, if necessary.\n" $CURRENT_ENV_FILE
      fi

      if [ "$3" == "conf-file" ]; then
        printf -- "- Configuration template file '%s' does not exist anymore!\n" "$1"
        printf "  A version %s configuration template file will be downloaded now.\n" "$TARGET_TAG"
        printf "  Please compare your current '%s' file with the new template file and update it, if necessary!\n" $CURRENT_CONFIG_FILE
      fi

    # source file and target file differ
    elif ! curl --stderr /dev/null "$TARGET_FILE" | diff -q - "$SOURCE_FILE" &>/dev/null; then
      if [ "$3" == "env-file" ]; then
        printf -- "- A new version of the current environment template file '%s' is available and will be downloaded now!\n" "$1"
        printf "  Please compare your current '%s' file with the new template file and update it with new environment variables, or delete obsolete variables, if necessary.\n" $CURRENT_ENV_FILE
      fi

      if [ "$3" == "conf-file" ]; then
        mv "$1" "$1".old 2>/dev/null
        cp $CURRENT_CONFIG_FILE ${CURRENT_CONFIG_FILE}.old
        printf -- "- A new version of the current configuration template file '%s' is available and will be downloaded now!\n" "$1"
        printf "  Please compare your current '%s' file with the new template file and update it, if necessary!\n" $CURRENT_CONFIG_FILE
      fi

    fi

    if wget -q -O "$1" "$TARGET_FILE"; then
      printf "  File '%s' was downloaded successfully.\n" "$1"

      if [ "$3" == "env-file" ]; then
        HAS_ENV_FILE_UPDATE=true
      fi

      if [ "$3" == "conf-file" ]; then
        HAS_CONFIG_FILE_UPDATE=true
      fi

    else
      printf "  File '%s' download failed.\n\n" "$1"
      echo 'Update script finished with error'
      exit 1

    fi

  else
    if [ "$3" == "env-file" ]; then
      printf -- "- No update of environment template file '%s' available.\n" "$1"
    fi

    if [ "$3" == "conf-file" ]; then
      printf -- "- No update of configuration template file '%s' available.\n" "$1"
    fi

  fi
}

check_template_files_modifications() {
  echo "Check template files for updates ..."

  # check environment file
  get_modified_file .env.traefik.template .env.traefik.template "env-file"

  # check configuration files
  get_modified_file config/traefik/tls-config.yml config/traefik/tls-config.yml "conf-file"
  get_modified_file config/prometheus/prometheus.yml config/prometheus/prometheus.yml "conf-file"
  get_modified_file config/grafana/config.monitoring config/grafana/config.monitoring "conf-file"
  get_modified_file config/grafana/provisioning/dashboards/dashboard.yml config/grafana/provisioning/dashboards/dashboard.yml "conf-file"
  get_modified_file config/grafana/provisioning/dashboards/traefik_rev4.json config/grafana/provisioning/dashboards/traefik_rev4.json "conf-file"
  get_modified_file config/grafana/provisioning/datasources/datasource.yml config/grafana/provisioning/datasources/datasource.yml "conf-file"

  printf "Template files update check done.\n\n"
}

customize_settings() {
  # Set application BASE_DIR
  sed -i "s#BASE_DIR :=.*#BASE_DIR := \.#" scripts/traefik.mk

  # write chosen version tag to env file
  sed -i "s#IQB_TRAEFIK_VERSION_TAG.*#IQB_TRAEFIK_VERSION_TAG=$TARGET_TAG#" .env.traefik

  # Generate TLS dummies
  if [ ! -f ./secrets/traefik/certificate.pem ]; then
    printf "Generated certificate placeholder file.\nReplace this text with real content if necessary.\n" >./secrets/traefik/certificate.pem
  fi
  if [ ! -f ./secrets/traefik/privkey.pem ]; then
    printf "Generated key placeholder file.\nReplace this text with real content if necessary.\n" >./secrets/traefik/privkey.pem
  fi
}

finalize_update() {
  if [ $HAS_ENV_FILE_UPDATE == "true" ] || [ $HAS_CONFIG_FILE_UPDATE == "true" ]; then
    if [ $HAS_ENV_FILE_UPDATE == "true" ] && [ $HAS_CONFIG_FILE_UPDATE == "true" ]; then
      echo 'Version, environment, and configuration update applied!'
      printf "\nPlease check your environment and configuration file for modifications!\n"
    elif [ $HAS_ENV_FILE_UPDATE == "true" ]; then
      echo 'Version and environment update applied!'
      printf "\nPlease check your environment file for modifications!\n"
    elif [ $HAS_CONFIG_FILE_UPDATE == "true" ]; then
      echo 'Version and configuration update applied!'
      printf "\nPlease check your configuration file for modifications!\n"
    fi

    if command make -v >/dev/null 2>&1; then
      printf "\nWhen your files are checked, you could restart the application with 'make %s-up' at the " $APP_NAME
      printf "command line to put the update into effect.\n\n"

    else
      printf '\nWhen your files are checked, you could restart the docker services to put the update into effect.\n\n'
    fi

    echo 'The application will now shut down ...'
    make traefik-down

    echo 'Update script finished.'
    exit 0

  else
    printf "Version update applied.\n\n"
    application_reload
  fi
}

application_reload() {
  if command make -v >/dev/null 2>&1; then
    read -p "Do you want to reload $APP_NAME now? [Y/n] " -er -n 1 RELOAD

    if [[ ! $RELOAD =~ [nN] ]]; then
      make traefik-up

    else
      echo 'Update script finished.'
      exit 0
    fi

  else
    printf 'You could start the updated docker services now.\n\n'
    echo 'Update script finished.'
    exit 0
  fi
}

application_restart() {
  if command make -v >/dev/null 2>&1; then
    read -p "Do you want to restart $APP_NAME now? [Y/n] " -er -n 1 RESTART

    if [[ ! $RESTART =~ [nN] ]]; then
      make traefik-down
      make traefik-up

    else
      echo 'Update script finished.'
      exit 0
    fi

  else
    printf 'You can restart the docker services now.\n\n'
    echo 'Update script finished.'
    exit 0
  fi
}

generate_tls_certificate() {
  if command openssl x509 -in secrets/traefik/certificate.pem -text -noout >/dev/null 2>&1 &&
    command openssl rsa -in secrets/traefik/privkey.pem -check >/dev/null 2>&1; then
    printf "A TLS certificate and private key are already present!\n"
    read -p "Do you really want to replace them? [y/N] " -er -n 1 REPLACE

    if [[ ! $REPLACE =~ ^[yY]$ ]]; then
      printf "\nThe existing self-signed certificate and private key have not been replaced.\n\n"
      return
    fi
  fi

  printf "An unsecure self-signed TLS certificate valid for 30 days will be generated ...\n"
  openssl req \
    -newkey rsa:2048 -nodes -subj "/CN=$SERVER_NAME" -keyout secrets/traefik/privkey.pem \
    -x509 -days 30 -out secrets/traefik/certificate.pem
  printf "A self-signed certificate file and a private key file have been generated.\n\n"
}

generate_admin_credentials() {
  read -p "Traefik administrator name: " -er TRAEFIK_ADMIN_NAME
  read -p "Traefik administrator password: " -er TRAEFIK_ADMIN_PASSWORD

  BASIC_AUTH_CRED=$TRAEFIK_ADMIN_NAME:$(openssl passwd -apr1 "$TRAEFIK_ADMIN_PASSWORD" | sed -e s/\\$/\\$\\$/g)
  printf "TRAEFIK_AUTH: %s\n\n" "$BASIC_AUTH_CRED"
  sed -i "s#TRAEFIK_AUTH.*#TRAEFIK_AUTH=$BASIC_AUTH_CRED#" .env.traefik

  printf "The traefik administrator credentials have been updated.\n\n"
}

main() {
  # Load current environment variables in .env.traefik
  source .env.traefik
  SOURCE_TAG=$IQB_TRAEFIK_VERSION_TAG

  if [ -z "$SELECTED_VERSION" ]; then
    printf "Update script started ...\n\n"
    printf "[1] Update %s\n" $APP_NAME
    printf "[2] Update the self-signed TLS certificate valid for 30 days\n"
    printf "[3] Update the %s administrator credentials\n\n" $APP_NAME
    printf "[4] Exit update script\n\n"

    while read -p 'What do you want to do? [1-4] ' -er -n 1 CHOICE; do
      if [ "$CHOICE" = 1 ]; then
        printf "\n=== UPDATE %s ===\n\n" $APP_NAME

        get_new_release_version
        create_backup
        run_update_script_in_selected_version
        prepare_installation_dir
        update_files
        check_template_files_modifications
        customize_settings
        finalize_update

        break

      elif [ "$CHOICE" = 2 ]; then
        printf "\n=== UPDATE SELF-SIGNED TLS CERTIFICATE ===\n\n"

        generate_tls_certificate
        application_restart

        break

      elif [ "$CHOICE" = 3 ]; then
        printf "\n=== UPDATE TRAEFIK CREDENTIALS ===\n\n"
        generate_admin_credentials
        application_restart

        break

      elif [ "$CHOICE" = 4 ]; then
        echo 'Installation script finished.'

        exit 0

      fi

    done

  else
    TARGET_TAG="$SELECTED_VERSION"

    prepare_installation_dir
    update_files
    check_template_files_modifications
    customize_settings
    finalize_update
  fi
}

main
