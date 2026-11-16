#!/bin/bash
# creer_comptes.sh : crée les groupes et les comptes à partir de comptes.csv

FICHIER_COMPTES="comptes.csv"

# Étape 1 : vérifier que le script est lancé en root
verifier_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Erreur : ce script doit être lancé en root." >&2
        exit 1
    fi
}

# Étape 2 : vérifier que comptes.csv existe
verifier_fichier() {
    :   # à écrire
}

# Étape 3 : créer les groupes s'ils n'existent pas déjà
creer_groupes() {
    :   # à écrire
}

# Étapes 4 et 5 : lire le CSV et créer les utilisateurs
creer_utilisateurs() {
    :   # à écrire
}

# ---------- Programme principal ----------

verifier_root
verifier_fichier
creer_groupes
creer_utilisateurs
