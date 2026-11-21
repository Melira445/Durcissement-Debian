#!/bin/bash
set -euo pipefail

DEST="/mnt/backup"
GARDER=7

if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être lancé en root" >&2
    exit 1
fi

if ! mountpoint -q "$DEST"; then
    echo "Erreur : $DEST n'est pas monté" >&2
    exit 2
fi

NOUVELLE="$DEST/$(date +%F_%H%M%S)"
PRECEDENTE=$(ls -1d "$DEST"/20* 2>/dev/null | tail -n 1 || true)

if [ -n "$PRECEDENTE" ]; then
    rsync -aAX --link-dest="$PRECEDENTE" /srv /etc "$NOUVELLE/"
else
    rsync -aAX /srv /etc "$NOUVELLE/"
fi
logger -t sauvegarde "Sauvegarde créée : $NOUVELLE"
echo "Sauvegarde créée : $NOUVELLE"

ls -1d "$DEST"/20* | head -n -"$GARDER" | while read -r ancienne; do
    rm -rf "$ancienne"
    logger -t sauvegarde "Ancienne version supprimée : $ancienne"
done
