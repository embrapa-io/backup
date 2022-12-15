#!/bin/sh

echo "Starting embrapa.io backup process to backend..."

type docker > /dev/null 2>&1 || { echo >&2 "Command 'docker' has not found! Aborting."; exit 1; }

set -e

IO_PATH="/root/embrapa.io/backend"

[ ! -d $IO_PATH ] && echo "$IO_PATH does not exist." && exit 1

BKP_PATH="/var/opt/embrapa.io/backup"

mkdir -p $BKP_PATH

[ ! -d $BKP_PATH ] && echo "$BKP_PATH does not exist." && exit 1

BKP_FOLDER="io_backend_$(date +%Y-%m-%d_%H-%M-%S)"

echo "Deleting old backups (older than 7 days)..."

find $BKP_PATH -type f -name "*.tar.gz" -mtime +7 -exec rm {} \;

echo "Creating backup folder: '$BKP_FOLDER'..."

mkdir -p $BKP_PATH/$BKP_FOLDER/backend

echo "Running Docker Compose backup process..."

cd $IO_PATH

env $(cat .env.cli) docker compose build --force-rm --no-cache backup

env $(cat .env.cli) docker compose run --rm --no-deps backup

echo "Copying backup and config files..."

cp -r $IO_PATH/.embrapa/* $BKP_PATH/$BKP_FOLDER/backend/

rm $IO_PATH/.embrapa/backup/*.tar.gz

cp $IO_PATH/.env* $BKP_PATH/$BKP_FOLDER/backend/

if ! type docker-backup &> /dev/null; then
    echo "Starting Docker backup process with 'docker-backup' to all containers..."

    mkdir -p $BKP_PATH/$BKP_FOLDER/docker

    cd $BKP_PATH/$BKP_FOLDER/docker

    docker-backup backup --all --stopped --tar --verbose
else
    echo "Command 'docker-backup' has not found! See: https://github.com/muesli/docker-backup"
fi

echo "Compressing backup folder..."

cd /tmp

tar -czvf $BKP_PATH/$BKP_FOLDER.tar.gz -C $BKP_PATH $BKP_FOLDER

rm -rf $BKP_PATH/$BKP_FOLDER

echo "All done! Backup file at: $BKP_PATH/$BKP_FOLDER.tar.gz"
