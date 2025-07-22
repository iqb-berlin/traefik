#!/bin/bash

declare APP_NAME='traefik'

declare SELECTED_VERSION=$1
declare REPO_URL="https://raw.githubusercontent.com/iqb-berlin/$APP_NAME"
declare REPO_API="https://api.github.com/repos/iqb-berlin/$APP_NAME"
declare HAS_ENV_FILE_UPDATE=false
declare HAS_CONFIG_FILE_UPDATE=false
declare HAS_MIGRATION_FILES=false

declare APP_DIR
declare BACKUP_DIR
declare SOURCE_TAG
declare TARGET_TAG
declare IS_RELEASE_TAG
declare IS_PRERELEASE_TAG
declare TAG_EXISTS

load_environment_variables() {
  # Load current environment variables in .env.traefik
  source .env.traefik
  SOURCE_TAG=$IQB_TRAEFIK_VERSION_TAG
  APP_DIR=$(pwd)
}

get_new_release_version() {
  declare latest_release
  latest_release=$(curl -s "$REPO_API"/releases/latest |
    grep tag_name |
    cut -d : -f 2,3 |
    tr -d \" |
    tr -d , |
    tr -d " ")

  if [ "$SOURCE_TAG" = "latest" ]; then
    SOURCE_TAG="$latest_release"
  fi

  printf "Installed version: %s\n" "$SOURCE_TAG"
  printf "Latest available release: %s\n\n" "$latest_release"

  if [ "$SOURCE_TAG" = "$latest_release" ]; then
    printf "Latest release is already installed!\n"
    declare continue
    read -p "Continue anyway? [y/N] " -er -n 1 continue

    if [[ ! $continue =~ ^[yY]$ ]]; then
      printf "'%s' update script finished.\n" $APP_NAME
      exit 0
    fi

    printf "\n"
  fi

  while read -p '1. Name the desired version: ' -er -i "${latest_release}" TARGET_TAG; do
    if ! curl --head --silent --fail --output /dev/null $REPO_URL/"$TARGET_TAG"/README.md 2>/dev/null; then
      printf "This version tag does not exist.\n"

    else
      printf "\n"
      break
    fi

  done
}

create_backup() {
  BACKUP_DIR="backup/release/${SOURCE_TAG}"

  printf "2. Backup creation\n"
  # Backup installation directory
  mkdir -p "${BACKUP_DIR}"/backup
  tar -cf - --exclude='./backup' . | tar -xf - -C "${BACKUP_DIR}"
  printf -- "- Current '%s' release files have been saved at: '%s'\n" "${SOURCE_TAG}" "${BACKUP_DIR}"
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
  printf "4. File downloads\n"

  download_file "${APP_DIR}/docker-compose.traefik.yaml" docker-compose.yaml
  download_file "${APP_DIR}/docker-compose.traefik.prod.yaml" docker-compose.traefik.prod.yaml
  download_file "${APP_DIR}/scripts/make/traefik.mk" scripts/make/prod.mk

  printf "File downloads done.\n\n"
}

update_keycloak_theme() {
  printf "5. Keycloak IQB theme download\n"

  curl --location --silent github.com/iqb-berlin/${APP_NAME}/archive/${TARGET_TAG}.tar.gz | \
    tar --extract --gunzip --directory config/keycloak --strip=3 ${APP_NAME}-${TARGET_TAG}/config/keycloak/themes/iqb

  printf "Keycloak IQB theme download done.\n\n"
}

get_modified_file() {
  declare source_file
  source_file="${APP_DIR}"/"$1"

  declare target_file
  target_file=$REPO_URL/"$TARGET_TAG"/"$2"

  declare file_type
  file_type="$3"

  declare current_env_file
  current_env_file=.env.traefik

  if [ ! -f "$source_file" ] || ! (curl --stderr /dev/null "$target_file" | diff -q - "$source_file" &>/dev/null); then

    # no source file exists anymore
    if [ ! -f "$source_file" ]; then
      if [ "$file_type" == "env-file" ]; then
        printf -- "- Environment template file '%s' does not exist anymore.\n" "$source_file"
        printf "  A version %s environment template file will be downloaded now ...\n" "$TARGET_TAG"
        printf "  Please compare your current environment file with the new template file and update it "
        printf "with new environment variables, or delete obsolete variables, if necessary.\n"
        printf "  For comparison use e.g. 'diff %s %s'.\n" $current_env_file "$source_file"
      fi

      if [ "$file_type" == "conf-file" ]; then
        printf -- "- Configuration file '%s' does not exist (anymore).\n" "$source_file"
        printf "  A version %s configuration file will be downloaded now ...\n" "$TARGET_TAG"
      fi

    # source file and target file differ
    elif ! curl --stderr /dev/null "$target_file" | diff -q - "$source_file" &>/dev/null; then
      if [ "$file_type" == "env-file" ]; then
        printf -- "- The current environment template file '%s' is outdated.\n" "$source_file"
        printf "  A version %s environment template file will be downloaded now ...\n" "$TARGET_TAG"
        printf "  Please compare your current environment file with the new template file and update it "
        printf "with new environment variables, or delete obsolete variables, if necessary.\n"
        printf "  For comparison use e.g. 'diff %s %s'.\n" $current_env_file "$source_file"
      fi

      if [ "$file_type" == "conf-file" ]; then
        mv "$source_file" "$source_file".old 2>/dev/null
        printf -- "- The current configuration file '%s' is outdated.\n" "$source_file"
        printf "  A version %s configuration file will be downloaded now ...\n" "$TARGET_TAG"
        printf "  Please compare the new configuration file with your old configuration file and modify it, "
        printf "if necessary!\n"
        printf "  For comparison use e.g. 'diff %s %s.old'.\n" "$source_file" "$source_file"
      fi

    fi

    if curl --silent --fail --output "$source_file" "$target_file"; then
      printf -- "  - File '%s' was downloaded successfully.\n" "$source_file"

      if [ "$file_type" == "env-file" ]; then
        HAS_ENV_FILE_UPDATE=true
      fi

      if [ "$file_type" == "conf-file" ]; then
        HAS_CONFIG_FILE_UPDATE=true
      fi

    else
      printf "  File '%s' download failed.\n\n" "$source_file"
      printf "'%s' update script finished with error.\n" $APP_NAME
      exit 1

    fi

  else
    if [ "$file_type" == "env-file" ]; then
      printf -- "- The current environment file '%s' is still up to date.\n" "$source_file"
    fi

    if [ "$file_type" == "conf-file" ]; then
      printf -- "- The current configuration file '%s' is still up to date.\n" "$source_file"
    fi

  fi
}

check_environment_file_modifications() {
  # check environment file
  printf "6. Environment template file modification check\n"
  get_modified_file .env.traefik.template .env.traefik.template "env-file"
  printf "Environment template file modification check done.\n\n"
}

check_tag_exists() {
  declare tag
  tag="$1"

  declare status_code
  status_code=$(curl \
      --write-out "%{response_code}\n" \
      --silent \
      --output /dev/null \
    $REPO_API/releases/tags/"$tag")

  if test "$status_code" -eq "200"; then
    TAG_EXISTS=true
    #printf "  Tag '%s' exists.\n" "$tag"
  else
    TAG_EXISTS=false
    #printf "  Tag '%s' does not exist!\n" "$tag"
  fi
}

check_tag_format() {
  declare tag
  tag="$1"

  if test "$(printf "%s\n" "$tag" |
    sed -nre 's/^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\-(alpha|beta|rc)(\.[1-9][0-9]*|[1-9][0-9]*)?$/&/p')"; then
    IS_RELEASE_TAG=false
    IS_PRERELEASE_TAG=true
    #printf "  Tag '%s' is a pre-release tag.\n" "$tag"
  elif test "$(printf "%s\n" "$tag" | sed -nre 's/^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/&/p')"; then
    IS_RELEASE_TAG=true
    IS_PRERELEASE_TAG=false
    #printf "  Tag '%s' is a release tag.\n" "$tag"
  else
    IS_RELEASE_TAG=false
    IS_PRERELEASE_TAG=false
    #printf "  Tag '%s' is neither a release tag nor pre-release tag!\n" "$tag"
  fi
}

run_optional_migration_scripts() {
  printf "7. Optional migration scripts check\n"
  declare source_tag_is_release
  declare source_tag_is_prerelease
  declare target_tag_is_release
  declare target_tag_is_prerelease

  #printf -- "- Source tag: '%s'\n" "$SOURCE_TAG"
  check_tag_format "$SOURCE_TAG"
  source_tag_is_release=$IS_RELEASE_TAG
  source_tag_is_prerelease=$IS_PRERELEASE_TAG
  check_tag_exists "$SOURCE_TAG"

  if test $TAG_EXISTS != true; then
    printf -- "- Source tag: '%s' doesn't exist!\n" "$SOURCE_TAG"
    printf "  The existence of possible migration scripts could not be determined.\n"
    printf "Optional migration scripts check done.\n\n"

    return

  else
    #printf -- "- Target tag: '%s'\n" "$TARGET_TAG"
    check_tag_format "$TARGET_TAG"
    target_tag_is_release=$IS_RELEASE_TAG
    target_tag_is_prerelease=$IS_PRERELEASE_TAG
    check_tag_exists "$TARGET_TAG"

  fi

  if test $TAG_EXISTS = false; then
    printf -- "- Target tag: '%s' doesn't exist!\n" "$TARGET_TAG"
    printf "  The existence of possible migration scripts could not be determined.\n"
    printf "Optional migration scripts check done.\n\n"

    return

  elif [[ ("$source_tag_is_release" = true || "$source_tag_is_prerelease" = true) &&
    ("$target_tag_is_release" = true || "$target_tag_is_prerelease" = true) ]]; then

    declare release_tags
    release_tags=$(curl -s $REPO_API/releases?per_page=100 |
        grep tag_name |
        cut -d : -f 2,3 |
        tr -d \" |
        tr -d , |
        tr -d " " |
        sed -ne "/$TARGET_TAG/,/$SOURCE_TAG/p" |
        head -n -1)

  elif [[ ("$source_tag_is_release" = false && "$source_tag_is_prerelease" = false) ]]; then
    printf -- "- Source tag '%s' is neither a release tag nor pre-release tag!\n" "$SOURCE_TAG"
    printf "  The existence of possible migration scripts could not be determined.\n"
    printf "Optional migration scripts check done.\n\n"

    return

  elif [[ "$target_tag_is_release" = false && "$target_tag_is_prerelease" = false ]]; then
    printf -- "- Target tag '%s' is neither a release tag nor pre-release tag!\n" "$TARGET_TAG"
    printf "  The existence of possible migration scripts could not be determined.\n"
    printf "Optional migration scripts check done.\n\n"

    return
  fi

  if [ -n "$release_tags" ]; then
    declare release_tag
    for release_tag in $release_tags; do
      declare -a migration_scripts
      declare migration_script_check_url
      migration_script_check_url=$REPO_URL/"$TARGET_TAG"/scripts/migration/"$release_tag".sh
      if curl --head --silent --fail --output /dev/null "$migration_script_check_url" 2>/dev/null; then
        migration_scripts+=("$release_tag".sh)
      fi
    done

    if [ ${#migration_scripts[@]} -eq 0 ]; then
      printf -- "- No additional migration scripts to execute.\n\n"

    else
      printf -- "- Additional Migration script(s) available.\n\n"
      printf "7.1 Migration script download\n"
      mkdir -p "${APP_DIR}"/scripts/migration
      for migration_script in "${migration_scripts[@]}"; do
        download_file "${APP_DIR}"/scripts/migration/"$migration_script" scripts/migration/"$migration_script"
        chmod +x "${APP_DIR}"/scripts/migration/"$migration_script"
      done

      printf "\n7.2 Migration script execution\n"
      printf "The following migration scripts will be executed for the migration from version %s to version %s:\n" \
        "$SOURCE_TAG" "$TARGET_TAG"
      declare migration_script
      for ((index = ${#migration_scripts[@]} - 1; index >= 0; index--)); do
        printf -- "- %s\n" "${migration_scripts[index]}"
      done

      printf "\nWe strongly recommend the installation of the update scripts, otherwise it is very likely that "
      printf "errors will occur during operation of the application.\n\n"

      read -p "Do you want to proceed with the installation? [Y/n] " -er -n 1 continue
      if [[ $continue =~ ^[nN]$ ]]; then
        HAS_MIGRATION_FILES=true

        printf "\nIf you want to ensure the smooth operation of the application, you can also install the migration "
        printf "scripts manually.\n"
        printf "To do this, change to directory './scripts/migration' and execute the above scripts in ascending "
        printf "order!\n\n"

        printf "Optional migration scripts check done.\n\n"

        return
      fi
      printf "\n"

      for ((i = ${#migration_scripts[@]} - 1; i >= 0; i--)); do
        printf -- "- Executing '%s' ...\n" "${migration_scripts[$i]}"
        bash "${APP_DIR}"/scripts/migration/"${migration_scripts[$i]}"
        rm "${APP_DIR}"/scripts/migration/"${migration_scripts[$i]}"
      done

      printf "\nMigration scripts successfully executed.\n\n"

      printf "Optional migration scripts check done.\n\n"

      printf "\n------------------------------------------------------------\n"
      printf "Proceed with the original '%s' installation ..." $APP_NAME
      printf "\n------------------------------------------------------------\n"
      printf "\n"

    fi

  fi
}

check_config_files_modifications() {
  # check configuration files
  printf "8. Configuration files modification check\n"
  get_modified_file config/grafana/provisioning/dashboards/dashboard.yaml config/grafana/provisioning/dashboards/dashboard.yaml "conf-file"
  get_modified_file config/grafana/provisioning/dashboards/traefik_rev4.json config/grafana/provisioning/dashboards/traefik_rev4.json "conf-file"
  get_modified_file config/grafana/provisioning/datasources/datasource.yaml config/grafana/provisioning/datasources/datasource.yaml "conf-file"
  get_modified_file config/grafana/oauth2.config config/grafana/oauth2.config
  get_modified_file config/keycloak/monitoring-realm.config config/keycloak/monitoring-realm.config
  get_modified_file config/keycloak/monitoring-realm.json config/keycloak/monitoring-realm.json
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
  sed -i "s#TRAEFIK_BASE_DIR :=.*#TRAEFIK_BASE_DIR := \\$(pwd)#" "${APP_DIR}/scripts/make/traefik.mk"
  sed -i "s#scripts/update.sh#scripts/update_${APP_NAME}.sh#" "${APP_DIR}/scripts/make/traefik.mk"

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
  printf "9. Summary\n"
  if [ $HAS_ENV_FILE_UPDATE == "true" ] || [ $HAS_CONFIG_FILE_UPDATE == "true" ] || [ $HAS_MIGRATION_FILES == "true" ]; then
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
    if [ $HAS_MIGRATION_FILES == "true" ]; then
      printf -- '- Migration script(s) existing and execution is still pending!\n\n'
      printf "  PLEASE EXECUTE PENDING MIGRATION SCRIPTS ! ! !\n\n"
    fi
    printf "Summary done.\n\n\n"

    if [[ $(docker compose --project-name "${APP_DIR##*/}" ps -q) ]]; then
      printf "'%s' infrastructure will now shut down ...\n" $APP_NAME
      docker compose --project-name "${APP_DIR##*/}" down
    fi

    printf "When your files are checked for modification, you could restart the application with "
    printf "'make %s-up' at the command line to put the update into effect.\n\n" $APP_NAME

    printf "'%s' update script finished.\n" $APP_NAME
    exit 0

  else
    printf -- "- Version update applied.\n"
    printf "  No further action needed.\n"
    printf "Summary done.\n\n\n"

    # application_reload --> Seems not to work with liquibase containers!
    application_reload
    #application_restart
  fi
}

application_reload() {
  if command make -v >/dev/null 2>&1; then
    declare reload
    read -p "Do you want to reload $APP_NAME now? [Y/n] " -er -n 1 reload

    if [[ ! $reload =~ [nN] ]]; then
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
    declare restart
    read -p "Do you want to restart $APP_NAME now? [Y/n] " -er -n 1 restart

    if [[ ! $restart =~ [nN] ]]; then
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

    declare replace
    read -p "Do you really want to replace them? [y/N] " -er -n 1 replace

    if [[ ! $replace =~ ^[yY]$ ]]; then
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
    printf "\n==================================================\n"
    printf '%s update script started ...' $APP_NAME | tr '[:lower:]' '[:upper:]'
    printf "\n==================================================\n"
    printf "\n"
    printf "[1] Update %s\n" $APP_NAME
    printf "[2] Update the self-signed TLS certificate valid for 30 days\n"
    printf "[3] Exit update script\n\n"

    declare choice
    while read -p 'What do you want to do? [1-3] ' -er -n 1 choice; do
      if [ "$choice" = 1 ]; then
        printf "\n=== UPDATE %s ===\n\n" $APP_NAME

        load_environment_variables
        get_new_release_version
        create_backup
        run_update_script_in_selected_version
        prepare_installation_dir
        update_files
        update_keycloak_theme
        check_environment_file_modifications
        run_optional_migration_scripts
        check_config_files_modifications
        customize_settings
        finalize_update

        break

      elif [ "$choice" = 2 ]; then
        printf "\n=== UPDATE SELF-SIGNED TLS CERTIFICATE ===\n\n"

        generate_tls_certificate
        application_restart

        break

      elif [ "$choice" = 3 ]; then
        printf "'%s' update script finished.\n" $APP_NAME
        exit 0

      fi

    done

  else
    TARGET_TAG="$SELECTED_VERSION"

    load_environment_variables
    prepare_installation_dir
    update_files
    update_keycloak_theme
    check_environment_file_modifications
    run_optional_migration_scripts
    check_config_files_modifications
    customize_settings
    finalize_update
  fi
}

main
