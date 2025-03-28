#! /usr/bin/env bash
set -e

# Automate the initial creation and update of a mirror in aptly.

# You need to install repo signing public key, if you wanna take it from your system you can look for in:
# /usr/share/keyrings/ (like /usr/share/keyrings/ubuntu-archive-keyring.gpg) or you can take it from apt-key (apt-key help / list / export).
# Export the key to the pubring in GPG utility (usually ${GNUPGHOME}/pubring.gpg). You can use prepared script /opt/keys_imp.sh for it.
# You can then specify its value in the docker environment variable.
# GPG_PASSPHRASE="super-secret-passphrase"

LOG_FILE="/var/log/aptly/aptly.log"

exec > >(tee -a $LOG_FILE) 2>&1

# Path to YAML file with mirrors settings
YAML_FILE="/opt/aptly/mirrors.yml"

# Logger function
logger() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Read settings from YAML file function
read_yaml() {
    yq e "$1" "$YAML_FILE"
}

# Create the mirror repository, if it doesn't exist
create_mirrors() {
    set +e
    for DIST in ${REPO_DISTS[@]}; do
        aptly mirror list -raw | grep "^${REPO_NAME}-${DIST}$"
        if [[ $? -ne 0 ]]; then
            logger "Creating mirror of ${REPO_NAME} repository."
            logger | aptly mirror create \
            ${MIRROR_CREATE_OPTS} \
            -architectures=${REPO_ARCHS} ${REPO_NAME}-${DIST} ${REPO_URL} ${DIST} ${REPO_COMPS}
        fi
    done
    set -e
}

# Update the all repository mirrors
update_mirrors() {
    for DIST in ${REPO_DISTS[@]}; do
        logger "Updating ${REPO_NAME}-${DIST} repository mirror.."
        logger | aptly mirror update ${REPO_NAME}-${DIST}
    done
}

# Create snapshots of updated repositories
create_snapshots() {
    SNAP_DATE=$(date +%s%N)

    for DIST in ${REPO_DISTS[@]}; do
        logger "Creating snapshot of ${REPO_NAME}-${DIST} repository mirror.."
        SNAPSHOT=${REPO_NAME}-${DIST}-$SNAP_DATE
        SNAPSHOTARRAY+="${SNAPSHOT} "
        logger | aptly snapshot create ${SNAPSHOT} from mirror ${REPO_NAME}-${DIST}
    done

    logger "Snapshots results:"
    logger ${SNAPSHOTARRAY[@]}
}

# Publish the latest snapshots
publish_snapshots() {
    set +e
    for snap in ${SNAPSHOTARRAY[@]}; do
        DIST=$(echo ${snap} | sed "s/^${REPO_NAME}-\(.*\)-[^-]*\$/\1/")
        aptly publish list -raw | grep "^${REPO_NAME} ${DIST}$"
        if [[ $? -eq 0 ]]; then
            logger | aptly publish switch \
            ${PUBLISH_SWITCH_OPTS} -batch=true \
            -passphrase=${GPG_PASSPHRASE} ${DIST} ${REPO_NAME} ${snap}
        else
            logger | aptly publish snapshot \
            ${PUBLISH_SNAPSHOT_OPTS} -batch=true \
            -passphrase=${GPG_PASSPHRASE} ${snap} ${REPO_NAME}
        fi
    done
    set -e
}

# Сount repositories
REPO_COUNT=$(read_yaml '.repositories | length')

for ((i=0; i<REPO_COUNT; i++)); do
    REPO_NAME=$(read_yaml ".repositories[$i].name")
    REPO_URL=$(read_yaml ".repositories[$i].url")
    REPO_DISTS=$(read_yaml ".repositories[$i].dist | join(\" \")")
    REPO_COMPS=$(read_yaml ".repositories[$i].components | join(\" \")")
    REPO_ARCHS=$(read_yaml ".repositories[$i].architectures | join(\",\")")
    
    create_mirrors
    update_mirrors
    create_snapshots
    publish_snapshots
done

# Generate Aptly Graph
aptly graph -output /opt/aptly/public/aptly_graph.png
