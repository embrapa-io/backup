#!/bin/sh

echo "Starting embrapa.io backup process to GitLab..."

type gitlab-backup > /dev/null 2>&1 || { echo >&2 "The command 'gitlab-backup' has not found! Aborting."; exit 1; }

set -e

BKP_PATH="/var/opt/embrapa.io/backup"

[ ! -d $BKP_PATH ] && echo "$BKP_PATH does not exist." && exit 1

BKP_FOLDER="io_gitlab_$(date +%Y-%m-%d_%H-%M-%S)"

echo "Deleting old backups (older than 7 days)..."

find $BKP_PATH -type f -name "*.tar.gz" -mtime +7 -exec rm {} \;

echo "Creating backup folder: '$BKP_FOLDER'..."

mkdir -p $BKP_PATH/$BKP_FOLDER/gitlab/etc

echo "Running GitLab backup process..."

gitlab-backup create

mv /var/opt/gitlab/backups/*.tar $BKP_PATH/$BKP_FOLDER/gitlab/

echo "Copying GitLab config files..."

cp -r /etc/gitlab/* $BKP_PATH/$BKP_FOLDER/gitlab/etc/

echo "Compressing backup folder..."

tar -czvf $BKP_PATH/$BKP_FOLDER.tar.gz -C $BKP_PATH $BKP_FOLDER

rm -rf $BKP_PATH/$BKP_FOLDER

echo "All done! Backup file at: $BKP_PATH/$BKP_FOLDER.tar.gz"
