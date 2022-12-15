#!/bin/sh

# https://develop.sentry.dev/self-hosted/backup/

echo "Starting embrapa.io backup process to Sentry..."

type docker > /dev/null 2>&1 || { echo >&2 "Command 'docker' has not found! Aborting."; exit 1; }

set -e

SENTRY_PATH="/root/sentry"

[ ! -d $SENTRY_PATH ] && echo "$SENTRY_PATH does not exist." && exit 1

BKP_PATH="/var/opt/embrapa.io/backup"

mkdir -p $BKP_PATH

[ ! -d $BKP_PATH ] && echo "$BKP_PATH does not exist." && exit 1

BKP_FOLDER="io_sentry_$(date +%Y-%m-%d_%H-%M-%S)"

echo "Deleting old backups (older than 7 days)..."

find $BKP_PATH -type f -name "*.tar.gz" -mtime +7 -exec rm {} \;

echo "Creating backup folder: '$BKP_FOLDER'..."

mkdir -p $BKP_PATH/$BKP_FOLDER/sentry

echo "Running Docker Compose backup process..."

cd $SENTRY_PATH

docker compose run --rm -T -e SENTRY_LOG_LEVEL=CRITICAL web export > $BKP_PATH/$BKP_FOLDER/sentry/backup.json

echo "Copying config files..."

cp $SENTRY_PATH/sentry/config.yml $BKP_PATH/$BKP_FOLDER/sentry/
cp $SENTRY_PATH/sentry/sentry.conf.py $BKP_PATH/$BKP_FOLDER/sentry/

# When Sentry is running in dedicated server:

# if ! type docker-backup &> /dev/null; then
#     echo "Starting Docker backup process with 'docker-backup' to all containers..."

#     mkdir -p $BKP_PATH/$BKP_FOLDER/docker

#     cd $BKP_PATH/$BKP_FOLDER/docker

#     docker-backup backup --all --stopped --tar --verbose
# else
#     echo "Command 'docker-backup' has not found! See: https://github.com/muesli/docker-backup"
# fi

echo "Compressing backup folder..."

cd /tmp

tar -czvf $BKP_PATH/$BKP_FOLDER.tar.gz -C $BKP_PATH $BKP_FOLDER

rm -rf $BKP_PATH/$BKP_FOLDER

echo "All done! Backup file at: $BKP_PATH/$BKP_FOLDER.tar.gz"
