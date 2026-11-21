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

# J3 : le journal système est conservé après un redémarrage
test_J3() {
    if grep -rqs '^Storage=persistent' /etc/systemd/journald.conf /etc/systemd/journald.conf.d/ && [ -d /var/log/journal ]; then
        ok "J3" "le journal système est persistant"
    else
        ko "J3" "le journal n'est pas configuré en Storage=persistent"
    fi
}

# J1 : fail2ban protège SSH
test_J1() {
    if systemctl is-active --quiet fail2ban && fail2ban-client status sshd > /dev/null 2>&1; then
        ok "J1" "fail2ban est actif et la prison sshd est en service"
    else
        ko "J1" "fail2ban ou la prison sshd n'est pas actif"
    fi
}

# J4 : analyse_logs.sh renvoie 0 sans alerte et 2 si le seuil est dépassé
test_J4() {
    local script
    script="$(dirname "$0")/analyse_logs.sh"
    SEUIL_ECHECS=1000000 bash "$script" > /dev/null 2>&1
    local code_calme=$?
    SEUIL_ECHECS=0 bash "$script" > /dev/null 2>&1
    local code_alerte=$?
    if [ "$code_calme" -eq 0 ] && [ "$code_alerte" -eq 2 ]; then
        ok "J4" "analyse_logs.sh renvoie 0 sans alerte et 2 si le seuil est dépassé"
    else
        ko "J4" "codes de sortie inattendus (calme : $code_calme, alerte : $code_alerte)"
    fi
}

# D1 : les mises à jour de sécurité s'installent automatiquement
test_D1() {
    if dpkg-query -W -f='${Status}' unattended-upgrades 2>/dev/null | grep -q "install ok installed" \
       && apt-config dump | grep -q '^APT::Periodic::Unattended-Upgrade "1"'; then
        ok "D1" "unattended-upgrades est installé et activé"
    else
        ko "D1" "unattended-upgrades n'est pas installé ou pas activé"
    fi
}

# J2 : pare-feu nftables, entrée refusée par défaut sauf SSH et connexions établies
test_J2() {
    local regles
    regles="$(nft list chain inet filtre entree 2>/dev/null)"
    if echo "$regles" | grep -q "policy drop" \
       && echo "$regles" | grep -q "established" \
       && echo "$regles" | grep -q "dport 22 accept" \
       && systemctl is-enabled --quiet nftables; then
        ok "J2" "pare-feu : entrée refusée par défaut, SSH et connexions établies acceptées, actif au démarrage"
    else
        ko "J2" "règles nftables absentes ou incomplètes, ou service nftables non activé"
    fi
}

# J2 : fail2ban bannit via nftables
test_J2b() {
    if fail2ban-client get sshd actions 2>/dev/null | grep -q "nftables"; then
        ok "J2" "fail2ban bannit via nftables"
    else
        ko "J2" "la prison sshd n'utilise pas l'action nftables"
    fi
}

# C4 : le compte root est verrouillé
test_C4a() {
    if [ "$(passwd -S root | awk '{print $2}')" = "L" ]; then
        ok "C4" "le compte root est verrouillé"
    else
        ko "C4" "le compte root n'est pas verrouillé"
    fi
}

# C4 : les répertoires personnels ne sont pas accessibles aux autres
test_C4b() {
    local ouverts
    ouverts=$(find /home -mindepth 1 -maxdepth 1 -type d -perm /007)
    if [ -z "$ouverts" ]; then
        ok "C4" "les répertoires personnels sont fermés aux autres"
    else
        ko "C4" "répertoires accessibles aux autres : $ouverts"
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
test_J3
test_J1
test_J4
test_D1
test_J2
test_J2b
test_C4a
test_C4b

test_B1
test_B1b
test_B1c
test_B2
test_B2b
test_B3
test_B4
test_D2
test_D3a
test_D3b

echo "--- $NB_OK / $NB_TOTAL tests réussis"
if [ "$NB_OK" -eq "$NB_TOTAL" ]; then
    exit 0
else
    exit 1
fi
