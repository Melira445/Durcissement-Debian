#!/bin/bash
set -euo pipefail

# B1 : sauvegarde de /srv et /etc sur le second disque, versions datées
# DEST = disque de sauvegarde, GARDER = nombre de versions conservées
DEST="/mnt/backup"
GARDER=7

# Vérifie qu'on est root
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être lancé en root" >&2
    exit 1
fi

# Vérifie que le disque de sauvegarde est monté
if ! mountpoint -q "$DEST"; then
    echo "Erreur : $DEST n'est pas monté" >&2
    exit 2
fi

# Nom de la nouvelle version (date et heure) et version précédente
NOUVELLE="$DEST/$(date +%F_%H%M%S)"
PRECEDENTE=$(ls -1d "$DEST"/20* 2>/dev/null | tail -n 1 || true)

# rsync : -a droits, -A ACL, -X attributs ; --link-dest évite de recopier les fichiers inchangés
if [ -n "$PRECEDENTE" ]; then
    rsync -aAX --link-dest="$PRECEDENTE" /srv /etc "$NOUVELLE/"
else
    rsync -aAX /srv /etc "$NOUVELLE/"
fi
logger -t sauvegarde "Sauvegarde créée : $NOUVELLE"
echo "Sauvegarde créée : $NOUVELLE"

# Rotation : supprime les versions au-delà des GARDER plus récentes
ls -1d "$DEST"/20* | head -n -"$GARDER" | while read -r ancienne; do
    rm -rf "$ancienne"
    logger -t sauvegarde "Ancienne version supprimée : $ancienne"
done
