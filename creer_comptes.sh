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

# ---------- Programme principal ----------
verifier_root
verifier_fichier
creer_groupes
