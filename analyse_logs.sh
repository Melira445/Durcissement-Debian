#!/bin/bash
# analyse_logs.sh : rapport sur les connexions SSH
# Codes de sortie : 0 = rien d'anormal, 1 = erreur, 2 = seuil d'alerte dépassé
# Aucun argument : le script est lancé par root ou via sudo (compte support).

SEUIL_ECHECS=5            # échecs depuis une même adresse IP qui déclenchent l'alerte
PERIODE="24 hours ago"    # période analysée

verifier_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Erreur : ce script doit être lancé en root." >&2
        exit 1
    fi
}

lire_journal() {
    journalctl -u ssh --since "$PERIODE" --no-pager
}

echecs_par_ip() {
    lire_journal | grep "Failed password" | sed -E 's/.*from ([^ ]+) port.*/\1/' | sort | uniq -c | sort -rn
}

comptes_vises() {
    lire_journal | grep "Failed password" | sed -E 's/.*Failed password for (invalid user )?([^ ]+) from.*/\2/' | sort | uniq -c | sort -rn
}

nb_reussies() {
    lire_journal | grep -c "Accepted"
}

rapport() {
    echo "=== Rapport SSH (depuis : $PERIODE) ==="
    echo
    echo "Échecs par adresse IP :"
    echecs_par_ip
    echo
    echo "Comptes visés :"
    comptes_vises
    echo
    echo "Connexions réussies : $(nb_reussies)"
    echo
}

verifier_seuil() {
    local max
    max=$(echecs_par_ip | head -n 1 | awk '{print $1}')
    max=${max:-0}
    if [ "$max" -ge "$SEUIL_ECHECS" ]; then
        echo "ALERTE : une adresse totalise $max échecs (seuil : $SEUIL_ECHECS)."
        exit 2
    fi
    echo "Aucune alerte (maximum : $max échecs, seuil : $SEUIL_ECHECS)."
    exit 0
}

# ---------- Programme principal ----------
verifier_root
rapport
verifier_seuil
