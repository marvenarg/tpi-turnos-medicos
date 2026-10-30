#!/bin/bash

set -e

FECHA_HORA=$(date +%Y-%m-%d_%H-%M-%S)

BASE="./resguardos_tpi"
TEMP="$BASE/$FECHA_HORA"
ARCHIVO="$BASE/backup_$FECHA_HORA.tar.zst"

if [ -z "$MONGODB_URI" ]; then
    echo "Error: la variable MONGODB_URI no está definida."
    exit 1
fi

mkdir -p "$TEMP"

echo "Iniciando backup de MongoDB Atlas..."
echo "Directorio temporal: $TEMP"

mongodump \
    --uri="$MONGODB_URI" \
    --out="$TEMP"

echo "Comprimiendo backup..."

tar --zstd -cf "$ARCHIVO" -C "$BASE" "$FECHA_HORA"

rm -rf "$TEMP"

echo "Backup finalizado correctamente."
echo "Archivo generado: $ARCHIVO"
