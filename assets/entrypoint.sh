#!/bin/sh

set -e

ME=$(basename $0)

auto_envsubst() {
  local template_dir="${NGINX_ENVSUBST_TEMPLATE_DIR:-/etc/nginx/templates}"
  local suffix="${NGINX_ENVSUBST_TEMPLATE_SUFFIX:-.template}"
  local output_dir="${NGINX_ENVSUBST_OUTPUT_DIR:-/etc/nginx/conf.d}"

  local template defined_envs relative_path output_path subdir
  defined_envs=$(printf '${%s} ' $(env | cut -d= -f1))
  [ -d "$template_dir" ] || return 1
  if [ ! -w "$output_dir" ]; then
    echo "$ME: ERROR: $template_dir exists, but $output_dir is not writable"
    return 1
  fi
  find "$template_dir" -follow -type f -name "*$suffix" -print | while read -r template; do
    relative_path="${template#$template_dir/}"
    output_path="$output_dir/${relative_path%$suffix}"
    subdir=$(dirname "$relative_path")
    # create a subdirectory where the template file exists
    mkdir -p "$output_dir/$subdir"
    echo "$ME: Running envsubst on $template to $output_path"
    envsubst "$defined_envs" < "$template" > "$output_path"
  done
}

set_env() {
  ### Set custom logs path
  if [ ! -z "$LOG_FILE" ]; then
    sed -i 's|LOG_FILE="/var/log/aptly/aptly.log"|LOG_FILE="${LOG_FILE}"|' /opt/db_cleanup.sh
    sed -i 's|LOG_FILE="/var/log/aptly/aptly.log"|LOG_FILE="${LOG_FILE}"|' /opt/update_mirror.sh
    echo "* * * The path you specify ${LOG_FILE} will be used for logging."
  else
    echo "* * * The default path /var/log/aptly/aptly.log will be used for logging."
    LOG_FILE="/var/log/aptly/aptly.log"
  fi

  ### Set custom repos config path
  if [ ! -z "$MIRR_FILE" ]; then
    sed -i 's|YAML_FILE="/opt/aptly/mirrors.yml"|YAML_FILE="${MIRR_FILE}"|' /opt/update_mirror.sh
    echo "* * * The path you specify ${MIRR_FILE} will be used for repository mirrors settings."
  else
    MIRR_FILE="/opt/aptly/mirrors.yml"
    echo "* * * The default path /opt/aptly/mirrors.yml will be used for repository mirrors settings."
    if [ ! -f /opt/aptly/mirrors.yml ]; then
      cp /opt/mirrors.yml /opt/aptly/mirrors.yml
      echo "* * * /opt/aptly/mirrors.yml file has been created. Edit it before you run update_mirror.sh."
    fi
  fi
}

display_info() {
  echo '
     ┌                            ┐
                                
       ███ ███ ██████ ███ ███ ███  
      ░███░███░██████░███░███░███  
      ░███████░███░░ ░███░███░███  
      ░░░███░ ░███   ░███░███░███  
       ███████░███   ░███░███░███  
      ░███░███░██████░███░███░███  
      ░███░███░██████░███░███░███  
      ░░░ ░░░ ░░░░░░ ░░░ ░░░ ░░░   
     └                            ┘
           Created by XCIII:
      https://github.com/coralhl/

───────────────────────────────────────'
echo "
MIRR_FILE    = $MIRR_FILE
LOG_FILE     = $LOG_FILE
───────────────────────────────────────
"
}

auto_envsubst

set_env

display_info

exec "$@"
