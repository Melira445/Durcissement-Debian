
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


