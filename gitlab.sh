#!/bin/sh

echo "Starting embrapa.io backup process to GitLab..."

type gitlab-backup > /dev/null 2>&1 || { echo >&2 "The command 'gitlab-backup' has not found! Aborting."; exit 1; }

set -e

BKP_FOLDER="embrapa.io_gitlab_$(date +%Y-%m-%d_%H-%M-%S)"

echo "Will be created backup folder: '$BKP_FOLDER'..."

gitlab-backup create

mkdir -p /var/opt/embrapa.io/backups/$BKP_FOLDER/gitlab/etc

mv /var/opt/gitlab/backups/* /var/opt/embrapa.io/backups/$BKP_FOLDER/gitlab/

echo "Copying GitLab config files..."

cp -r /etc/gitlab/* /var/opt/embrapa.io/backups/$BKP_FOLDER/gitlab/etc/

tar -czvf /var/opt/embrapa.io/backups/$BKP_FOLDER.tar.gz -C /var/opt/embrapa.io/backups $BKP_FOLDER

rm -rf /var/opt/embrapa.io/backups/$BKP_FOLDER

echo "All done!"
