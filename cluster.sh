#!/bin/sh

echo "Starting embrapa.io backup process to cluster.agro.rocks..."

type docker > /dev/null 2>&1 || { echo >&2 "Command 'docker' has not found! Aborting."; exit 1; }

type docker-compose > /dev/null 2>&1 || { echo >&2 "Command 'docker-compose' has not found! Aborting."; exit 1; }

type docker-backup > /dev/null 2>&1 || { echo >&2 "Command 'docker-backup' has not found! See: https://github.com/muesli/docker-backup. Aborting."; exit 1; }

set -e

BKP_PATH="/var/opt/embrapa.io/backup"

mkdir -p $BKP_PATH

[ ! -d $BKP_PATH ] && echo "$BKP_PATH does not exist." && exit 1

BKP_FOLDER="io_cluster_$(date +%Y-%m-%d_%H-%M-%S)"

echo "Deleting old backups (older than 7 days)..."

find $BKP_PATH -type f -name "*.tar.gz" -mtime +7 -exec rm {} \;

echo "Creating backup folder: '$BKP_FOLDER'..."

mkdir -p $BKP_PATH/$BKP_FOLDER/cluster.agro.rocks

echo "Starting Docker backup process with 'docker-backup' to all containers..."

cd $BKP_PATH/$BKP_FOLDER/cluster.agro.rocks

docker-backup backup --all --stopped --tar --verbose

echo "Compressing backup folder..."

cd /tmp

tar -czvf $BKP_PATH/$BKP_FOLDER.tar.gz -C $BKP_PATH $BKP_FOLDER

rm -rf $BKP_PATH/$BKP_FOLDER

echo "All done! Backup file at: $BKP_PATH/$BKP_FOLDER.tar.gz"
