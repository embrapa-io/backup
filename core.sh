#!/bin/sh

echo "Starting embrapa.io backup process to backend..."

type docker > /dev/null 2>&1 || { echo >&2 "Command 'docker' has not found! Aborting."; exit 1; }

set -e

# Backups contêm segredos (dumps de DB, .env, configs) — não podem ficar
# world-readable. Restringe a permissão dos arquivos/pastas criados a seguir.
umask 077

IO_PATH="/root/embrapa.io/backend"

[ ! -d $IO_PATH ] && echo "$IO_PATH does not exist." && exit 1

BKP_PATH="/var/opt/embrapa.io/backup"

mkdir -p $BKP_PATH

[ ! -d $BKP_PATH ] && echo "$BKP_PATH does not exist." && exit 1

BKP_FOLDER="io_backend_$(date +%Y-%m-%d_%H-%M-%S)"

# Se o script falhar antes de compactar, remove a pasta de trabalho parcial
# (evita acúmulo de diretórios órfãos io_backend_* quando o backup aborta).
# Guarda contra BKP_FOLDER vazio para nunca apagar o BKP_PATH inteiro.
trap '[ -n "$BKP_FOLDER" ] && rm -rf "$BKP_PATH/$BKP_FOLDER"' EXIT

echo "Cleaning up old backups (keeping last 7 days + last 4 Sundays)..."

# Política de retenção: mantém os últimos 7 dias + o backup de cada um dos 4
# últimos domingos. Trata tanto os .tar.gz concluídos quanto diretórios
# io_backend_* órfãos (de execuções que abortaram antes de compactar).
# A data é lida do nome do item: io_backend_AAAA-MM-DD_HH-MM-SS[.tar.gz]

# Janela diária: últimos 7 dias = hoje + 6 anteriores (meia-noite de 6 dias atrás)
CUTOFF_EPOCH=$(date -d "today -6 days 00:00:00" +%s)

# Os 4 últimos domingos (inclui hoje, caso hoje seja domingo)
DOW=$(date +%w)                                  # 0=domingo .. 6=sábado
BASE_SUNDAY=$(date -d "today -$DOW days" +%Y-%m-%d)
KEEP_SUNDAYS=""
for W in 0 1 2 3; do
  KEEP_SUNDAYS="$KEEP_SUNDAYS $(date -d "$BASE_SUNDAY -$((W * 7)) days" +%Y-%m-%d)"
done

for ENTRY in "$BKP_PATH"/io_backend_*; do
  [ -e "$ENTRY" ] || continue
  NAME=$(basename "$ENTRY")

  # extrai AAAA-MM-DD do nome; nomes fora do padrão são preservados
  FDATE=$(echo "$NAME" | sed -n 's/^io_backend_\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)_.*/\1/p')
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

mkdir -p $BKP_PATH/$BKP_FOLDER/backend

echo "Running Docker Compose backup process..."

cd $IO_PATH

docker compose build --force-rm --no-cache backup

docker compose run --rm --no-deps backup

echo "Copying backup and config files..."

cp -r $IO_PATH/.embrapa/* $BKP_PATH/$BKP_FOLDER/backend/

rm $IO_PATH/.embrapa/backup/*.tar.gz

cp $IO_PATH/.env* $BKP_PATH/$BKP_FOLDER/backend/

if type docker-backup > /dev/null 2>&1; then
    set +e

    echo "Starting Docker backup process with 'docker-backup' to all containers..."

    mkdir -p $BKP_PATH/$BKP_FOLDER/docker

    cd $BKP_PATH/$BKP_FOLDER/docker

    docker-backup backup --all --stopped --tar --verbose
    DOCKER_BACKUP_RC=$?

    set -e

    # Avisa (sem abortar) se o docker-backup falhou.
    if [ "$DOCKER_BACKUP_RC" -ne 0 ]; then
      echo >&2 "WARNING: 'docker-backup' saiu com código $DOCKER_BACKUP_RC — o backup pode estar incompleto!"
    fi
else
    echo "Command 'docker-backup' not found! See: https://github.com/muesli/docker-backup"
fi

echo "Compressing backup folder..."

cd /tmp

tar -czvf $BKP_PATH/$BKP_FOLDER.tar.gz -C $BKP_PATH $BKP_FOLDER

rm -rf $BKP_PATH/$BKP_FOLDER

echo "All done! Backup file at: $BKP_PATH/$BKP_FOLDER.tar.gz"

echo "Clean up unused images..."

docker builder prune -af --filter "until=24h" || true

docker image prune -af --filter "until=24h" || true
