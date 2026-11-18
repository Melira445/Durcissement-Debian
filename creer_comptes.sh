#!/bin/bash
# creer_comptes.sh : crée les groupes et les comptes à partir de comptes.csv

FICHIER_COMPTES="comptes.csv"
GROUPES="admins support acces_ssh technique chercheurs doctorants invite"

# Étape 1 : vérifier que le script est lancé en root
verifier_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Erreur : ce script doit être lancé en root." >&2
        exit 1
    fi
}

# Étape 2 : vérifier que comptes.csv existe
verifier_fichier() {
    if [ ! -f "$FICHIER_COMPTES" ]; then
        echo "Erreur : le fichier $FICHIER_COMPTES est introuvable." >&2
        exit 1
    fi
}

# Étape 3 : créer les groupes s'ils n'existent pas déjà
creer_groupes() {
    for g in $GROUPES; do
        if getent group "$g" > /dev/null; then
            echo "Le groupe $g existe déjà."
        else
            groupadd "$g"
            echo "Groupe $g créé."
        fi
    done
}

# Étapes 4 et 5 : lire comptes.csv et créer les utilisateurs
lire_comptes() {
    tail -n +2 "$FICHIER_COMPTES" | while IFS=';' read -r login nom groupe_principal groupes_secondaires; do
        if [ -z "$login" ]; then
            continue
        fi

        if id "$login" > /dev/null 2>&1; then
            echo "Le compte $login existe déjà."
            continue
        fi

        if [ "$groupe_principal" = "invite" ]; then
            shell="/usr/sbin/nologin"
        else
            shell="/bin/bash"
        fi

        if [ -n "$groupes_secondaires" ]; then
            useradd -m -c "$nom" -g "$groupe_principal" -G "$groupes_secondaires" -s "$shell" "$login"
        else
            useradd -m -c "$nom" -g "$groupe_principal" -s "$shell" "$login"
        fi
        echo "Compte $login créé."
    done
}

# Étape 6 : créer un dossier et lui poser ses droits (permissions + ACL)
appliquer_droits() {
    local dossier="$1"
    local acl="$2"

    mkdir -p "$dossier"
    chmod o-rwx "$dossier"
    setfacl -m "$acl" "$dossier"
    setfacl -d -m "$acl" "$dossier"
    echo "Dossier $dossier prêt."
}

creer_repertoires() {
    appliquer_droits /srv/donnees_brutes "g:technique:rwx,g:chercheurs:rx,g:doctorants:rx"
    appliquer_droits /srv/analyses "g:chercheurs:rwx,g:doctorants:rwx"
    appliquer_droits /srv/publications "g:chercheurs:rwx,g:doctorants:rx,g:invite:rx"
}



# ---------- Programme principal ----------
verifier_root
verifier_fichier
creer_groupes
lire_comptes
creer_repertoires
