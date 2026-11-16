#!/bin/bash
# creer_comptes.sh : crée les groupes et les comptes à partir de comptes.csv

# 1. Vérifier que le script est lancé en root
# 2. Vérifier que comptes.csv existe
# 3. Créer les groupes s'ils n'existent pas déjà
# 4. Lire comptes.csv ligne par ligne (ignorer l'en-tête et les lignes vides)
# 5. Pour chaque ligne : créer l'utilisateur s'il n'existe pas déjà
#    (groupe principal, groupes secondaires, pas de shell pour invite)
