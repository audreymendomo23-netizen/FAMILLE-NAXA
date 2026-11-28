# Laboratoire matériel virtuel NAXA SECURITY
La CI exécute le code Android de l'application sur des appareils virtuels API 26 et 35, et des recettes de passerelle isolées. Elle est déclenchée sur la branche SECURITY, sans publication, sans compte de production et sans secrets. Tous les résultats sont étiquetés VIRTUAL ; un test ignoré ne vaut jamais PASS.
## Matrice de recette
| ID | Réserve | Épreuve automatisée | Limite de preuve |
|---|---|---|---|
| QR01/02 | NS-13 / NS-05 | Bitmap produit par l'application, décodage ZXing, image vide et codes malformés refusés | Pas de caméra physique, de luminosité ou de capteur réel |
| GPS01/02 | NS-05 | Règles de fraîcheur/précision, injection via LocationManager Android, détection et refus du mock | Pas de réception satellite ni précision terrain |
| STORAGE01/02 | NS-31 | ContentResolver sur fichier privé, empreinte SHA-256, altération, limites 0/256 Kio/256 Kio+1 | Pas de fournisseur SAF distant ni stockage hébergé |
| DEVICE01 | NS-05 | Inventaire des capacités déclarées NFC/BLE/GPS/caméra | Aucun lecteur RFID, NFC ou BLE raccordé : présence de feature ≠ lecture effective |
| EDGE | NS-18 / NS-33 | Signatures, panne réseau simulée, file durable, rejeu, reçu et refus d'actuation | Aucun périphérique physique ni transport vers un site réel |
## Qualification physique distincte
Pour obtenir un PASS physique, utiliser un téléphone dédié et un équipement autorisé, hors production : caméra lisant un QR affiché sur un second écran, GPS réellement reçu, badge/lecteur NFC ou RFID identifié, balise BLE compatible, réception d'une observation de passerelle et preuve stockée/restituée. Conserver commit, version APK, modèle et firmware pseudonymisés, conditions, heure, résultat attendu/observé et logs expurgés. Ne jamais exécuter l'injection mock sur un téléphone physique ; le script CI la refuse explicitement. Ne pas publier les identifiants des badges, coordonnées réelles, tokens, images ou secrets dans le dépôt public. Les intégrations NFC/RFID/BLE non implémentées restent ouvertes, indépendamment de l'émulateur. Les flux réels et la conservation effective nécessitent des scénarios dédiés, aucun résultat ne leur est attribué ici.
## Reproduction et preuves
Workflow `naxa-security-hardware.yml`, matrices API 26/35 en parallèle et EDGE. Chaque run produit les XML JUnit et l'inventaire des capacités, 14 jours de conservation. Le script exige les sept cas Android exécutés et réussis, sans test sauté. Le laboratoire utilise les primitives de production, et ne modifie pas les règles de sécurité pour accepter des preuves simulées. Aucun verdict global sans qualification serveur et matérielle indépendante.
