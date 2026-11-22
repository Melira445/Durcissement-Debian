
## 1. Tableau de conformité

| ID | Mise en place | Vérification et état |
|---|---|---|
| S1 | Authentification SSH par clé uniquement. | `mjames` se connecte par clé. Une nouvelle tentative sans clé est refusée. `sudo id -u` renvoie `0` après  la connexion.
| S2 | PermitRootLogin no interdit la connexion SSH par root.la valeur `permitrootlogin no` est affichée par `sshd -T` et une tentative de connexion directe en root est denied
| S3 | AllowGroups acces_ssh limite l’accès SSH aux membres de ce groupe. | Validé : `tech1` appartient au groupe `technique` et pas à `acces_ssh`. Le journal SSH confirme un refus dû à `AllowGroups`. |
| S4 | MaxAuthTries 4 et ChannelTimeout session=15m. | Les valeurs `maxauthtries 4` et `channeltimeout session=15m` ont été vérifiées avec `sshd -T`. La fermeture d’une nouvelle session inactive est effective.
| S5 | Configuration SSH dans `/etc/ssh/sshd_config.d/` et copie dans `config/ssh/00-biolab.conf`. | Le contrôle manuel avec `sshd -t` a réussi.|


## 2. Choix techniques

- S1 et S2 —Les administrateurs se connectent avec leur propre compte et leur clé SSH, puis utilisent `sudo` si nécessaire. Cela évite d’ouvrir une session SSH directement en `root`.
- S3 — Le groupe `acces_ssh` définit l’accès au service SSH.
- S4 — Quatre essais par connexion.Elle ne bloque pas les nouvelles connexions d’une même adresse IP.
- S4 — Le canal de session est fermé après 15 minutes sans trafic, ce qui limite la durée d’une session laissée ouverte.

## 3. Défense : attaques rendues plus difficiles et limites

- Essais de mots de passe sur SSH :** l’authentification par mot de passe est désactivée. Cela ne protège pas contre le vol d’une clé privée autorisée et utilisable.
- Connexion directe avec le compte root est interdite. Cela n’empêche pas un attaquant qui compromet un compte administrateur d’essayer d’utiliser ses droits `sudo`.
- Accès SSH depuis un compte métier hors groupe :`AllowGroups` rejette le compte. Cette règle ne remplace pas les permissions et les ACL sur les fichiers du laboratoire.

## 4. Procédure de restauration


## 1. Tableau de conformité (parties C1, C2, C4, J1 à J4)

| ID | Mise en place | Test dans verifier.sh | Vérification et état |
|---|---|---|---|
| C1 | `creer_comptes.sh` lit `comptes.csv`, crée les 7 groupes et les 11 comptes (groupe principal, groupes secondaires, shell `nologin` pour `invite`). Le script peut être relancé sans erreur. | `test_C1` (à ajouter) | Lancé deux fois : la seconde exécution affiche « existe déjà » partout, sans erreur ni doublon. |
| C2 | `creer_comptes.sh` crée `/srv/donnees_brutes`, `/srv/analyses` et `/srv/publications`, retire les droits aux autres (`chmod o-rwx`) et pose les ACL du tableau du contexte C (`setfacl -m`), y compris les ACL par défaut (`setfacl -d -m`). | `test_C2a`, `test_C2b`, `test_C2c` | Testé avec `sudo -u` : `tech1` écrit dans `donnees_brutes`, `cher1` et `invite1` sont refusés ; un fichier créé par `tech1` est lisible par `cher1` (ACL par défaut) ; `doct1` écrit dans `analyses`, `tech1` est refusé ; `invite1` lit `publications` mais n'y écrit pas. |
| C4 | `passwd -l root` verrouille root ; `chmod 700 /home/*` ferme les répertoires personnels aux autres. | `test_C4a`, `test_C4b` | `passwd -S root` affiche `L` ; aucun dossier de `/home` n'est accessible aux autres. |
| J1 | `config/fail2ban/jail.d/sshd.conf` : prison `sshd`, `backend = systemd`, `banaction = nftables`, `maxretry = 4`, `findtime = 10m`, `bantime = 10m`. | `test_J1` | Après des échecs répétés depuis le poste client, son adresse est apparue dans « Banned IP list », puis a été libérée avec `fail2ban-client set sshd unbanip`. |
| J2 | `config/nftables.conf` : table `inet filtre`, chaîne `entree` en `policy drop`, avec acceptation des connexions établies, de la boucle locale et du port 22. Fichier copié dans `/etc/nftables.conf`, service `nftables` activé. | `test_J2`, `test_J2b` | `nft list ruleset` confirme les règles ; SSH fonctionne, le ping est refusé ; les règles sont revenues après un redémarrage ; un `reload` n'a pas supprimé la table de fail2ban. |
| J3 | `config/journald.conf` (`Storage=persistent`) installé dans `/etc/systemd/journald.conf.d/`. | `test_J3` | `journalctl --list-boots` liste plusieurs démarrages, dont celui d'avant le redémarrage de test. |
| J4 | `analyse_logs.sh` : rapport sur 24 h (échecs par adresse IP, comptes visés, connexions réussies). Codes de sortie : 0 (rien), 1 (pas lancé en root), 2 (seuil dépassé). Seuil : 5 échecs par adresse. | `test_J4` | Sans root : erreur et code 1. Avec 6 échecs de test : « ALERTE » et code 2. |
| (clés) | `creer_comptes.sh` installe les clés publiques de `config/cles_publiques/` pour les comptes de `acces_ssh` (`.ssh` en 700, `authorized_keys` en 600). | `test_CLES` (à ajouter) | Avec une clé de test : connexion de `support` sans mot de passe. |

## 2. Choix techniques

- C1 : le script teste l'existence de chaque groupe et de chaque compte avant de le créer, ce qui le rend relançable (idempotent). `comptes.csv` ne contient aucun mot de passe. Le groupe `invite` reçoit `/usr/sbin/nologin` : aucun terminal, seulement du transfert de fichiers.
- C2 : les permissions classiques n'offrent qu'un seul groupe par dossier. Les ACL permettent de donner des droits différents à plusieurs groupes. Pour un dossier, « lecture » correspond à `r-x` et « lecture/écriture » à `rwx`, car le `x` permet d'y entrer. Les ACL par défaut s'appliquent aux fichiers créés plus tard.
- C4 : root est verrouillé, on administre avec `sudo` depuis un compte nominatif. Les dossiers personnels en 700 empêchent un utilisateur de lire ceux des autres.
- J1 : `maxretry = 4` est aligné sur `MaxAuthTries 4` de SSH. `bantime = 10m` est assez court pour ne pas se bannir soi-même pendant les tests et la soutenance (en production, une durée plus longue serait préférable). `backend = systemd` car Debian 13 minimale n'a pas de fichier `auth.log`. Aucune adresse n'est exclue (`ignoreip`), pour pouvoir démontrer le bannissement.
- J2 : `policy drop` refuse tout par défaut. La boucle locale est acceptée pour que la machine puisse communiquer avec elle-même. Le ping est refusé, ce qui est cohérent avec « tout est refusé sauf SSH ». La table a un nom propre et le fichier n'utilise pas `flush ruleset`, qui effacerait aussi les règles de fail2ban. On utilise `reload` et non `restart`, car l'arrêt du service nftables efface toutes les règles.
- J3 : réglage explicite alors que Debian gardait déjà le journal sur disque : il garantit que ça reste vrai.
- J4 : le script lit `journalctl -u ssh`. Il ne compte que les lignes `Failed password` (une ligne = une tentative ratée). La période est de 24 h. Le seuil est de 5 échecs par adresse : [à justifier avec tes mots]. Le script n'accepte aucun argument, car la règle sudo de `support` interdit les arguments, et il appartient à root.

## 3. Défense : attaques rendues plus difficiles et limites

- Force brute sur SSH : fail2ban bannit l'adresse après 4 échecs, et `analyse_logs.sh` repère les adresses insistantes. Limites : un attaquant qui change d'adresse ou qui espace ses essais passe sous le seuil ; fail2ban réagit après coup.
- Scan de ports / service exposé : le pare-feu refuse tout sauf SSH. Limites : SSH reste exposé, et une faille de sshd ne serait pas bloquée ; le trafic sortant n'est pas filtré.
- Utilisateur curieux : les dossiers personnels sont en 700 et les ACL limitent l'accès à `/srv`. Limites : root et les administrateurs voient tout, et un compte avec `sudo` contourne ces règles.
- Compte métier compromis (par exemple un chercheur) : l'attaquant ne peut lire ou écrire que ce que les ACL autorisent à ce compte. Limites : il accède à tout ce que ce compte peut lire, et les données ne sont pas chiffrées.
- Effacement des traces après un incident : le journal persistant permet d'enquêter même après un redémarrage. Limites : il est stocké sur la machine elle-même, donc un attaquant root peut l'effacer, et il n'est pas copié ailleurs.


## Tableau de conformité : parties B et D

| ID | Ce qui a été fait | Test | ANSSI |
|----|-------------------|------|-------|
| B1 | Un second disque sert aux sauvegardes. sauvegarde.sh copie /srv et /etc avec rsync. Chaque copie est dans un dossier daté. On garde 7 copies. | test_B1, B1b, B1c | R68 |
| B2 | La sauvegarde se lance chaque nuit à 02:00 et écrit dans le journal. | test_B2, B2b | R68 |
| B3 | Seuls root et les admins ouvrent /mnt/backup. | test_B3 | R50 |
| B4 | Un fichier supprimé a été récupéré depuis une copie. | test_B4 | R68 |
| D1 | Les mises à jour de sécurité s'installent toutes seules. | test_D1 | R61 |
| D2 | Seul SSH (port 22) écoute sur le réseau. | test_D2 | R62 |
| D3 | Aucun fichier modifiable par tous. 11 fichiers SUID, expliqués plus bas. | test_D3a, D3b | R57, R58 |

## Choix techniques : parties B et D

- ext4 : le format standard de Debian.
- Montage par UUID (le nom /dev/sdb peut changer). nofail : on démarre même sans le disque.
- Le disque n'est formaté que s'il est vide, sinon installer.sh effacerait les sauvegardes.
- rsync -aAX : garde les droits, les ACL et les attributs.
- --link-dest : un fichier inchangé n'est pas recopié, il pointe vers la copie précédente. On gagne de la place.
- 7 copies : une semaine d'historique, le minimum demandé.
- 02:00 : le serveur est peu utilisé. Persistent=true : si la machine est éteinte, la sauvegarde se fait au démarrage.
- Timer systemd plutôt que cron : il écrit dans le journal et attend le montage du disque.
- Les scripts sont dans /usr/local/sbin, propriété de root : personne d'autre ne peut les modifier.

## D2 : ports en écoute

Seul SSH écoute en TCP. Le client DHCP (dhcpcd) utilise les ports UDP 68 et 546 pour recevoir sa configuration réseau. Ce n'est pas un service accessible de l'extérieur.

## D3 : fichiers SUID

| Fichier | Rôle |
|---------|------|
| passwd | changer son mot de passe |
| chfn, chsh | changer son nom ou son shell |
| gpasswd, newgrp | gérer les groupes |
| su, sudo | devenir un autre utilisateur |
| mount, umount | monter des disques |
| ssh-keysign | authentification SSH par hôte (désactivée) |
| dbus-daemon-launch-helper | lancer les services D-Bus |

## Procédure de restauration

1. Lister les copies : sudo ls /mnt/backup
2. Choisir une copie, par exemple 2026-11-21_002415.
3. Un fichier : sudo cp -a /mnt/backup/VERSION/srv/chemin/fichier /srv/chemin/
4. Un dossier : sudo rsync -aAX /mnt/backup/VERSION/srv/dossier/ /srv/dossier/
5. Vérifier avec ls -l.

Test fait : test_restauration.txt créé, sauvegardé, supprimé, restauré.
