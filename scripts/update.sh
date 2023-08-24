#!/bin/bash

APP_NAME='traefik'

SELECTED_VERSION=$1
REPO_URL="https://raw.githubusercontent.com/iqb-berlin/$APP_NAME"
REPO_API="https://api.github.com/repos/iqb-berlin/$APP_NAME"
HAS_ENV_FILE_UPDATE=false
HAS_CONFIG_FILE_UPDATE=false

load_environment_variables() {
  # Load current environment variables in .env.traefik
  source .env.traefik
  SOURCE_TAG=$IQB_TRAEFIK_VERSION_TAG
}

get_new_release_version() {
  LATEST_RELEASE=$(curl -s "$REPO_API"/releases/latest | grep tag_name | cut -d : -f 2,3 | tr -d \" | tr -d , | tr -d " ")

  if [ "$SOURCE_TAG" = "latest" ]; then
    SOURCE_TAG="$LATEST_RELEASE"
  fi

  printf "Installed version: %s\n" "$SOURCE_TAG"
  printf "Latest available release: %s\n\n" "$LATEST_RELEASE"

  if [ "$SOURCE_TAG" = "$LATEST_RELEASE" ]; then
    printf "Latest release is already installed!\n"
    read -p "Continue anyway? [Y/n] " -er -n 1 CONTINUE

    if [[ $CONTINUE =~ ^[nN]$ ]]; then
      printf "'%s' update script finished.\n" $APP_NAME
      exit 0
    fi

    printf "\n"
  fi

  while read -p '1. Name the desired version: ' -er -i "${LATEST_RELEASE}" TARGET_TAG; do
    if ! curl --head --silent --fail --output /dev/null $REPO_URL/"$TARGET_TAG"/README.md 2>/dev/null; then
      printf "This version tag does not exist.\n"

    else
      printf "\n"
      break
    fi

  done
}

create_backup() {
  printf "2. Backup creation\n"
  mkdir -p ./backup/release/"$SOURCE_TAG"
  tar -cf - --exclude='./backup' . | tar -xf - -C ./backup/release/"$SOURCE_TAG"
  printf -- "- Current release files have been saved at: '%s'\n" "$PWD/backup/release/$SOURCE_TAG"
  printf "Backup created.\n\n"
}

run_update_script_in_selected_version() {
  CURRENT_UPDATE_SCRIPT=./backup/release/"$SOURCE_TAG"/update_$APP_NAME.sh
  NEW_UPDATE_SCRIPT=$REPO_URL/"$TARGET_TAG"/scripts/update.sh

  printf "3. Update script modification check\n"
  if [ ! -f "$CURRENT_UPDATE_SCRIPT" ] || ! curl --stderr /dev/null "$NEW_UPDATE_SCRIPT" | diff -q - "$CURRENT_UPDATE_SCRIPT" &>/dev/null; then
    if [ ! -f "$CURRENT_UPDATE_SCRIPT" ]; then
      printf -- "- Current update script 'update_%s.sh' does not exist (anymore)!\n" $APP_NAME

    elif ! curl --stderr /dev/null "$NEW_UPDATE_SCRIPT" | diff -q - "$CURRENT_UPDATE_SCRIPT" &>/dev/null; then
      printf -- '- Current update script is outdated!\n'
    fi

    printf '  Downloading a new update script in the selected version ...\n'
    if wget -q -O update_$APP_NAME.sh "$NEW_UPDATE_SCRIPT"; then
      chmod +x update_$APP_NAME.sh
      printf '  Download successful!\n'
    else
      printf '  Download failed!\n'
      printf "  '%s' update script finished with error.\n" $APP_NAME
      exit 1
    fi

    printf "  Current update script will now call the downloaded update script and terminate itself.\n"
    printf "Update script modification check done.\n\n"

    ./update_$APP_NAME.sh "$TARGET_TAG"
    exit $?

  else
    printf -- "- Update script has not been changed in the selected version\n"
    printf "Update script modification check done.\n\n"
  fi
}

prepare_installation_dir() {
  if [ -d ./grafana/ ]; then
    mv ./grafana/ ./config/grafana/
  else
    mkdir -p ./config/grafana/provisioning/dashboards
    mkdir -p ./config/grafana/provisioning/datasources
  fi
  mkdir -p ./config/maintenance-page
  if [ -d ./prometheus/ ]; then
    mv ./prometheus/ ./config/prometheus/
  else
    mkdir -p ./config/prometheus
  fi
  mkdir -p ./config/traefik
  mkdir -p ./scripts
  mkdir -p ./secrets/traefik
  rm Makefile
}

download_file() {
  if wget -q -O "$1" $REPO_URL/"$TARGET_TAG"/"$2"; then
    printf -- "- File '%s' successfully downloaded.\n" "$1"
  else
    printf -- "- File '%s' download failed.\n\n" "$1"
    printf "'%s' update script finished with error.\n" $APP_NAME
    exit 1
  fi
}

update_files() {
  printf "4. File download\n"

  download_file docker-compose.traefik.yaml docker-compose.yaml
  download_file docker-compose.traefik.prod.yaml docker-compose.traefik.prod.yaml
  download_file scripts/traefik.mk scripts/make/prod.mk

  printf "File download done.\n\n"
}

get_modified_file() {
  SOURCE_FILE="$1"
  TARGET_FILE=$REPO_URL/"$TARGET_TAG"/"$2"
  FILE_TYPE="$3"
  CURRENT_ENV_FILE=.env.traefik

  if [ ! -f "$SOURCE_FILE" ] || ! (curl --stderr /dev/null "$TARGET_FILE" | diff -q - "$SOURCE_FILE" &>/dev/null); then

    # no source file exists anymore
    if [ ! -f "$SOURCE_FILE" ]; then
      if [ "$FILE_TYPE" == "env-file" ]; then
        printf -- "- Environment template file '%s' does not exist anymore.\n" "$SOURCE_FILE"
        printf "  A version %s environment template file will be downloaded now ...\n" "$TARGET_TAG"
        printf "  Please compare your current environment file with the new template file and update it "
        printf "with new environment variables, or delete obsolete variables, if necessary.\n"
        printf "  For comparison use e.g. 'diff %s %s'.\n" $CURRENT_ENV_FILE "$SOURCE_FILE"
      fi

      if [ "$FILE_TYPE" == "conf-file" ]; then
        printf -- "- Configuration file '%s' does not exist (anymore).\n" "$SOURCE_FILE"
        printf "  A version %s configuration file will be downloaded now ...\n" "$TARGET_TAG"
      fi

    # source file and target file differ
    elif ! curl --stderr /dev/null "$TARGET_FILE" | diff -q - "$SOURCE_FILE" &>/dev/null; then
      if [ "$FILE_TYPE" == "env-file" ]; then
        printf -- "- The current environment template file '%s' is outdated.\n" "$SOURCE_FILE"
        printf "  A version %s environment template file will be downloaded now ...\n" "$TARGET_TAG"
        printf "  Please compare your current environment file with the new template file and update it "
        printf "with new environment variables, or delete obsolete variables, if necessary.\n"
        printf "  For comparison use e.g. 'diff %s %s'.\n" $CURRENT_ENV_FILE "$SOURCE_FILE"
      fi

      if [ "$FILE_TYPE" == "conf-file" ]; then
        mv "$SOURCE_FILE" "$SOURCE_FILE".old 2>/dev/null
        printf -- "- The current configuration file '%s' was changed.\n" "$SOURCE_FILE"
        printf "  A version %s configuration file will be downloaded now ...\n" "$TARGET_TAG"
        printf "  Please compare the new file with your current (now old) file and modify the new one, if necessary!\n"
        printf "  For comparison use e.g. 'diff %s %s.old'.\n" "$SOURCE_FILE" "$SOURCE_FILE"
      fi

    fi

    if wget -q -O "$SOURCE_FILE" "$TARGET_FILE"; then
      printf "  File '%s' was downloaded successfully.\n" "$SOURCE_FILE"

      if [ "$FILE_TYPE" == "env-file" ]; then
        HAS_ENV_FILE_UPDATE=true
      fi

      if [ "$FILE_TYPE" == "conf-file" ]; then
        HAS_CONFIG_FILE_UPDATE=true
      fi

    else
      printf "  File '%s' download failed.\n\n" "$SOURCE_FILE"
      printf "'%s' update script finished with error.\n" $APP_NAME
      exit 1

    fi

  else
    if [ "$FILE_TYPE" == "env-file" ]; then
      printf -- "- The current environment template file '%s' is still up to date.\n" "$SOURCE_FILE"
    fi

    if [ "$FILE_TYPE" == "conf-file" ]; then
      printf -- "- The current configuration file '%s' is still up to date.\n" "$SOURCE_FILE"
    fi

  fi
}

check_template_files_modifications() {
  # check environment file
  printf "5. Environment template file modification check\n"
  get_modified_file .env.traefik.template .env.traefik.template "env-file"
  printf "Environment template file modification check done.\n\n"

  # check configuration files
  printf "6. Configuration files modification check\n"
  get_modified_file config/traefik/tls-config.yaml config/traefik/tls-config.yaml "conf-file"
  get_modified_file config/maintenance-page/default.conf.template config/maintenance-page/default.conf.template "conf-file"
  get_modified_file config/maintenance-page/maintenance.html config/maintenance-page/maintenance.html "conf-file"
  get_modified_file config/prometheus/prometheus.yaml config/prometheus/prometheus.yaml "conf-file"
  get_modified_file config/grafana/config.monitoring config/grafana/config.monitoring "conf-file"
  get_modified_file config/grafana/provisioning/dashboards/dashboard.yaml config/grafana/provisioning/dashboards/dashboard.yaml "conf-file"
  get_modified_file config/grafana/provisioning/dashboards/traefik_rev4.json config/grafana/provisioning/dashboards/traefik_rev4.json "conf-file"
  get_modified_file config/grafana/provisioning/datasources/datasource.yaml config/grafana/provisioning/datasources/datasource.yaml "conf-file"
  printf "Configuration files modification check done.\n\n"
}

customize_settings() {
  # Setup makefiles
  sed -i "s#TRAEFIK_BASE_DIR :=.*#TRAEFIK_BASE_DIR := \\$(pwd)#" scripts/traefik.mk
  if [ -f Makefile ]; then
    printf "include %s/scripts/traefik.mk\n" "$(pwd)" >>Makefile
  else
    printf "include %s/scripts/traefik.mk\n" "$(pwd)" >Makefile
  fi

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
  printf "7. Summary\n"
  if [ $HAS_ENV_FILE_UPDATE == "true" ] || [ $HAS_CONFIG_FILE_UPDATE == "true" ]; then
    if [ $HAS_ENV_FILE_UPDATE == "true" ] && [ $HAS_CONFIG_FILE_UPDATE == "true" ]; then
      printf -- '- Version, environment, and configuration update applied!\n\n'
      printf "  PLEASE CHECK YOUR ENVIRONMENT AND CONFIGURATION FILES FOR MODIFICATIONS ! ! !\n\n"
    elif [ $HAS_ENV_FILE_UPDATE == "true" ]; then
      printf -- '- Version and environment update applied!\n\n'
      printf "  PLEASE CHECK YOUR ENVIRONMENT FILE FOR MODIFICATIONS ! ! !\n\n"
    elif [ $HAS_CONFIG_FILE_UPDATE == "true" ]; then
      printf -- '- Version and configuration update applied!\n\n'
      printf "  PLEASE CHECK YOUR CONFIGURATION FILES FOR MODIFICATIONS ! ! !\n\n"
    fi
    printf "Summary done.\n\n\n"

    if [[ $(docker compose --project-name "${PWD##*/}" ps -q) ]]; then
      printf "'%s' infrastructure will now shut down ...\n" $APP_NAME
      docker compose --project-name "${PWD##*/}" down
    fi

    printf "When your files are checked for modification, you could restart the application with "
    printf "'make %s-up' at the command line to put the update into effect.\n\n" $APP_NAME

    printf "'%s' update script finished.\n" $APP_NAME
    exit 0

  else
    printf -- "- Version update applied.\n"
    printf "  No further action needed.\n"
    printf "Summary done.\n\n\n"

    application_reload
  fi
}

application_reload() {
  if command make -v >/dev/null 2>&1; then
    read -p "Do you want to reload $APP_NAME now? [Y/n] " -er -n 1 RELOAD

    if [[ ! $RELOAD =~ [nN] ]]; then
      make traefik-up

    else
      printf "'%s' update script finished.\n" $APP_NAME
      exit 0
    fi

  else
    printf 'You could start the updated docker services now.\n\n'
    printf "'%s' update script finished.\n" $APP_NAME
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
      printf "'%s' update script finished.\n" $APP_NAME
      exit 0
    fi

  else
    printf 'You can restart the docker services now.\n\n'
    printf "'%s' update script finished.\n" $APP_NAME
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
  if [ -z "$SELECTED_VERSION" ]; then
    printf "\n==================================================\n"
    printf '%s update script started ...' $APP_NAME | tr '[:lower:]' '[:upper:]'
    printf "\n==================================================\n"
    printf "\n"
    printf "[1] Update %s\n" $APP_NAME
    printf "[2] Update the self-signed TLS certificate valid for 30 days\n"
    printf "[3] Update the %s administrator credentials\n" $APP_NAME
    printf "[4] Exit update script\n\n"

    while read -p 'What do you want to do? [1-4] ' -er -n 1 CHOICE; do
      if [ "$CHOICE" = 1 ]; then
        printf "\n=== UPDATE %s ===\n\n" $APP_NAME

        load_environment_variables
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
        printf "'%s' update script finished.\n" $APP_NAME
        exit 0

      fi

    done

  else
    TARGET_TAG="$SELECTED_VERSION"

    prepare_installation_dir
    load_environment_variables
    update_files
    check_template_files_modifications
    customize_settings
    finalize_update
  fi
}

main
