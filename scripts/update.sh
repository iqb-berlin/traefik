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
  LATEST_RELEASE=$(curl -s "$REPO_API"/releases/latest |
    grep tag_name |
    cut -d : -f 2,3 |
    tr -d \" |
    tr -d , |
    tr -d " ")

  if [ "$SOURCE_TAG" = "latest" ]; then
    SOURCE_TAG="$LATEST_RELEASE"
  fi

  printf "Installed version: %s\n" "$SOURCE_TAG"
  printf "Latest available release: %s\n\n" "$LATEST_RELEASE"

  if [ "$SOURCE_TAG" = "$LATEST_RELEASE" ]; then
    printf "Latest release is already installed!\n"
    read -p "Continue anyway? [y/N] " -er -n 1 CONTINUE

    if [[ ! $CONTINUE =~ ^[yY]$ ]]; then
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
  declare current_update_script
  current_update_script="${BACKUP_DIR}/scripts/update_${APP_NAME}.sh"

  declare selected_update_script
  selected_update_script="${REPO_URL}/${TARGET_TAG}/scripts/update.sh"

  printf "3. Update script modification check\n"
  if [ ! -f "$current_update_script" ] ||
    ! curl --stderr /dev/null "$selected_update_script" | diff -q - "$current_update_script" &>/dev/null; then
    if [ ! -f "$current_update_script" ]; then
      printf -- "- Current update script 'update_%s.sh' does not exist (anymore)!\n" $APP_NAME

    elif ! curl --stderr /dev/null "$selected_update_script" | diff -q - "$current_update_script" &>/dev/null; then
      printf -- '- Current update script is outdated!\n'
    fi

    printf '  Downloading a new update script in the selected version ...\n'
    if curl --silent --fail --output "${APP_DIR}/scripts/update_${APP_NAME}.sh" "$selected_update_script"; then
      chmod +x "${APP_DIR}/scripts/update_${APP_NAME}.sh"
      printf '  Download successful!\n'
    else
      printf '  Download failed!\n'
      printf "  '%s' update script finished with error.\n" $APP_NAME
      exit 1
    fi

    printf "  Current update script will now call the downloaded update script and terminate itself.\n"
    declare continue
    read -p "  Do you want to continue? [Y/n] " -er -n 1 continue
    if [[ $continue =~ ^[nN]$ ]]; then
      printf "  You can check the the new update script (e.g.: 'less scripts/update_%s.sh') or " $APP_NAME
      printf "compare it with the old one (e.g.: 'diff %s %s').\n\n" \
        "scripts/update_${APP_NAME}.sh" "backup/release/$SOURCE_TAG/update_${APP_NAME}.sh"

      printf "  If you want to resume this update process, please type: 'bash scripts/update_%s.sh %s'\n\n" \
        $APP_NAME "$TARGET_TAG"

      printf "'%s' update script finished.\n" $APP_NAME
      exit 0
    fi

    printf "Update script modification check done.\n\n"

    bash "${APP_DIR}/scripts/update_${APP_NAME}.sh" "$TARGET_TAG"
    exit $?

  else
    printf -- "- Update script has not been changed in the selected version\n"
    printf "Update script modification check done.\n\n"
  fi
}

prepare_installation_dir() {
  mkdir -p ./config/grafana/provisioning/dashboards
  mkdir -p ./config/grafana/provisioning/datasources
  mkdir -p ./config/keycloak
  mkdir -p ./config/maintenance-page
  mkdir -p ./config/prometheus
  mkdir -p ./config/traefik
  mkdir -p ./scripts/make
  mkdir -p ./scripts/migration
  mkdir -p ./secrets/traefik/certs/acme
  pwd
  ls -la
  rm Makefile
}

download_file() {
  if curl --silent --fail --output "$1" $REPO_URL/"$TARGET_TAG"/"$2"; then
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
  download_file scripts/make/traefik.mk scripts/make/prod.mk

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
        printf -- "- The current configuration file '%s' has been changed.\n" "$SOURCE_FILE"
        printf "  A version %s configuration file will be downloaded now ...\n" "$TARGET_TAG"
        printf "  Please compare the new file with your current (now old) file and modify the new one, if necessary!\n"
        printf "  For comparison use e.g. 'diff %s %s.old'.\n" "$SOURCE_FILE" "$SOURCE_FILE"
      fi

    fi

    if curl --silent --fail --output "$SOURCE_FILE" "$TARGET_FILE"; then
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

check_environment_file_modifications() {
  # check environment file
  printf "5. Environment template file modification check\n"
  get_modified_file .env.traefik.template .env.traefik.template "env-file"
  printf "Environment template file modification check done.\n\n"
}

run_optional_migration_scripts() {
  printf "6. Optional migration scripts check\n"
  RELEASE_TAGS=$(curl -s $REPO_API/releases |
    grep tag_name |
    cut -d : -f 2,3 |
    tr -d \" |
    tr -d , |
    tr -d " " |
    sed -n -e "/$TARGET_TAG/,/$SOURCE_TAG/p" |
    head -n -1)

  if [ -n "$RELEASE_TAGS" ]; then
    for RELEASE_TAG in $RELEASE_TAGS; do
      declare -a MIGRATION_SCRIPTS
      MIGRATION_SCRIPT_CHECK_URL=$REPO_URL/"$TARGET_TAG"/scripts/migration/"$RELEASE_TAG".sh
      if curl --head --silent --fail --output /dev/null "$MIGRATION_SCRIPT_CHECK_URL" 2>/dev/null; then
        MIGRATION_SCRIPTS+=("$RELEASE_TAG".sh)
      fi
    done

    if [ ${#MIGRATION_SCRIPTS[@]} -eq 0 ]; then
      printf -- "- No additional migration scripts to execute.\n\n"

    else
      printf "6.1 The following migration scripts are executed for the migration from version %s to version %s:\n" "$SOURCE_TAG" "$TARGET_TAG"
      for MIGRATION_SCRIPT in "${MIGRATION_SCRIPTS[@]}"; do
        printf -- "- %s\n" "$MIGRATION_SCRIPT"
      done
      printf "\n6.2 Migration script download\n"
      mkdir -p scripts/migration
      for MIGRATION_SCRIPT in "${MIGRATION_SCRIPTS[@]}"; do
        download_file scripts/migration/"$MIGRATION_SCRIPT" scripts/migration/"$MIGRATION_SCRIPT"
        chmod +x scripts/migration/"$MIGRATION_SCRIPT"
      done

      printf "\n6.3 Migration script execution\n"
      for ((i = ${#MIGRATION_SCRIPTS[@]} - 1; i >= 0; i--)); do
        printf "Executing '%s' ...\n" "${MIGRATION_SCRIPTS[$i]}"
        bash scripts/migration/"${MIGRATION_SCRIPTS[$i]}"
        rm scripts/migration/"${MIGRATION_SCRIPTS[$i]}"
      done

      printf "\nMigration scripts successfully executed.\n\n"
      printf "\n------------------------------------------------------------\n"
      printf "Proceed with the original '%s' installation ..." $APP_NAME
      printf "\n------------------------------------------------------------\n"
      printf "\n"
    fi
  else
    printf -- "- No additional migration scripts to execute, because there are no releases between your current "
    printf "  version '%s' and your selected target version '%s'.\n\n" "$SOURCE_TAG" "$TARGET_TAG"
  fi
}

check_config_files_modifications() {
  # check configuration files
  printf "7. Configuration files modification check\n"
  get_modified_file config/grafana/provisioning/dashboards/dashboard.yaml config/grafana/provisioning/dashboards/dashboard.yaml "conf-file"
  get_modified_file config/grafana/provisioning/dashboards/traefik_rev4.json config/grafana/provisioning/dashboards/traefik_rev4.json "conf-file"
  get_modified_file config/grafana/provisioning/datasources/datasource.yaml config/grafana/provisioning/datasources/datasource.yaml "conf-file"
  get_modified_file config/grafana/oauth2.config config/grafana/oauth2.config
  get_modified_file config/keycloak/iqb-realm.config config/keycloak/iqb-realm.config
  get_modified_file config/keycloak/iqb-realm.json config/keycloak/iqb-realm.json
  get_modified_file config/maintenance-page/default.conf.template config/maintenance-page/default.conf.template "conf-file"
  get_modified_file config/maintenance-page/maintenance.html config/maintenance-page/maintenance.html "conf-file"
  get_modified_file config/prometheus/prometheus.yaml config/prometheus/prometheus.yaml "conf-file"
  get_modified_file config/traefik/tls-acme.yaml config/traefik/tls-acme.yaml "conf-file"
  get_modified_file config/traefik/tls-certificates.yaml config/traefik/tls-certificates.yaml "conf-file"
  get_modified_file config/traefik/tls-options.yaml config/traefik/tls-options.yaml "conf-file"
  printf "Configuration files modification check done.\n\n"
}

customize_settings() {
  # Setup makefiles
  sed -i "s#TRAEFIK_BASE_DIR :=.*#TRAEFIK_BASE_DIR := \\$(pwd)#" scripts/make/traefik.mk
  sed -i "s#scripts/update.sh#scripts/update_${APP_NAME}.sh#" scripts/make/traefik.mk

  if [ -f Makefile ]; then
    printf "include %s/scripts/make/traefik.mk\n" "$(pwd)" >>Makefile
  else
    printf "include %s/scripts/make/traefik.mk\n" "$(pwd)" >Makefile
  fi

  # write chosen version tag to env file
  sed -i "s#IQB_TRAEFIK_VERSION_TAG.*#IQB_TRAEFIK_VERSION_TAG=$TARGET_TAG#" .env.traefik

  # Generate TLS dummies
  if [ ! -f ./secrets/traefik/certs/certificate.pem ]; then
    printf "Generated certificate placeholder file.\nReplace this text with real content if necessary.\n" >./secrets/traefik/certs/certificate.pem
  fi
  if [ ! -f ./secrets/traefik/certs/private_key.pem ]; then
    printf "Generated key placeholder file.\nReplace this text with real content if necessary.\n" >./secrets/traefik/certs/private_key.pem
  fi
}

finalize_update() {
  printf "8. Summary\n"
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
  if command openssl x509 -in secrets/traefik/certs/certificate.pem -text -noout >/dev/null 2>&1 &&
    command openssl rsa -in secrets/traefik/certs/private_key.pem -check >/dev/null 2>&1; then
    printf "A TLS certificate and private key are already present!\n"
    read -p "Do you really want to replace them? [y/N] " -er -n 1 REPLACE

    if [[ ! $REPLACE =~ ^[yY]$ ]]; then
      printf "\nThe existing self-signed certificate and private key have not been replaced.\n\n"
      return
    fi
  fi

  printf "An unsecure self-signed TLS certificate valid for 30 days will be generated ...\n"
  openssl req \
    -newkey rsa:2048 -nodes -subj "/CN=$SERVER_NAME" -keyout secrets/traefik/certs/private_key.pem \
    -x509 -days 30 -out secrets/traefik/certs/certificate.pem
  printf "A self-signed certificate file and a private key file have been generated.\n\n"
}

main() {
  if [ -z "$SELECTED_VERSION" ]; then
    printf "\n============================================================\n"
    printf '%s update script started ...' $APP_NAME | tr '[:lower:]' '[:upper:]'
    printf "\n============================================================\n"
    printf "\n"
    printf "[1] Update %s\n" $APP_NAME
    printf "[2] Update the self-signed TLS certificate valid for 30 days\n"
    printf "[3] Exit update script\n\n"

    while read -p 'What do you want to do? [1-3] ' -er -n 1 CHOICE; do
      if [ "$CHOICE" = 1 ]; then
        printf "\n=== UPDATE %s ===\n\n" $APP_NAME

        load_environment_variables
        get_new_release_version
        create_backup
        prepare_installation_dir
        run_update_script_in_selected_version
        update_files
        check_environment_file_modifications
        run_optional_migration_scripts
        check_config_files_modifications
        customize_settings
        finalize_update

        break

      elif [ "$CHOICE" = 2 ]; then
        printf "\n=== UPDATE SELF-SIGNED TLS CERTIFICATE ===\n\n"

        generate_tls_certificate
        application_restart

        break

      elif [ "$CHOICE" = 3 ]; then
        printf "'%s' update script finished.\n" $APP_NAME
        exit 0

      fi

    done

  else
    TARGET_TAG="$SELECTED_VERSION"

    load_environment_variables
    prepare_installation_dir
    update_files
    check_environment_file_modifications
    run_optional_migration_scripts
    check_config_files_modifications
    customize_settings
    finalize_update
  fi
}

main
