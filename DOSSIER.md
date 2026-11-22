
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
