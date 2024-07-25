#!/bin/bash

LOG_FILE="/var/log/aptly/aptly.log"

exec > >(tee -a $LOG_FILE) 2>&1

# Logger function
logger() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Get list of all snapshots
ALL_SNAPSHOTS=$(aptly snapshot list -raw)

# Get list of all published snapshots
PUBLISHED_SNAPSHOTS=$(aptly publish list | awk -F'\\[' '{print $3}' | awk -F'\\]' '{print $1}' | tail -n +2)

# Find unpublished snapshots
UNPUBLISHED_SNAPSHOTS=$(comm -23 <(echo "$ALL_SNAPSHOTS" | sort) <(echo "$PUBLISHED_SNAPSHOTS" | sort))

# Remove unpublished snapshots
for SNAPSHOT in $UNPUBLISHED_SNAPSHOTS; do
  logger "Removing an unpublished snapshot: $SNAPSHOT"
  aptly snapshot drop "$SNAPSHOT"
done

# Database cleanup
logger "Database cleanup (removing information about unreferenced packages and deletes files)"
logger | aptly db cleanup
logger "Database cleanup completed"
