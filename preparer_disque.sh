#!/bin/bash
set -euo pipefail

# B1 : prépare le second disque (relançable sans risque)
DISQUE="/dev/sdb"
POINT="/mnt/backup"

if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être lancé en root" >&2
    exit 1
fi

if [ ! -b "$DISQUE" ]; then
    echo "Disque $DISQUE introuvable" >&2
    exit 1
fi

# Formate uniquement si le disque est vide (sinon on garde les sauvegardes)
if ! blkid "$DISQUE" >/dev/null 2>&1; then
    echo "Formatage de $DISQUE en ext4"
    mkfs.ext4 -q -L sauvegardes "$DISQUE"
else
    echo "$DISQUE a déjà un système de fichiers : pas de formatage"
fi

# Montage automatique par UUID dans /etc/fstab (ajouté une seule fois)
UUID=$(blkid -s UUID -o value "$DISQUE")
mkdir -p "$POINT"
if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID $POINT ext4 defaults,nofail 0 2" >> /etc/fstab
    systemctl daemon-reload
fi
mountpoint -q "$POINT" || mount "$POINT"

# B3 : accès réservé à root et au groupe admins
chown root:admins "$POINT"
chmod 750 "$POINT"
echo "Disque prêt : $POINT"
