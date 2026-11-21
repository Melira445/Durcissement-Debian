#!/bin/bash
set -e
cd "$(dirname "$0")"

apt-get update
apt-get install -y rsync acl unattended-upgrades nftables fail2ban

cp config/apt/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades

bash ./creer_comptes.sh

cp config/sudoers.d/biolab /etc/sudoers.d/biolab
chmod 440 /etc/sudoers.d/biolab

cp sauvegarde.sh /usr/local/sbin/sauvegarde.sh
cp analyse_logs.sh /usr/local/sbin/analyse_logs.sh
chmod 755 /usr/local/sbin/sauvegarde.sh /usr/local/sbin/analyse_logs.sh

mkdir -p /etc/systemd/journald.conf.d
mkdir -p /var/log/journal
cp config/journald.conf /etc/systemd/journald.conf.d/persistant.conf
systemctl restart systemd-journald

cp config/nftables.conf /etc/nftables.conf
systemctl enable nftables
systemctl restart nftables

cp config/fail2ban/jail.d/sshd.conf /etc/fail2ban/jail.d/sshd.conf
systemctl enable fail2ban
systemctl restart fail2ban

bash ./preparer_disque.sh

cp config/systemd/sauvegarde.service /etc/systemd/system/
cp config/systemd/sauvegarde.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now sauvegarde.timer

cp config/ssh/00-biolab.conf /etc/ssh/sshd_config.d/00-biolab.conf
sshd -t
systemctl reload ssh

passwd -l root

echo "Installation terminée"
