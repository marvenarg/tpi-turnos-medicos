#!/bin/bash

set -e

FECHA_HORA=$(date +%Y-%m-%d_%H-%M-%S)

BASE="./resguardos_tpi"
DESTINO="$BASE/$FECHA_HORA"
TEMP="$DESTINO/dump"
ARCHIVO="$DESTINO/backup_$FECHA_HORA.tar.zst"

if [ -z "$MONGODB_URI" ]; then
    echo "Error: la variable MONGODB_URI no está definida."
    exit 1
fi

command -v mongodump >/dev/null 2>&1 || {
    echo "Error: mongodump no está disponible."
    exit 1
}

command -v tar >/dev/null 2>&1 || {
    echo "Error: tar no está disponible."
    exit 1
}

command -v zstd >/dev/null 2>&1 || {
    echo "Error: zstd no está disponible."
    exit 1
}

mkdir -p "$TEMP"

echo "Iniciando backup de MongoDB Atlas..."
echo "Directorio del respaldo: $DESTINO"

mongodump \
    --uri="$MONGODB_URI" \
    --out="$TEMP"

echo "Comprimiendo backup..."

tar --zstd -cf "$ARCHIVO" -C "$DESTINO" "dump"

rm -rf "$TEMP"

echo
echo "Backup finalizado correctamente."
echo "Archivo generado: $ARCHIVO"
