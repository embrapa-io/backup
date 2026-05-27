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

# Se o script falhar antes de compactar, remove a pasta de trabalho parcial
# (evita acúmulo de diretórios órfãos io_sentry_* quando o backup aborta).
# Guarda contra BKP_FOLDER vazio para nunca apagar o BKP_PATH inteiro.
trap '[ -n "$BKP_FOLDER" ] && rm -rf "$BKP_PATH/$BKP_FOLDER"' EXIT

echo "Cleaning up old backups (keeping last 7 days + last 4 Sundays)..."

# Política de retenção (igual ao cluster.sh): mantém os últimos 7 dias + o backup
# de cada um dos 4 últimos domingos. Trata tanto os .tar.gz concluídos quanto os
# diretórios io_sentry_* órfãos (de execuções que abortaram antes de compactar).
# A data é lida do nome do item: io_sentry_AAAA-MM-DD_HH-MM-SS[.tar.gz]

# Janela diária: últimos 7 dias = hoje + 6 anteriores (meia-noite de 6 dias atrás)
CUTOFF_EPOCH=$(date -d "today -6 days 00:00:00" +%s)

# Os 4 últimos domingos (inclui hoje, caso hoje seja domingo)
DOW=$(date +%w)                                  # 0=domingo .. 6=sábado
BASE_SUNDAY=$(date -d "today -$DOW days" +%Y-%m-%d)
KEEP_SUNDAYS=""
for W in 0 1 2 3; do
  KEEP_SUNDAYS="$KEEP_SUNDAYS $(date -d "$BASE_SUNDAY -$((W * 7)) days" +%Y-%m-%d)"
done

for ENTRY in "$BKP_PATH"/io_sentry_*; do
  [ -e "$ENTRY" ] || continue
  NAME=$(basename "$ENTRY")

  # extrai AAAA-MM-DD do nome; nomes fora do padrão são preservados
  FDATE=$(echo "$NAME" | sed -n 's/^io_sentry_\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)_.*/\1/p')
  if [ -z "$FDATE" ]; then
    continue
  fi

  KEEP=0

  # mantém se estiver dentro dos últimos 7 dias
  FEPOCH=$(date -d "$FDATE" +%s 2>/dev/null || echo 0)
  if [ "$FEPOCH" -ge "$CUTOFF_EPOCH" ]; then
    KEEP=1
  fi

  # mantém se a data for um dos 4 últimos domingos
  for S in $KEEP_SUNDAYS; do
    if [ "$FDATE" = "$S" ]; then
      KEEP=1
    fi
  done

  if [ "$KEEP" -eq 0 ]; then
    echo "  - removing old backup: $NAME"
    rm -rf "$ENTRY"
  fi
done

echo "Creating backup folder: '$BKP_FOLDER'..."

mkdir -p $BKP_PATH/$BKP_FOLDER/sentry

echo "Running Docker Compose backup process..."

cd $SENTRY_PATH

docker compose run --rm -T -e SENTRY_LOG_LEVEL=CRITICAL web export > $BKP_PATH/$BKP_FOLDER/sentry/backup.json

docker compose exec -T postgres pg_dump -U postgres -d postgres > $BKP_PATH/$BKP_FOLDER/sentry/postgres.sql

# docker cp $(docker compose ps -q redis):/data/dump.rdb "$BKP_PATH/$BKP_FOLDER/sentry/redis.rdb"

echo "Copying config files..."

cp $SENTRY_PATH/sentry/config.yml $BKP_PATH/$BKP_FOLDER/sentry/
cp $SENTRY_PATH/sentry/sentry.conf.py $BKP_PATH/$BKP_FOLDER/sentry/

# When Sentry is running in dedicated server:

# if ! type docker-backup &> /dev/null; then
#     set +e

#     echo "Starting Docker backup process with 'docker-backup' to all containers..."

#     mkdir -p $BKP_PATH/$BKP_FOLDER/docker

#     cd $BKP_PATH/$BKP_FOLDER/docker

#     docker-backup backup --all --stopped --tar --verbose

#     set -e
# else
#     echo "Command 'docker-backup' has not found! See: https://github.com/muesli/docker-backup"
# fi

echo "Compressing backup folder..."

cd /tmp

tar -czvf $BKP_PATH/$BKP_FOLDER.tar.gz -C $BKP_PATH $BKP_FOLDER

rm -rf $BKP_PATH/$BKP_FOLDER

echo "All done! Backup file at: $BKP_PATH/$BKP_FOLDER.tar.gz"

# When Sentry is running in dedicated server:

# echo "Clean up unused images..."

# docker image prune -af --filter "until=24h"
