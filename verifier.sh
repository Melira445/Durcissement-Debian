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

# Programme principal
test_C2a

echo "--- $NB_OK / $NB_TOTAL tests réussis"
if [ "$NB_OK" -eq "$NB_TOTAL" ]; then
    exit 0
else
    exit 1
fi
