#!/bin/sh

# https://matomo.org/faq/how-to/how-do-i-backup-and-restore-the-matomo-data/

echo "Starting embrapa.io backup process to Matomo..."

type docker > /dev/null 2>&1 || { echo >&2 "Command 'docker' has not found! Aborting."; exit 1; }

set -e

MATOMO_PATH="/root/matomo"

[ ! -d $MATOMO_PATH ] && echo "$MATOMO_PATH does not exist." && exit 1

BKP_PATH="/var/opt/embrapa.io/backup"

mkdir -p $BKP_PATH

[ ! -d $BKP_PATH ] && echo "$BKP_PATH does not exist." && exit 1

BKP_FOLDER="io_matomo_$(date +%Y-%m-%d_%H-%M-%S)"

echo "Deleting old backups (older than 7 days)..."

find $BKP_PATH -type f -name "*.tar.gz" -mtime +7 -exec rm {} \;

echo "Creating backup folder: '$BKP_FOLDER'..."

mkdir -p $BKP_PATH/$BKP_FOLDER/matomo

echo "Running Docker Compose backup process..."

cd $MATOMO_PATH

docker compose build --force-rm --no-cache backup

docker compose run --rm --no-deps backup

echo "Copying backup and config files..."

cp -r $MATOMO_PATH/backup/* $BKP_PATH/$BKP_FOLDER/matomo/

rm $MATOMO_PATH/backup/*

cp $MATOMO_PATH/.env* $BKP_PATH/$BKP_FOLDER/matomo/

# When Matomo is running in dedicated server:

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
