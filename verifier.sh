#!/bin/bash
# verifier.sh : teste les exigences du projet et affiche [OK] ou [KO]
# Ce script ne modifie jamais le système.

NB_OK=0
NB_TOTAL=0

ok() {
    echo "[OK] $1 $2"
    NB_OK=$((NB_OK + 1))
    NB_TOTAL=$((NB_TOTAL + 1))
}

ko() {
    echo "[KO] $1 $2"
    NB_TOTAL=$((NB_TOTAL + 1))
}

# C2 : tech1 (groupe technique) peut écrire dans /srv/donnees_brutes
test_C2a() {
    if sudo -u tech1 test -w /srv/donnees_brutes; then
        ok "C2" "tech1 peut écrire dans /srv/donnees_brutes"
    else
        ko "C2" "tech1 ne peut pas écrire dans /srv/donnees_brutes"
    fi
}

# C2 : cher1 (chercheurs) ne peut PAS écrire dans /srv/donnees_brutes
test_C2b() {
    if sudo -u cher1 test -w /srv/donnees_brutes; then
        ko "C2" "cher1 peut écrire dans /srv/donnees_brutes (attendu : refusé)"
    else
        ok "C2" "cher1 ne peut pas écrire dans /srv/donnees_brutes"
    fi
}

# C2 : invite1 ne peut PAS lire /srv/donnees_brutes
test_C2c() {
    if sudo -u invite1 test -r /srv/donnees_brutes; then
        ko "C2" "invite1 peut lire /srv/donnees_brutes (attendu : refusé)"
    else
        ok "C2" "invite1 ne peut pas lire /srv/donnees_brutes"
    fi
}



# B1 : le disque est monté et il y a au moins une sauvegarde
test_B1() {
    if mountpoint -q /mnt/backup && ls -d /mnt/backup/20* >/dev/null 2>&1; then
        ok "B1" "disque monté et sauvegarde présente"
    else
        ko "B1" "disque non monté ou aucune sauvegarde"
    fi
}

# B1 : sauvegarde incrémentale (un fichier est partagé entre versions)
test_B1b() {
    if find /mnt/backup -path '*/etc/hostname' -links +1 | grep -q .; then
        ok "B1" "sauvegarde incrémentale (liens physiques)"
    else
        ko "B1" "aucun fichier partagé entre les versions"
    fi
}

# B1 : le script garde 7 versions
test_B1c() {
    if grep -q '^GARDER=7' /usr/local/sbin/sauvegarde.sh; then
        ok "B1" "rotation sur 7 versions"
    else
        ko "B1" "GARDER n'est pas à 7"
    fi
}

# B2 : le timer est activé
test_B2() {
    if systemctl is-enabled sauvegarde.timer >/dev/null 2>&1; then
        ok "B2" "timer de sauvegarde activé"
    else
        ko "B2" "timer de sauvegarde non activé"
    fi
}

# B2 : le journal contient une trace de sauvegarde
test_B2b() {
    if journalctl -t sauvegarde --no-pager | grep -q 'Sauvegarde créée'; then
        ok "B2" "sauvegardes journalisées"
    else
        ko "B2" "aucune trace dans le journal"
    fi
}

# B3 : /mnt/backup est réservé à root et admins
test_B3() {
    if [ "$(stat -c '%a %U:%G' /mnt/backup)" = "750 root:admins" ]; then
        ok "B3" "/mnt/backup en 750 root:admins"
    else
        ko "B3" "mauvais droits sur /mnt/backup"
    fi
}

# B4 : on peut relire /etc/hostname depuis la dernière sauvegarde
test_B4() {
    local version
    version=$(ls -d /mnt/backup/20* | tail -n 1)
    if cmp -s "$version/etc/hostname" /etc/hostname; then
        ok "B4" "restauration possible depuis la sauvegarde"
    else
        ko "B4" "fichier de la sauvegarde différent ou absent"
    fi
}

# D1 : mises à jour automatiques activées
test_D1() {
    if grep -q 'Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades; then
        ok "D1" "mises à jour automatiques activées"
    else
        ko "D1" "mises à jour automatiques non activées"
    fi
}

# D2 : aucun port TCP n'écoute sauf le 22
test_D2() {
    if ss -tln | tail -n +2 | grep -v ':22 ' | grep -q .; then
        ko "D2" "un port TCP autre que 22 écoute"
    else
        ok "D2" "seul SSH écoute en TCP"
    fi
}

# D3 : aucun fichier modifiable par tous
test_D3a() {
    if find / -xdev -type f -perm -0002 -not -path '/tmp/*' -not -path '/var/tmp/*' 2>/dev/null | grep -q .; then
        ko "D3" "il existe des fichiers modifiables par tous"
    else
        ok "D3" "aucun fichier modifiable par tous"
    fi
}

# D3 : il y a exactement 11 fichiers SUID (ceux du dossier)
test_D3b() {
    local nb
    nb=$(find / -xdev -type f -perm -4000 2>/dev/null | wc -l)
    if [ "$nb" -eq 11 ]; then
        ok "D3" "11 fichiers SUID, comme dans le dossier"
    else
        ko "D3" "$nb fichiers SUID (attendu : 11)"
    fi
}

# Programme principal
test_C2a
test_C2b
test_C2c

test_B1
test_B1b
test_B1c
test_B2
test_B2b
test_B3
test_B4
test_D1
test_D2
test_D3a
test_D3b

echo "--- $NB_OK / $NB_TOTAL tests réussis"
if [ "$NB_OK" -eq "$NB_TOTAL" ]; then
    exit 0
else
    exit 1
fi
