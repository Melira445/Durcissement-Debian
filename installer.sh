#!/bin/bash
set -e
cd "$(dirname "$0")"

# Paquets nécessaires
apt-get update
apt-get install -y rsync acl unattended-upgrades nftables fail2ban

# D1 : mises à jour automatiques
cp config/apt/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades

# C1, C2 : comptes, groupes et ACL
bash ./creer_comptes.sh

# C3 : droits sudo
cp config/sudoers.d/biolab /etc/sudoers.d/biolab
chmod 440 /etc/sudoers.d/biolab

# Scripts lancés en root, propriété de root
cp sauvegarde.sh /usr/local/sbin/sauvegarde.sh
cp analyse_logs.sh /usr/local/sbin/analyse_logs.sh
chmod 755 /usr/local/sbin/sauvegarde.sh /usr/local/sbin/analyse_logs.sh

# J3 : journal persistant
mkdir -p /etc/systemd/journald.conf.d
mkdir -p /var/log/journal
cp config/journald.conf /etc/systemd/journald.conf.d/persistant.conf
systemctl restart systemd-journald

# J2 : pare-feu
cp config/nftables.conf /etc/nftables.conf
systemctl enable nftables
systemctl restart nftables

# J1 : fail2ban
cp config/fail2ban/jail.d/sshd.conf /etc/fail2ban/jail.d/sshd.conf
systemctl enable fail2ban
systemctl restart fail2ban

# B1, B3 : disque de sauvegarde
bash ./preparer_disque.sh

# B2 : timer de sauvegarde
cp config/systemd/sauvegarde.service /etc/systemd/system/
# B2 : timer de sauvegarde
cp config/systemd/sauvegarde.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now sauvegarde.timer

# S1 à S5 : SSH, configuration testée avec sshd -t avant rechargement
cp config/ssh/00-biolab.conf /etc/ssh/sshd_config.d/00-biolab.conf
sshd -t
systemctl reload ssh

# C3 : plus aucun sudo hors admins ; C4 : root verrouillé
gpasswd -d yasmine sudo 2>/dev/null || true
passwd -l root

/usr/local/sbin/sauvegarde.sh
sleep 2
/usr/local/sbin/sauvegarde.sh

echo "Installation terminée"
