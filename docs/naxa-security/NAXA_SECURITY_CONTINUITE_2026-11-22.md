# Continuité produit — NAXA SECURITY 360°
**Version :** 1.0  
**Date :** 22 novembre 2026  
**Dépôt :** audreymendomo23-netizen/FAMILLE-NAXA  
**Branche de référence :** main  
**Dossier documentaire :** docs/naxa-security/  
**Application :** apps/android/naxa-security/  
**État général :** cadrage fonctionnel consolidé ; réalisation métier non démontrée ; recette matérielle non exécutée

---

## 1. Objet de cette passation

Ce document permet à une nouvelle session, à un développeur ou à un agent de reprendre NAXA SECURITY sans perdre les décisions, sans confondre intention et réalisation, et sans recommencer les travaux déjà consignés.

Il doit être lu avec :
1. NAXA_SECURITY_CAHIER_DES_CHARGES_V1.1.md — référence fonctionnelle et technique.
2. README.md du monorepo.
3. AGENTS.md — règles de gouvernance.
4. docs/ARCHITECTURE_CIBLE.md — architecture générale FAMILLE-NAXA.
5. docs/CONTINUITE.md — continuité générale de la famille.

**Règle fondamentale :** NAXA SECURITY appartient à **FAMILLE-NAXA**. Il ne s'agit pas du projet NAXA Pharmacie, ni d'un module de ce dernier. Ne pas importer les utilisateurs, rôles, schémas métier, clés, données, services ou règles de NAXA Pharmacie par simple proximité de nom.

## 2. Périmètre produit approuvé

NAXA SECURITY est une application logicielle SaaS/ERP de sécurité physique, connectivité et supervision à distance d'équipements tiers.

### 2.1 Ce que fournit NAXA
- application Android autonome ;
- expérience Web responsive/PWA distincte ;
- logiciel local NAXA EDGE et connecteurs logiciels ;
- services Cloud autorisés ;
- configuration, appairage logique, gestion des équipements compatibles ;
- supervision à distance des états, alarmes et appareils ;
- traitement d'événements, automatisations et IA complémentaire ;
- gestion des organisations, sites, utilisateurs, actifs, contrats, interventions et maintenance ;
- abonnement, facturation, notifications, support logiciel et documentation.

### 2.2 Ce que NAXA ne fournit pas
- aucune caméra, centrale, sirène, détecteur, traceur, lecteur, badge, serveur ou autre équipement matériel ;
- aucun câblage, travaux d'électricité, génie civil ni installation physique du matériel dans le forfait logiciel ;
- aucune certification de matériel ou de centrale incendie tierce ;
- aucun gardiennage ou service de surveillance humaine permanente ;
- aucune intervention physique garantie sur site ;
- aucun service de police, de secours ou de lutte contre l'incendie.

Le matériel appartient au client ou est fourni/posé par un fabricant, vendeur, installateur ou intégrateur tiers. Le logiciel se connecte uniquement aux capacités réellement disponibles et testées.

## 3. Décisions commerciales verrouillées [V]

| Offre | Mensuel | Annuel | Couverture |
|---|---:|---:|---|
| Essentiel | 5 000 FCFA/mois | 60 000 FCFA/an | Un seul site |
| Business | 20 000 FCFA/mois | 200 000 FCFA/an | Multisite |
| Professional | 50 000 FCFA/mois | 500 000 FCFA/an | Tous les produits et services NAXA SECURITY + ERP complet |

- L'annuel Essentiel représente 12 mensualités ; aucun mois gratuit supplémentaire n'est implicite.
- Les annuels Business et Professional donnent 12 mois de service pour 10 mensualités.
- Une souscription globale par organisation couvre les sites prévus par l'offre ; ne pas créer un abonnement distinct par site par défaut.
- Les prix ne concernent pas les autres applications de FAMILLE-NAXA. « Tous les produits et services » signifie le catalogue NAXA SECURITY.
- Le détail quantitatif des quotas (caméras, capteurs, utilisateurs, Edge, stockage, rétention, GPS, IA, rondes, API et flux simultanés) reste à chiffrer et publier avant commercialisation.
- Essai de 14 jours et extensions à +20 % par extension figurent dans le cahier v1.1 ; les modalités exactes, unités et éventuels frais uniques doivent être conservés comme paramètres à finaliser avant vente si non encore contractuellement arbitrés.
- Paiements prévus : Orange Money, MTN Mobile Money, virement et facturation B2B. Pas de cartes bancaires dans le périmètre initial approuvé. Aucun droit ne s'active sur capture d'écran ou référence non vérifiée ; confirmation serveur obligatoire.

Ne jamais réintroduire quatre plans historiques, un plan Enterprise, ou les prix antérieurs. Le nom français « Essentiel » doit être utilisé dans les nouveaux écrans et documents.

## 4. Périmètre fonctionnel consolidé

Le cahier v1.1 décrit 35 modules, qui constituent une seule application et non 35 applications séparées :

1. SECURITY CORE — organisations, utilisateurs, comptes et gouvernance.
2. VIDEO — caméras, DVR/NVR, flux, enregistrements et recherche.
3. AUDIO — audio entrant/sortant, interphonie et alertes sonores.
4. GPS — personnes, agents, véhicules et actifs dans les conditions autorisées.
5. PRESENCE — pointage, présence, horaires, affectations et visiteurs.
6. PATROL — rondes, itinéraires, checkpoints et comptes rendus.
7. ACCESS — portes, badges, lecteurs, contrôleurs et permissions.
8. ALARMS & SOS — intrusion, panique, sabotage et sirènes.
9. REMOTE ACTIONS — commandes distantes et scénarios contrôlés.
10. AI SECURITY — détection, corrélation, priorisation et synthèse.
11. FIRE & SMOKE — détecteurs, centrales, états et événements fumée/incendie.
12. ENVIRONMENT — gaz, CO, chaleur, eau, température, humidité et risques techniques.
13. VISITORS — pré-enregistrement, badges et historiques.
14. VEHICLES — véhicules, accès, stationnement et flotte.
15. SOS & PERSONAL SAFETY — bouton d'urgence et sécurité des personnes.
16. INCIDENTS — dossiers, responsables, actions, preuves et clôture.
17. CONTROL 360 — centre de supervision multisite/multi-organisation.
18. EDGE — connectivité, traitement local et mode dégradé.
19. COMPATIBILITY — catalogue, matrice, essais et statut de compatibilité.
20. ASSET & MAINTENANCE — inventaire, santé, maintenance et interventions.
21. ERP OPERATIONS — équipes, plannings, tâches et gestion opérationnelle.
22. REPORTING & BI — KPI, rapports et exports.
23. SUBSCRIPTIONS — plans, prix, quotas, droits et extensions.
24. PAYMENTS — Mobile Money, banque, factures et rapprochement.
25. LIVECARE — FAQ, livechat, agent humain, audio/vidéo et partage d'écran sous consentement.
26. NOTIFICATIONS — push, SMS, e-mail, WhatsApp Business et alertes sonores.
27. AI ASSISTANT — aide utilisateur/opérateur.
28. LANGUAGE / I18N — français, anglais et Fulfulde.
29. ADMINISTRATION — administration produit et configuration.
30. SECURITY AUDIT — journaux et traçabilité.
31. STORAGE & EVIDENCE — stockage, intégrité, conservation et export.
32. OFFLINE & SYNC — persistance locale, files, idempotence et synchronisation.
33. INTEGRATIONS — API et interconnexion autorisée avec les applications sœurs.
34. BACKUP & RECOVERY — sauvegarde et restauration testée.
35. PARTNERS — fabricants, installateurs, intégrateurs et tiers.

## 5. Architecture cible et principes d'interopérabilité

### 5.1 Modèle hybride
Équipements tiers → réseau client → NAXA EDGE installé sur une machine/serveur du client → connexion sortante sécurisée vers Cloud → API/services → Android et Web/PWA.

NAXA ne fournit pas la machine Edge. Un DVR/NVR n'est pas présumé capable d'héberger NAXA EDGE. La vidéo et l'audio restent locaux par défaut ; le Cloud reçoit surtout événements, métadonnées, états et extraits expressément autorisés. Une visualisation distante doit passer par un relais/gateway sécurisé ; ne pas exposer RTSP directement sur Internet.

### 5.2 Compatibilité multimarque
Priorités à mettre en œuvre et à tester par famille :
- vidéo : ONVIF (profils pertinents selon capacités et version), RTSP/RTP et API constructeur ;
- enregistreurs : API/SDK constructeur et mécanismes documentés de recherche/lecture/export ;
- audio/interphonie : ONVIF lorsque supporté, SIP, API constructeur, entrées/sorties ;
- incendie : API officielle de la centrale, protocole documenté, passerelle fabricant/certifiée ou interfaces supervisées prévues par l'installateur ;
- accès : API/SDK contrôleurs, OSDP/Wiegand via contrôleur adapté, interfaces autorisées ;
- capteurs/IoT : MQTT, Modbus, BACnet, Zigbee/Z-Wave/LoRaWAN à travers passerelles documentées ;
- GPS : API et protocoles publiés par le fabricant du tracker ;
- présence : API des terminaux, RFID/NFC, QR, BLE et sources autorisées.

Un appareil Wi-Fi n'est pas automatiquement compatible. Le registre doit documenter modèle, révision, firmware, protocole, fonctions réellement testées, limites, résultats, date, version du connecteur et statut : expérimental, partiel, validé, certifié NAXA (recette interne limitée au modèle/firmware testé), ou non pris en charge. Ne pas prétendre à une certification ONVIF ou fabricant inexistante.

### 5.3 Identité, permissions et isolation
Hiérarchie cible : organisation → région → site → bâtiment → étage → zone → équipement. Les opérateurs externes ne voient une organisation cliente que par délégation explicite, limitée et auditée. Les droits s'appliquent côté serveur ; les restrictions d'interface seules ne sont pas suffisantes. Pas d'accès inter-applications implicite.

## 6. Scénarios fumée et incendie à ne pas confondre

### 6.1 Intégration des détecteurs de fumée
Sources possibles : détecteur autonome avec relais, détecteur raccordé à une centrale, modèle radio via passerelle, détecteur adressable ou connecté via API officielle. La centrale et les avertisseurs locaux restent autonomes.
Séquence : détection locale → logique locale de la centrale → signal local → transmission vers Edge via interface approuvée → horodatage et normalisation → identification organisation/site/zone/appareil → création d'événement fumée → affichage plan/caméras autorisées/détecteurs proches → notifications et escalade → acquittement logiciel sans arrêter l'alarme physique → intervention humaine du client/tiers → retour à la normale source → rapport de clôture.

### 6.2 Détection incendie / alarme feu
Sources possibles : détecteur thermique, flamme, multi-critères, déclencheur manuel, centrale conventionnelle/adressable, alarme de zone ou alarme générale. L'état FIRE_ALARM provenant de la centrale est critique et ne dépend ni de l'IA ni du Cloud.
Séquence : détection/déclencheur manuel → traitement par centrale → alarmes et dispositifs locaux autonomes → signal à Edge → incident critique → carte et plan d'évacuation approuvé → alertes prioritaires et accusés → escalade → suivi de zone et journal → intervention client/secours suivant procédure locale → inspection par personne habilitée → réarmement selon fabricant → rapport détaillé.
Une alarme fumée est un événement provenant du détecteur ; une alarme incendie peut être un état de la centrale ou une confirmation selon la logique homologuée. Les événements d'origine, de centrale et d'IA doivent rester distingués.

### 6.3 Sécurité incendie impérative
- L'alarme locale, la centrale et les dispositifs certifiés ne dépendent jamais de NAXA, du Cloud, des notifications push ou d'Internet.
- NAXA n'est pas une centrale incendie certifiée et ne remplace pas la détection requise.
- L'IA peut ajouter du contexte (caméra, capteurs voisins, résumé), mais ne retarde pas, ne déclasse pas et n'annule jamais une alarme de la centrale.
- L'acquittement dans NAXA n'arrête pas la sirène et ne signifie pas reset physique.
- Pas de désactivation globale, d'isolement ou de reset Cloud automatique de la centrale. Ces fonctions suivent la procédure fabricant par personne habilitée.
- Ne jamais verrouiller une issue d'évacuation. Les portes, désenfumage, ventilation, extinction et autres fonctions critiques doivent être définis par l'ingénierie incendie et les systèmes certifiés, pas par un scénario générique.
- Une perte de connexion ou un défaut détecteur est un événement technique distinct, non une fausse alarme feu.
- Tests sur installation de recette ou pendant maintenance planifiée, via les outils du fabricant et une personne compétente ; pas de production de fumée/flamme/gaz dangereux improvisée.

## 7. Services transversaux — état réel à ne pas surestimer

| Capacité | État de preuve actuel | Règle de reprise |
|---|---|---|
| Auth/session/MFA famille | architecture décrite ; maturité end-to-end non démontrée ici | auditer code, API, RLS, révocation et appareils |
| Organisations/RBAC | modèle cible décrit ; isolation/security complète non prouvée | auditer schémas, rôles et tests multi-tenant |
| Billing Core | package présent et règles de périodes documentées | vérifier source, tests, migration et entitlements SECURITY |
| Paiement réel | fournisseurs/webhooks/activation réelle non démontrés | ne pas afficher paiement opérationnel avant tests sandbox et serveur |
| Notifications FCM/SMS/WhatsApp | capacités visées ; livraison bout en bout non démontrée | vérifier providers, tokens, retries, statuts et préférences |
| Livecare | expérience cible complète ; chat humain/audio/vidéo/screen share non démontrés comme service commun prêt | auditer le centre support avant intégration |
| Fulfulde | préférence/code ff-CM existe dans un contexte familial, ressources complètes non démontrées | créer et faire relire toutes les ressources par locuteurs qualifiés |
| Offline/sync | socle queue local SECURITY présent ; synchronisation sécurisée complète non démontrée | ajouter outbox fiable, ack serveur, idempotence, retry, chiffrement, TTL |
| Storage/evidence | besoin spécifié ; chaîne de preuve complète non démontrée | vérifier private buckets, RLS, retention, hash, signed URLs et export |
| Feature flags/admin | architecture envisagée ; exploitation complète non démontrée | vérifier contrôles serveur et audit |
| Edge/connecteurs matériels | non démontrés | concevoir runtime et banc de test ; aucun modèle ne doit être vendu compatible sans recette |

Un package existant, une page de préférence, une maquette ou un document cible n'est pas une preuve d'un service transversal opérationnel. Le contrat API et le droit d'accès de NAXA SECURITY doivent être vérifiés pour chaque service commun.

## 8. Audit du module Android actuel — preuves statiques observées

Dernier contrôle documentaire du dépôt main, effectué le 22 novembre 2026. Les éléments ci-dessous sont des preuves de l'état des fichiers consultés, pas une recette d'exécution.

### 8.1 Fichiers
- apps/naxa-security/README.md : texte court indiquant application autonome et annonce que les documents sources restent à importer après inventaire.
- apps/android/naxa-security/build.gradle.kts : Android/Kotlin/Compose ; dépendances visibles à Compose, core-android, Room runtime/ktx/compiler. Aucune dépendance dédiée caméra/vidéo, ONVIF, RTSP, audio, GPS, capteurs incendie, IA, paiements ou support n'est visible dans ce fichier.
- apps/android/naxa-security/src/main/AndroidManifest.xml : manifeste consulté avec application et activité launcher. Aucune déclaration CAMERA, RECORD_AUDIO, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, INTERNET ou POST_NOTIFICATIONS n'y figure dans le contenu observé.
- apps/android/naxa-security/src/main/java/cm/naxa/naxasecurity/MainActivity.kt : écran Compose de base affichant « NAXA Security » et « Socle natif Famille NAXA — parcours métier à intégrer. » Aucun parcours métier, tableau de bord connecté ou contrôle d'équipement n'est démontré par ce fichier.
- apps/android/naxa-security/src/main/java/cm/naxa/naxasecurity/OfflineQueue.kt : entité Room OfflineEvent et DAO minimal avec enqueue, lecture des événements queued et changement d'état. Ce code seul ne prouve pas synchronisation serveur, chiffrement, signature, politique de retry, conflit, accusé serveur, idempotence réseau ou expiration des commandes.

### 8.2 Conclusion probatoire
- Le socle Android existe, mais le métier SECURITY complet n'est pas démontré.
- Aucun flux vidéo, connecteur ONVIF/RTSP, audio, GPS, détection incendie, intégration centrale, commande distante, IA, gestion multisite, billing connecté, Livecare, notification réelle ou Fulfulde complet n'est démontré par les fichiers inspectés.
- Aucun essai avec une caméra, un NVR, un détecteur ou une centrale physique n'a été exécuté dans cette reprise.
- Aucun build ou test Android n'a été lancé dans cette reprise ; ne pas annoncer « build vert ».
- Le dépôt contient des dossiers de build ; leur seule présence n'est pas une preuve d'une release vérifiée.

**Statut actuel global : NON DÉMONTRÉ / À CONSTRUIRE.** Ce statut n'affirme pas l'absence absolue de tout travail ailleurs dans le dépôt ; il reflète strictement le périmètre de fichiers et preuves examinés.

## 9. Dossier historique et réconciliation documentaire

Le dépôt historique audreymendomo23-netizen/NAXA contient un binaire Cahier_des_charges_09_NAXA_Security.pdf à la racine (main, blob Git 7997b33c11d8136009f04b0382416bfae350e7a3, 69 202 octets). Le connecteur GitHub utilisé a permis de relever son entrée dans l'arbre du dépôt, mais n'a pas restitué le contenu PDF binaire en texte ; le PDF n'a donc pas été relu page par page dans cette reprise.

Action obligatoire avant de considérer la documentation historique comme exhaustivement rapprochée :
1. obtenir le PDF en pièce jointe ou via un moyen de lecture de PDF disponible ;
2. le rendre en images et examiner toutes les pages ;
3. extraire texte, tableaux, notes et annexes ;
4. récupérer les anciens prompts, versions et décisions liés à SECURITY ;
5. faire une matrice : ancienne exigence / page source / reprise dans V1.1 / adaptation / écart / décision ;
6. intégrer tout élément manquant dans une version suivante du cahier et son journal de changements ;
7. conserver le PDF comme source historique, sans prétendre qu'il est obsolète avant comparaison.

Ne pas retarder le cadrage technique déjà approuvé, mais ne pas déclarer la réconciliation historique terminée.

## 10. Dépendances, risques et contrôles

1. Compatibilité réelle : dépend de modèles/firmwares, licences et API des fabricants. Risque d'annoncer trop tôt un support universel.
2. Incendie : risque vital ; les centrales et avertisseurs doivent rester autonomes et contrôlés par des professionnels compétents.
3. Accès distant : risque d'accès non autorisé aux flux et commandes. Imposer MFA, scopes, expiration, anti-rejeu, audit et approbation renforcée.
4. Mode hors connexion : aucun ancien déclenchement distant ne doit être rejoué après reconnexion.
5. Vie privée : vidéo, audio, GPS, présence et biométrie nécessitent finalités, information, base légale, minimisation, durée de conservation, accès tracés et analyse juridique au Cameroun et dans chaque pays.
6. IA : faux positifs et faux négatifs, biais et dérive ; IA complémentaire et non décisionnaire pour sécurité vitale.
7. Services transversaux : risque de supposer Livecare, paiement ou Fulfulde achevés. Auditer avant consommation.
8. Coûts : vidéo Cloud, rétention, bande passante, Edge et inférence IA peuvent rendre les offres non rentables si les quotas ne sont pas calculés.
9. Support : les agents support n'obtiennent pas un accès aux caméras ou GPS par défaut. Accès exceptionnel uniquement temporaire, justifié, consenti et journalisé.

## 11. Ordre de reprise obligatoire

### Lot 0 — clôture documentaire et audit de l'existant
- lire le cahier historique PDF intégralement et ses annexes/prompts ;
- comparer avec V1.1 et publier le registre d'écarts ;
- lister tous les fichiers du module, tests, ressources et configurations ;
- inspecter les paramètres Gradle, settings, dépendances et CI ;
- inventorier les services transversaux réels et leur contrat ;
- vérifier l'état de la branche et les changements non intégrés avant toute édition.

### Lot 1 — architecture détaillée et modèle de sécurité
- context map et diagramme des composants Android/Web/Edge/Cloud ;
- modèle organisation/site/bâtiment/zone/appareil ;
- matrice des rôles et permissions ;
- modèle de données et politique RLS ;
- threat model, secrets, certificats et délégation partenaire ;
- modèle d'événement canonique et machine à états ;
- API versionnées, contrats et stratégie d'idempotence.

### Lot 2 — catalogue et banc de compatibilité
- définir 3 à 5 appareils représentatifs par famille prioritaire ;
- caméra ONVIF, caméra RTSP, NVR, capteur d'intrusion, centrale incendie adressable, détecteur fumée via interface supportée, module I/O, tracker GPS et contrôleur accès ;
- publier la matrice modèle/firmware/fonction ;
- bâtir les tests simulés et physiques ;
- déclarer explicitement les limites de chaque modèle.

### Lot 3 — cœur produit
- authentification et MFA ;
- organisations/sites/zones ;
- RBAC/ABAC et audit serveur ;
- registre des appareils ;
- abonnement et entitlements SECURITY ;
- administration et préférences.

### Lot 4 — NAXA EDGE
- runtime local supporté sur systèmes effectivement testés ;
- découverte et appairage sécurisé ;
- connecteurs/adaptateurs versionnés ;
- événements normalisés ;
- stockage local chiffré, heartbeat, diagnostic ;
- synchronisation et sécurité ;
- fonctionnement autonome pendant la perte Cloud.

### Lot 5 — vidéo, audio, alarmes et commandes
- flux direct et enregistrements ;
- relais vidéo WebRTC ou équivalent ;
- audio et interphonie selon appareils ;
- événements intrusion et alarmes ;
- commandes avec cycle de vie complet et accusé matériel ;
- tests permissions/MFA/expiration/rejeu.

### Lot 6 — fumée et incendie (lot de sécurité critique)
- commencer par la lecture seule et la réception d'événements de centrale ;
- définir adaptateur certifié ou interface du fabricant ;
- valider alimentation, supervision, défaut et alarmes ;
- assurer indépendance de la centrale et des avertisseurs locaux ;
- implémenter les deux workflows et états séparés ;
- tests de perte réseau, Edge, Cloud et alimentation ;
- recette par installateur/technicien compétent ;
- validation du plan de sécurité et procédure d'évacuation par client/professionnel.

### Lot 7 — GPS, présence, rondes, accès, visiteurs et SOS
- permissions OS ;
- collecte et rétention minimales ;
- geofence, pointage, checkpoints ;
- contrôle d'accès selon fabricant et sécurité incendie ;
- SOS et escalade.

### Lot 8 — IA et incidents
- datasets d'essai représentatifs ;
- mesure précision/rappel/faux positifs/faux négatifs ;
- fusion des événements, classement et synthèse ;
- preuve et chaîne de conservation ;
- ne jamais laisser IA inhiber alarmes réglementaires.

### Lot 9 — ERP Professional et modules partagés
- contrats, inventaires, maintenance, interventions, planning, coûts, rapports ;
- Billing Core et paiements réels ;
- notifications ;
- Livecare ;
- stockage/sauvegarde ;
- Français/anglais/Fulfulde avec validation professionnelle ;
- intégrations app-à-app strictement bornées.

### Lot 10 — qualification et livraison
- tests unitaires, intégration, contrats API, SQL/RLS ;
- tests Android/Web/Edge indépendants ;
- vrais modèles matériels sur banc ;
- test de pénétration, restauration, charge, coupures et reprise ;
- recette métier et preuves ;
- version signée, documentation utilisateur/technicien ;
- état final VERT/PARTIEL/BLOQUÉ par domaine, jamais un vert global par simple build.

## 12. Matrice des preuves à produire

| Domaine | Preuve exigée avant statut VERT |
|---|---|
| Android | build reproductible, tests, permission/runtime et parcours validés |
| Web/PWA | build séparé, tests navigateur, droits et flux de supervision |
| Auth/RBAC | tests serveur multi-organisation/site/rôle, révocation et MFA |
| Billing | tests tarifs/renouvellements/quota/expiration et entitlements côté serveur |
| Paiement | transactions sandbox, webhooks vérifiés, idempotence et rapprochement |
| Vidéo | rapports par caméra/modèle/firmware, direct, NVR, playback, panne réseau |
| Audio | essais entrée/sortie, niveaux, interphonie, autorisations et preuve matérielle |
| Fumée | test détecteur/centrale, état, défaut, notification, autonomie locale, retour normal |
| Incendie | scénario complet avec centrale et technicien, alarmes locales, évacuation, pannes, reset autorisé |
| GPS | traces autorisées, perte signal, permission retirée, geofence et rétention |
| Présence/rondes | pointages, anti-rejeu, horaires, checkpoints et mode offline |
| Actions distantes | permission, MFA, expiration, nonce, ACK appareil, échec et audit |
| IA | protocole d'essai, métriques, limites et validation humaine |
| Notifications | reçus réel/échec, canaux et escalade |
| Livecare | chat agent, ticket, transfert, consentement et SLA |
| Fulfulde | couverture complète et validation des textes vocaux/sécurité |
| Stockage/preuves | RLS, URL expirée, intégrité, export et conservation |
| Backup | restauration démontrée et rapport horodaté |
| ERP | recettes des contrats, actifs, intervention, maintenance, coûts et rapports |
| Interopérabilité | contrats testés et aucun partage implicite entre applications |

## 13. Règles de développement et reprise

- Lire les instructions du dépôt avant chaque nouvelle séquence de travail.
- Travailler sur la branche de référence conformément à AGENTS.md ; ne pas créer de branche/PR sans demande explicite.
- Ne jamais committer de secret, donnée personnelle ou exemple client réel.
- Éviter toute modification d'autres applications pour faire passer SECURITY.
- Ne déclarer « terminé » que sur preuves observables et reproductibles.
- Tenir le registre des écarts : attendu / observé / cause / correction / test / preuve / statut.
- Aucun déploiement, publication APK ou changement hors périmètre SECURITY sans décision et autorisation prévues par les règles générales.
- Toute commande à risque doit être testée sur simulateur puis banc physique autorisé.
- Toute commande « envoyée » doit être distinguée d'une commande « reçue » et « exécutée ».
- En cas de doute entre sécurité vitale et automatisation, privilégier l'autonomie du système certifié et le refus sûr.

## 14. État de passation au 22 novembre 2026

| Élément | État |
|---|---|
| Périmètre fonctionnel SECURITY 360° | VALIDÉ [V] dans le cahier v1.1 |
| Trois offres et montants | VALIDÉS [V] |
| Mono-site Essentiel / multisite Business / ERP Professional | VALIDÉ [V] |
| Détecteurs fumée et incendie dans le périmètre | VALIDÉ [V] |
| Deux parcours fumée/incendie de bout en bout | SPÉCIFIÉS ; recette non exécutée [N] |
| Architecture Edge/Cloud hybride | CIBLE [P] ; runtime non démontré |
| Compatibilité multimarque | EXIGENCE [V] ; aucun catalogue matériel certifié démontré |
| Module Android | SOCLE MINIMAL OBSERVÉ ; produit métier non démontré [N] |
| OfflineQueue Room | CODE PARTIEL OBSERVÉ ; sync complète non démontrée [N] |
| Paiements/entitlements live | NON DÉMONTRÉS [N] |
| Livecare humain audio/vidéo | NON DÉMONTRÉ comme service commun prêt [N] |
| Fulfulde complet | NON DÉMONTRÉ [N] |
| Recette sur matériel physique | NON EXÉCUTÉE [N] |
| Relecture PDF historique | BLOQUÉE par récupération du binaire ; action de reprise requise [B] |

**Prochaine action obligatoire :** obtenir et lire le PDF historique, clôturer la matrice d'écarts, puis conduire le Lot 0 avant de construire les fonctionnalités métier ou d'annoncer une compatibilité matérielle.

---

**Fin du document de continuité NAXA SECURITY 360°.**

## Reprise navigation B1–B6
Registre de 181 écrans (25/25/30/33/35/33), cinq onglets et navigation Compose/Web, recherche et retour, liens internes. Voir REGISTRE_ECRANS_B1_B6.md. État : interface de préparation uniquement, aucun parcours métier réel ni authentification, aucune commande matérielle. Recettes de registre ajoutées, compilation et E2E à constater. Palette provisoire, logo officiel ouvert. Aucun autre produit modifié.

## Passe interfaces et backend
181 panneaux de consultation contextualisés / 343 champs; tarifs affichés. Les composants métier sont préparatoires: pas de CRUD ni données réelles, pas de commandes. Recette responsive dédiée run 46076389708 lancée, 181 destinations × 3 largeurs. Projet Supabase FAMILLE-NAXA idupfjbkwjcavyisxteo confirmé par lecture SQL (155 tables publiques, 155 RLS, aucun objet des préfixes sec_, security_, naxa_security_). Contrat SQL candidat six tables, lecture seule authentifiée, affectation explicite site, RLS et tests négatifs, aucune migration de production; aucune identité SECURITY provisionnée. PWA manifest et cache propres, icône NS provisoire non officielle. N0 et B1–B6 PARTIEL. Raccordement métier après autorisation distincte de migration production, recette isolée réussie et provisioning sécurisé. Aucun autre produit modifié.

## Passe métier suivante
Preuves précédentes : jobs Web/Android 46076389708 et 46076501881, SQL 46076501805 : SUCCESS (5/5). Nouveau candidat SQL append-only incidents manuels P2–P4 et ordres de maintenance, périmètre site, rôle, auteur, anti-doublon, aucune commande physique ni écriture client dans les appareils. Adaptateur REST Web préparé pour session SECURITY dédiée ; non raccordé à une session réelle. Recettes SQL élargies. Aucune migration de production, aucune donnée réelle créée. B1–B6 restent PARTIEL.

## Campagne parallèle B1–B6
Révision de départ ec93719 : Android/Web 46077049114 SUCCESS, SQL 46077049211 SUCCESS; gate famille 46077049238 échec E2E/axe et matrice RLS commune. Registre exécutable 543 recettes de navigation (181 destinations × 3 largeurs), 11 lots (10×50 + 43), matrice fail-fast false max-parallel 11 et rapports individuels. Ces recettes ne sont pas des preuves métier. Les workflows SQL et Android restent distincts. Aucun déploiement.

## Développement simultané des six bulks
Contrats métier JS B1 prix, B2 fraîcheur, B3 priorités/états/déclaration, B4 preuve GPS et checkpoints, B5 brouillon de maintenance, B6 délégation en lecture. Kotlin : règles correspondantes partielles. 36 tests unitaires JS en six jobs parallèles. Interfaces interactives calcul tarifaire et brouillons incident/maintenance sur Android et Web (8 destinations), sans persistance ni transmission ; les autres écrans restent à développer. Critères GPS de 100m proposés uniquement pour cette recette et non validés comme seuil métier global. Aucun connecteur matériel ni Auth réelle, aucun déploiement/migration. Tous les bulks restent PARTIEL jusqu'aux preuves E2E.

## Reprise B1 NAXA SERVICES / B4 ZIPPLE
31/31 jobs précédents verts (46077770542, 46077845242, 46077845218, 46077845195, 46077845200). Migration Supabase hébergée 20261127224320 : 7 tables sec_* RLS actives et accès anon refusé, vérifié. B1 : extraction du gestionnaire PIN NAXA SERVICES blob ce6fa14, namespace/Keystore SECURITY; coffre AES-GCM adapté du blob 4bb9082, consentement explicite et liaison membre/org/device. Composants non encore reliés à une authentification serveur. B4 : capture GPS Android issue de ZIPPLE blob 38b208b, permission ponctuelle, timeout 25s, seuil proposé 100m, fraîcheur 120s, refus mock; intégrée aux écrans B4.08 et B4.10. Preuve locale non confirmée, pas de pointage serveur. Aucun module métier étranger. Recettes à relancer. B1–B6 PARTIEL.

## Raccordement Web — reprise suivante
HEAD de départ 111d31e : quatre workflows SECURITY SUCCESS (46078814675, 46078814723, 46078814643, 46078814585), gate famille 46078814692 FAILURE. Base hébergée : 7 tables et 0 membres/0 sites constatés. Ajout d'un parcours Web de session de recette via Auth Supabase (e-mail provisionné, clé publique VITE_SECURITY_PUBLISHABLE_KEY requise), contrôle des sites RLS, expiration en mémoire, déconnexion, consultation sur 12 destinations, soumission incidents/maintenance sur 6 destinations avec identifiant de requête stable. Pas de compte créé, pas de clé privée, pas de persistance des jetons Web. Auth interne définitive modèle NAXA SERVICES et qualification positive hébergée restent à faire. B4 GPS Android non raccordé au serveur; B6/B2 matériels et support non terminés. Tous les bulks PARTIEL. Aucun déploiement ni migration supplémentaire.

## Audit réserves et replay navigateur
HEAD 678ae10 : 19/19 jobs dédiés verts (46079485247, 46079485222, 46079485091); gate global 46079485108 erreur TS7016 domain.mjs et TS2339 ImportMetaEnv SECURITY, corrigées par déclaration .d.mts et typage env; RLS commune reste hors périmètre. Adaptation de NAXA main 4acbab1 workflow naxa-nav-promoteur-e2e.yml : Node 22, Playwright 1.65.1, Chromium, serveur local, refus de requêtes externes via interception navigateur. Nouvelle recette UI avec fixtures SYNTHÉTIQUES (login refusé/accepté, sélection site, lectures B2/B3/B5, soumissions B3/B5, déconnexion). Aucun accès au Replay Supabase NAXA réel, aucun compte de production, aucune preuve de persistance réelle. Correction de réponse tardive de lecture et déconnexion HTTP. B1–B6 PARTIEL. Android GPS et PIN restent non raccordés à une identité serveur; B2/B6 matériels et services nécessitent développement et essais. Aucune migration supplémentaire ni déploiement.

## Correction du gate commun
Sur c900b25, 5 workflows SECURITY verts (46079851603, 46079851679, 46079851620, 46079851601, 46079851643). Gate commun 46079851677 : serveur Playwright historique arrêté prématurément; générateur utilise @famille-kiosko-web au lieu de @famille/kiosko-web. Correction du filtre et activation des logs serveur. Ajout d'un job commun SECURITY Vite sur checkout indépendant non régénéré, 181 destinations x 3 largeurs. Le gate historique Next.js est maintenu et ne constitue pas une preuve SECURITY. RLS commune non modifiée. Recettes nouvelles à constater.

## Reprise gate et contrats métier — 28 novembre 2026
Référence main 2fe794497cafee37133dcc28e3da7fa2f85f426f; run 46080856370 : Vite SECURITY et SQL draft SUCCESS, gate Android et RLS commune FAILURE. Les journaux indiquent le package historique tools introuvable (setup-android v3, packages par défaut tools platform-tools), non une preuve d'indisponibilité de l'API 37. Correctif candidat : packages explicites API 37/build-tools 36.0.0/platform-tools, sans pipe yes redondant. RLS : supprimer uniquement l'insertion de fixture vers family_admins (table absente et non utilisée par is_admin contextualisé), conserver le rôle platform_admin déjà semé et toutes les assertions positives/négatives. Aucune migration de production requise pour ces deux corrections.
Cahier V1.1 rapproché : les 181 écrans et les 543 recettes de navigation ne sont pas une mesure d'achèvement métier. B1 : contrôle local du nombre de sites et affichage, sans inventer les quotas. B2 : état télémétrie vérifiée/fraîche ou inconnu. B3 : présentation lecture seule des états incendie/fumée, acquittement distinct de l'extinction. B4 : brouillon arrivée/départ GPS en attente de validation serveur. B5 : compte-rendu de maintenance et revue autorisée. B6 : délégation en lecture liée au sujet et à la fenêtre temporelle. 24 nouveaux cas de contrat JS (60 au total, à exécuter). Les nouveaux contrats B2–B6 ne sont pas raccordés au matériel ni au serveur ; pas de parité Android revendiquée. Protection de la soumission Web contre les réponses tardives d'un ancien périmètre et les doubles clics en cours de requête ; l'idempotence serveur reste à qualifier, notamment après remontage. Aucune nouvelle migration ou commande matérielle.
Le commit candidat est préparé sans mouvement de main ni création de branche ; CI à relancer sur une référence autorisée. B1–B6 PARTIEL. Le PDF historique demeure non rapproché. Aucun déploiement, publication APK ou autre application modifiée.

### Qualification locale du candidat 9411bd9
Node.js 22.16.0 : les fichiers domain.mjs et domain.test.mjs ont été reproduits localement et leurs SHA Git vérifiés identiques aux blobs du commit (5031016196473bc0fb8edb5d87710004ccf18b7e, ec10f009bc6e48bed6fdb663c3666af70a237792). `node --test docs/naxa-security/contracts/domain.test.mjs` : 60/60 PASS, 0 FAIL ; exécutions filtrées B1=9/9, B2=8/8, B3=14/14, B4=11/11, B5=8/8, B6=10/10. Preuve locale de logique JS uniquement ; aucune qualification CI du candidat, aucune compilation Android/Web supplémentaire ni exécution de la matrice PostgreSQL. Les nouveaux correctifs CI restent à qualifier. Aucun mouvement de branche ni déploiement.

## Reprise active sur branche SECURITY — 28 novembre 2026
Candidat 5a381cb repris sur work/naxa-security-completion-20261128, main laissé intact. Les six workflows SECURITY et gate commun acceptent explicitement la branche; groupe de concurrence du gate isolé par ref. Ajout de la parité Kotlin des six règles avec six tests JUnit, contrôle d'offre Android et filtrage explicite des lectures Web selon le site/organisation sélectionnés. Nouveau contrat PostgreSQL isolé de pointage en attente : identité et site contrôlés par RLS, accès limité à son auteur, fraîcheur 120 s, précision 100 m (seuil de recette à valider), refus simulation déclarée, impossibilité de confirmer côté client, tests positifs/négatifs. Aucune migration hébergée, aucune preuve de GPS authentique ni pointage approuvé. Le client n'appelle pas encore cette table. CI à constater ; pas de vert global. La note précédente de 60/60 locaux n'est pas retenue comme preuve indépendante dans cette reprise : pas de journal local vérifiable disponible, attendre le runner.

## Reprise suivante — gate et raccordement B4
HEAD 74eed1b : workflows 46082477066 (contrats), 46082477097 (SQL dont pointage), 46082477051 (Android/Web), 46082477057 (replay) SUCCESS. Gate 46082477048 : RLS commune, SQL draft et Vite SUCCESS; Android échoue désormais sur le package platforms;android-37 introuvable, après résolution de tools. Six des onze lots 46082477155 déjà SUCCESS au premier contrôle, cinq en cours. Correction candidate : API 36 uniquement dans la génération historique jetable CI, vraie configuration SECURITY (API 35) inchangée, cible API 37 historique non qualifiée. B4 : formulaire de capture ponctuelle Web, envoi sur site de session sous flag VITE_SECURITY_ATTENDANCE_ENABLED (désactivé par défaut), historique personnel; source navigateur et mock_reported null explicites, preuve non vérifiée et jamais confirmée côté client. Deux assertions SQL supplémentaires et replay navigateur synthétique. B3/B5 : récupération de reçu par request_id après erreur POST, vérification de l'auteur, organisation, site et contenu. Aucun déploiement, aucune migration production ni donnée réelle; tests nouveaux à constater. Les contrats B2–B6 incomplets et matériel restent à développer.

## Passe 24 modules rouges — 28 novembre 2026
Départ 6478707 : 4 workflows SUCCESS (lots 543, contrats, Android/Web, replay), SQL FAILURE (délimiteurs DO $ au lieu de $$) et gate historique FAILURE (DSL AGP 9.3.1/Kotlin). RLS commune SUCCESS. Commit fb600b9 : correction délimiteurs SQL, toolchain de prévisualisation API 36/AGP 8.10.1/Kotlin 2.2.0/Gradle 8.11.1, contrôle SHA officielle ; aucun changement du véritable module. Qualification à constater.
Sources auditées : NAXA SERVICES 2f849eb (notification_contract.ts eaacb780, performance-export.ts ea9bb3bd), ZIPPLE f412b83 (SupportGuide.tsx af74dc03), BOOTIK 3313aa2 (domain.mjs 36db1b6), WideMeet 46723ab (MediaPanel.tsx 55374ddd, SupportCenter.tsx cf18caa4), socle assistant et notifications. Adaptation de la validation de périmètre/consentement, revue humaine, export local et demandes idempotentes ; aucune identité ou transport des autres apps repris. 24 parcours Web distincts avec contrats de validation et écrans existants, dont 16 types de demandes persistables (17 modules, vidéo/audio partagent media). SQL candidat sec_module_requests : validation serveur des champs, auteur/site/organisation, rôle renforcé pour admin/backup/payment/partner, état non modifiable. Flag VITE_SECURITY_MODULE_REQUESTS_ENABLED désactivé par défaut. Rapport/Control 360 sur incidents autorisés du site, 100 lignes max ; audit limité aux demandes personnelles ; empreinte de fichier SHA-256 locale. Pas de flux vidéo/audio matériel, de commandes, paiement, SOS réel, IA vision, transport notifications/livecare, sauvegarde réelle ni traduction complète. Aucun raccordement Android de ces 24 parcours, aucun déploiement ou migration hébergée. 75 tests JS supplémentaires (69 tests par module, 6 cas ciblés), SQL positives/négatives. Tous ces modules restent PARTIEL/à qualifier ; une demande ne constitue pas la fonction finale. Réévaluer l'audit 10,7% après qualification, pas de progression automatique.

### Consolidation Android et cycle de revue
Sur 7839d39, les six jobs de contrats métier (46083886958) et le SQL isolé (46083886946) sont SUCCESS. Ajout des 24 validations natives Kotlin (3 vues de lecture indiquent explicitement non raccordées, 21 formulaires/calculs locaux), tests JUnit, file de revue Web et suivi personnel, deux RPC SQL isolées avec rôle manager/owner et affectation site active, refus de l'auto-revue et des dossiers privés, contrôle du motif, idempotence et impossibilité de modifier directement l'état. Revue administrative seulement : aucun ordre matériel, paiement, habilitation, SOS ou transfert de données. Les nouvelles recettes sont à qualifier. Aucune migration hébergée ni déploiement ; les 24 modules ne sont pas terminés.

### Correction de non-régression des parcours
Le run de navigation 46083886976 et le gate Web 46083886983 sur 7839d39 ont échoué après ajout des parcours, dont collision de titres exacts (Langues). Correction du sous-titre des formulaires et protection de largeur des contrôles. Les critères des recettes n'ont pas été modifiés. Requalification en cours. Les contrats métier 46083886958, SQL 46083886946 et replay Chromium 46083887103 sont SUCCESS sur 7839d39 ; la nouvelle revue et la parité native sur 8568dd4 ne sont pas assimilées à ces résultats antérieurs.

## Exécution métier — consolidation du 28 novembre 2026
Référence 611ee7a : contrats 135 et lots 543 SUCCESS (46084076190, 46084076181), replay 46084076229 SUCCESS, Web du gate 46084076303 SUCCESS ; Android échoue sur Maven HTTP 429 JUnit/Hamcrest (pas d'erreur Kotlin démontrée). SQL de la revue 46084023548 SUCCESS sur 8568dd4. Gate historique 46084076209 : wrapper Gradle généré avec succès mais étape de vérification échoue ; RLS commune/Vite/SQL draft verts. Ajout de retries bornés exclusivement sur Maven 429 au gate Android réel.
Nouveau candidat SQL service-execution : effets transactionnels à l'insertion/revue d'une demande : préférences personnelles persistées (locale/canaux), incident P2 de déclaration humaine (pas d'alarme physique), message initial support + ajouts du demandeur, boîte de réception interne avec acquittement serveur et registre des dossiers examinés visiteurs/véhicules/affectations/compatibilité/partenaires. Registre ne donne aucun droit physique. Tables de reçus fournisseur et d'observations protégées en écriture client ; ingestion authentifiée et appareils réels non raccordés. Nouveaux écrans de lecture et suivi Web sur 14 destinations, tests SQL positifs, isolation site/acteur et refus privilèges. Aucune migration hébergée, aucun transport FCM/Livecare, aucun paiement initié, aucune traduction intégrale, aucun accès caméra/Edge réel, aucune sauvegarde production. Qualification nouvelle à constater ; les 24 modules ne sont pas entièrement achevés.

### Intégrations et fonctions complémentaires
Ajout d'une frontière de lecture média à autorisation personnelle courte et origine HTTPS configurée (aucun connecteur ni flux physique fourni), vue SQL de rapprochement exact sur reçus de confiance (aucune initiation de paiement), analyse explicable de télémétrie récente et export/vérification d'instantané de synthèse sans modification serveur. Contrats JS ciblés B1/B2/B3/B6, SQL isolé, replay de préférence sur données synthétiques. Ces capacités ne remplacent pas l'intégration fournisseur, ONVIF/RTSP/EDGE, l'IA vidéo, la restauration de base ou la qualification sur matériel. Aucune migration production. 

### Raccordement Android de recette
Ajout du client HTTP natif à domaine fixe Supabase SECURITY, clé publishable configurable à la compilation (-PsecurityPublishableKey=...), absence de clé par défaut, session mémoire avec expiration et déconnexion, choix de site autorisé, payloads typés et vérification du reçu (17 parcours persistables), consultation des trois parcours overview/report/audit. Pas de secret/service_role, pas de transport matériel, aucune identité réutilisée des autres applications. L'authentification reste la recette e-mail provisionnée et non le modèle final internalisé ; aucun compte réel utilisé. Nouveaux tests JUnit de contrat et qualification Android à constater. 

## Jauge de maturité fonctionnelle — audit de clôture de la passe
Barème inchangé : 35 modules équipondérés, 0 interface seule, 25 composants/règles, 50 raccordement partiel, 75 complet et qualifié hors production, 100 complet qualifié de bout en bout. Référence précédente 29,3% (29 orange et 6 jaunes). Sur la base des effets transactionnels SQL qualifiés sur 2b3a63a (46084587744) et frontière SQL/intégrations qualifiée sur c753440 (46084676511), et des contrats JS c753440 (46084676486), reclasser à 50% les neuf modules NS-08 (incident humain), NS-13 (registre visites), NS-14 (registre véhicules), NS-19 (registre des dossiers compatibilité, non certification), NS-21 (registre d'affectation), NS-24 (rapprochement exact non allocation unique), NS-25 (conversation demandeur, sans agent), NS-26 (boîte interne et préférences), NS-35 (registre partenaire). Les six jaunes préexistants : NS-01,05,16,17,20,22. Total : 15 jaunes, 20 orange, aucun bleu/vert; (15*50+20*25)/35=35,714%, arrondi 35,7%. Gain 6,4 points. Ne pas reclasser les autres modules uniquement sur leurs demandes, préférences, contrats ou UI. Android natif nouveau raccordement e15bcf5 à qualifier; ne pas comptabiliser cette modification comme preuve réelle. 139 contrats JS recensés et 543 navigations déjà vertes sur 2b3a63a (135 contrats sur cette révision, puis 139 sur c753440); nouveau HEAD à requalifier. Backend et recettes sont isolés, pas de preuve hébergée ou matérielle. Run 46084587796 Android/Web SUCCESS sur 2b3a63a; SQL et replay de cette révision SUCCESS. Le gate historique reste non qualifié, épinglage du SHA-256 officiel Gradle 8.11.1 (https://gradle.org/release-checksums/) après l'étape wrapper, sans désactiver vérification. Correction conversion des nombres entiers saisis au format décimal dans payload Android. Restent en particulier : identités internalisées et auth réelle, équipements ONVIF/RTSP/EDGE, contrôle physique et sécurité opérationnelle, IA audio/vidéo, flux de paiements fournisseur/rapprochement avec allocation non dupliquée, support agent et média, push externes, traductions intégrales, stockage/sauvegarde/restauration réelle, qualification de bout en bout et mise en production. Aucune modification main, aucune migration hébergée et aucun déploiement.

### Non-régression du replay
Sur c753440 : 46084676497 Android/Web SUCCESS, 46084676513 lots 543 SUCCESS, SQL et contrats SUCCESS. Replay 46084676506 : les huit scénarios antérieurs passent, timeout sélecteur Langue du nouveau scénario ; libellés accessibles explicites ajoutés aux champs des parcours. Aucune assertion supprimée ; attendre la nouvelle qualification. La jauge 35,7% demeure une estimation de maturité et non une qualification intégrale.

## Passe transversale à rendement élevé — opérations terrain (28 novembre 2026)
Départ 90312b1 : contracts 46084848453, Android/Web 46084848438 et replay 46084848562 SUCCESS ; lots 543 à confirmer sur ce SHA, précédemment verts sur 29a111e. Choix : renforcer le cycle opérationnel plutôt que multiplier des interfaces. Candidat SQL terrain : machine d'états incidents P2–P4 (P1 exclu), maintenance, revue humaine de pointage (ne certifie pas la position), création/affectation/rondes/checkpoints déclaratifs séquentiels avec revue distincte, journal de passages visiteurs/véhicules sans commande physique, signalement interne de sécurité avec accusé et clôture, journal immuable et reçus idempotents. Contrôle organisation/site/rôle actif, aucune mutation directe client, verrouillage transactionnel. Web raccordé sur 17 destinations, flag VITE_SECURITY_FIELD_ENABLED désactivé par défaut. Recettes SQL positives/négatives ajoutées. Aucun secours externe alerté, aucun contrôle physique, aucune validation GPS automatique, aucune migration hébergée. Nouvelle jauge à recalculer après preuve de qualification : référence 35,7%, ne pas compter les nouveaux parcours comme des modules complets.

### Synchronisation à faible risque
Réemploi du principe de l'outbox ZIPPLE (file IndexedDB, scope organisation/site/acteur, reçu exact), limité aux préférences de langue et de canal. File persistante après navigation/rechargement, blocage des valeurs contradictoires, reprise explicite après reconnexion, suppression seulement après reçu confirmé. Aucun mot de passe, jeton, position, preuve, paiement ou commande stocké. Quatre contrats JS et un scénario Chromium de persistance/confirmation synthétique ajoutés. Ordre des passages stabilisé par séquence SQL même dans une même transaction. Flag field activé en recette uniquement ; pas de migration hébergée.

### Ingestion EDGE et télémétrie de confiance
Candidat SQL avec rôle isolé sec_gateway_ingest (aucun droit client), affectation passerelle/appareil/site, validation des observations, déduplication par événement, refus de rejeu contradictoire, fraîcheur et signalement des anomalies de seuil configuré ou état appareil. Avertissements historisés distincts des alarmes certifiées, aucun ordre matériel ni secours déclenché. Contrat de transport Node HMAC-SHA256 avec secret externe, contrôle de périmètre et reçu serveur, trois tests JS. Ecran de lecture des avertissements B3.03. Recettes SQL incluant révocation passerelle, isolement, données obsolètes et faux reçu. Le rôle n'est créé qu'en base jetable CI ; le transport de production, les connecteurs ONVIF/RTSP, le provisionnement sécurisé réel et la qualification sur appareils restent à faire. Aucune migration hébergée.

### Correctifs et vérification intermédiaire
SQL terrain initial 46085203104 : erreur de syntaxe CASE dans la validation checkpoint ; correction 9f03ff2, SQL intégral 46085276643 SUCCESS, six lots JS 46085276587 SUCCESS. Web 9f03ff2 : accolade excédentaire PreferenceOutbox.tsx détectée par esbuild/TypeScript ; correction intégrée sans modification des assertions. Les recettes de navigation, replay et gate Web de ce SHA restent FAIL historiquement ; nouvelle qualification nécessaire.

## Jauge de clôture — passe terrain et EDGE
Référence initiale 35,7% : 15 jaunes, 20 orange. Barème inchangé, 35 modules équipondérés, 25% règles/composants, 50% raccordement partiel, 75% module complet qualifié isolément, 100% complet de bout en bout. Sur preuves SQL 46085276643 (terrain) et 46085376528 (terrain + EDGE) SUCCESS, et JS 46085376632 SUCCESS, six modules passent de 25% à 50% : NS-06 rondes manuelles, NS-07 journal des accès déclarés, NS-12 mesures/avertissements, NS-15 signalement interne avec acquittement, NS-18 ingestion candidate de télémétrie, NS-30 journal des actions. Les 15 jaunes antérieurs restent jaunes (NS-01,05,08,13,14,16,17,19,20,21,22,24,25,26,35). Total 21 jaunes / 14 orange, 0 vert ou bleu ; (21*50+14*25)/35 = 40,0%, +4,3 points. NS-32 file de préférences reste orange jusqu'au replay navigateur concluant. NS-10 et NS-27 restent orange : seuils/observations ne constituent pas une IA complète. Raccordements partiels isolés, aucun équipement/serveur hébergé qualifié. 146 contrats JS recensés (+7), 543 recettes de navigation précédemment PASS 46085203132 sur 3bd3822 ; nouvelles recettes sur 215b67b : UI 46085414471, business 46085414527, lots 46085414501, replay 46085414545, gate commun 46085414505, résultats non encore acquis au moment de cette note. SQL inchangé depuis 3f43517. 4 commits de construction/correction avant cette note. Aucun changement main, aucun déploiement ni migration hébergée. Priorités restantes : raccordement réel gateway/transport et appareils, preuves QR/NFC/GPS et Android des nouveaux cycles, rôles et sessions définitifs, workflow support agents, médias réels, paiement fournisseur, langues, sauvegarde, notifications externes, qualification produit.

## Passe cible 50% — services de confiance
Référence 0c8106d : UI 46085414471, lots 543 46085414501, replay 46085414545, contrats 46085414527 SUCCESS ; SQL terrain/EDGE 46085376528 SUCCESS. Reclasser NS-32 à 50% (file de préférences testée, pas offline global). Nouveau candidat : affectation/révocation site par propriétaire sans élévation de rôle, allocation unique d'un reçu fournisseur exact et abonnement site, stockage personnel de petits fichiers (256 Kio, SHA-256 serveur et lecture vérifiée), sauvegarde/restauration serveur des préférences personnelles et consultation/révocation des liaisons gateway. Interfaces Web sous flag VITE_SECURITY_TRUST_ENABLED désactivé par défaut. Tests SQL positifs/négatifs. Aucun fournisseur, stockage production ou gestion globale des abonnements raccordés. Ne pas assimiler à une finalisation de ces modules. Aucune migration hébergée.

### Sources incendie et géolocalisation déclarative
Candidat : événements fumée/incendie append-only provenant du rôle gateway et d'un appareil lié, conservation stricte de l'état source et refus de rejeu contradictoire, accusé individuel idempotent sans reset/silence/commande. Géopérimètres configurés par responsable, évaluation Haversine des positions de pointage avec marge d'incertitude, sans suivi continu ni position authentifiée. Interfaces Web sous flag TRUST, scénarios SQL positifs/négatifs. Correction BuildConfig dans le générateur historique pour SECURITY seulement (clé vide de recette), gate précédent 46085414505 échec référence BuildConfig, trois autres jobs PASS. Aucun raccordement matériel ni migration hébergée.

### Langues et médias
Traduction anglaise de la navigation Web des 181 écrans et cinq onglets, changement effectif FR/EN, repli français explicite pour le Fulfulde non validé ; formulaires métier restent français. Deux contrats JS et replay Chromium. Candidat d'émission de grants vidéo/audio par rôle serveur dédié après revue distincte de la demande, vérification appareil/site/membre, origine configurée, expiration et contrôle de révocation côté transport. Tests SQL des deux médias, refus sans revue, contrôle après révocation. Aucun flux réel ni transport média hébergé. Aucun contrôle PTZ/interphonie exécuté. Jauge à recalculer sur résultats.

### Diagnostic distant et aide décisionnelle
Diagnostic de santé en lecture seule : demande courte, autorisation distincte, confirmation uniquement via observation récente ingérée par passerelle associée, idempotence et refus du client. Aucun ordre d'ouverture, PTZ, alarme ou désactivation. Vue de corrélation temporelle incendie/télémétrie préservant les états sources, assistant déterministe produisant synthèse, recommandations et références aux données autorisées, sans inférence vision/audio/LLM, sans décision automatique. Recettes SQL et 2 contrats JS ; interfaces Web sous flag TRUST. Pas de transport matériel opérationnel ni de migration hébergée. Reclasser uniquement après qualification.

## Jauge de clôture — objectif 50% (28 novembre 2026)
Barème identique aux précédentes passes : 35 modules équipondérés, 0/25/50/75/100% selon niveau de construction, raccordement partiel, qualification isolée complète et qualification intégrale. Départ 40% (21 jaunes, 14 orange). Reclassification des 14 modules orange au niveau 50%, uniquement pour leurs sous-fonctions raccordées et qualifiées en environnement isolé, et non pour l'intégralité des modules :
- NS-32 file de préférences : replay 46085414545 PASS, 215b67b.
- NS-23 abonnement site avec reçu alloué une seule fois ; NS-29 affectation et révocation de site sans élévation de rôle ; NS-31 stockage et restitution personnels de fichiers 256 Kio avec SHA-256 serveur ; NS-33 inventaire/révocation des liaisons EDGE ; NS-34 sauvegarde et restauration des préférences : SQL 46085943638 PASS, d33d9c4 ; gate Android/Web 46085943649 PASS. Pas de paiement initié, stockage hébergé, sauvegarde complète ou quotas globaux.
- NS-04 GPS déclaratif (géopérimètre et incertitude) ; NS-11 événements sources incendie et accusé individuel sans action : SQL 46086054656 PASS, b4dccce. Gate Android/Web 46086054691 et navigation 46086054629 PASS. Pas de surveillance permanente ni centrale réelle.
- NS-02 vidéo et NS-03 audio : cycle d'autorisation par revue, rôle serveur émetteur, appareil associé, origine autorisée, validité et contrôle de révocation ; SQL 46086161689 PASS, a140351. Pas de flux réel ni passerelle de lecture en production. NS-28 navigation FR/EN de 181 titres et 5 onglets, contrats 46086161760 et replay 46086161696 PASS. Fulfulde et formulaires non traduits intégralement.
- NS-09 diagnostic distant en lecture seule avec autorisation distincte et observation de gateway confirmée ; NS-10 corrélation temporelle de sources, sans modèle vision/audio ; NS-27 assistant de synthèse et recommandations déterministes sur données de site, sans LLM : SQL 46086264888 et six jobs contrats métier 46086264823 SUCCESS sur 6f6daf5. Aucun ordre physique ni conclusion automatique de sûreté.
Bilan : 35 jaunes, 0 orange, 0 rouge, 0 bleu, 0 vert intégral ; (35*50)/35 = 50,0% de maturité estimée, +10,0 points. Cette jauge mesure la couverture de sous-fonctions métier et non la moitié des recettes E2E complètes, du temps ou des coûts. Aucun module n'est intégralement qualifié. 150 contrats JS recensés (+4), SQL complet jetable et six lots JS verts sur 6f6daf5. Recettes de compilation, navigation, replay et gate commun de ce dernier commit encore en cours au moment du constat ; les interfaces TRUST ne sont pas couvertes intégralement par le replay existant. Reste principal : auth définitive, intégrations hébergées et matérielles, contrôles opérationnels certifiés, transport et diffusion média, modèles IA, support agents, paiements réels, notification externe, traduction métier/fulfulde, parité Android des nouveaux parcours, stockage/sauvegarde complète, E2E réel. Aucune migration hébergée, aucun merge main, aucun déploiement. Quatre commits de développement et un commit d'audit sur la branche dédiée.

## Passe cible 65% — finalisation de parcours logiciels
Départ d3b6b7b : SQL, JS, replay, 543 navigation verts sur 6f6daf5 ; gate Android dédié échoue sur Maven 429 JUnit/Hamcrest malgré retries ; gate historique échoue en compilation NAXA SERVICES/ZIPPLE, hors périmètre. Livecare : agent explicitement provisionné par site, prise en charge, conversation privée, escalade, échéance de recette (24h/4h), résolution/réouverture/clôture et satisfaction, reçus idempotents, refus manager non habilité et accès direct. Web sous flag TRUST, assertions SQL. Pas de chatbot, média, SLA contractuel ou déploiement. Ne pas reclasser NS-25 à 75% sans la totalité des exigences et la qualification des parcours.

### Qualification navigateur + PostgreSQL réel (jetable)
Ajout d'un replay Livecare UI Chromium → adaptateur REST de recette strict → PostgreSQL réel avec rôle authenticated et auth.uid fixture. Huit écritures métier, personas distinctes, conversation, affectation, escalade, résolution, réouverture, clôture/satisfaction et refus inter-site. L'adaptateur n'est pas PostgREST ni un service de production ; aucune authentification réelle, aucun trafic externe. Résultat à constater sur runner SQL étendu.

Correctif recette Livecare : 46087565478 a détecté une faute END IF au lieu de END dans le bloc exception du test négatif manager ; correction sans retirer le test. Requalification SQL + navigateur réel déclenchée.

### Dossiers incidents et reporting serveur
Dossier détaillé avec responsable de site, transitions attente information/tiers, notes/diagnostic, référence de preuve personnelle, clôture motivée, réouverture, journal et reçu idempotent. Contrôle serveur de l'affectation et de la clôture ; états critiques non commandés. Rapport serveur par site et période (incidents, présence, rondes, ordres de travail, passages, alertes, incendie, appareils, audit) sans limite artificielle de 100 lignes ; droits manager/owner, export CSV existant avec protection formule, tests de 111 incidents. Interfaces Web sous TRUST. Reste le traitement P1 certifié, partage de preuves, parité native et qualification complète.

### Raccordement Android natif
API native autorisée pour lecture des dossiers/notes Livecare et incidents, RPC à reçus contrôlés, rapports calculés côté serveur et export CSV via sélecteur Android. Compose connecté aux écrans des deux cycles et rapports. Pointage GPS natif raccordé à sec_attendance_drafts sur actions arrivée/départ (pauses non prises en charge par le contrat actuel), vérification fraîcheur, précision, source mock, reçu complet et périmètre. Aucune trace GPS continue. Les nouvelles fonctions Android restent à qualifier ; pas de preuve émulateur avec backend réel à ce stade.

### Reporting multisite et recette réelle
Rapport organisation par RPC invoker, agrégation des sites explicitement autorisés au manager/propriétaire, liste des sources et totaux, export CSV aplati dans Web et Android, contrôles de périmètre côté clients. Nouveau scénario Chromium/PostgreSQL vérifie la récupération des 110 incidents sans troncature, exclusion du site non autorisé, et calcul multisite. Le test navigateur n'utilise ni authentification hébergée ni PostgREST réel. Qualification à constater.

### Recette dossier incident de bout en bout
Extension du même adaptateur local à la création et aux transitions du dossier (client, responsable, assignation, attente, reprise, résolution et clôture, huit notes réellement persistées). Tri des dossiers et notes par dates pour éviter qu'une nouvelle entrée soit invisible derrière 100 anciennes ; liaison de preuve native. Recette cible 110 incidents préexistants puis nouveau dossier. Toujours aucune preuve d'usage production ou d'émulateur Android connecté.

## Bilan de clôture — cible 65% (28 novembre 2026)
Sept commits de code/recette sur la branche dédiée avant cette note : 067e045, 7e7172d, d5713b8, b7fda06, 5dc51ab, 96f8e6f, 95a51f1. Preuves : 46087647440 (d5713b8) SUCCESS SQL + Chromium/PostgreSQL, log PASS 8 écritures Livecare persistées et refus intersite ; 46087748505 (b7fda06) SUCCESS SQL complet incluant cycle incident et rapport 111 lignes, puis replay Livecare ; 46087748502 (b7fda06) SUCCESS compilation Android/Web ; 46087748623 et 46087748517 SUCCESS contrats et replay standard. Le défaut Maven 429 précédent n'a pas empêché ces gates antérieurs de réussir ; le gate historique inter-apps reste hors périmètre. Sur 96f8e6f, replay standard 46087888137 SUCCESS, rapport multisite et dernier Android encore en qualification au constat. Sur 95a51f1, nouveaux runs 46087969020 (SQL/replay réel), 46087968999 (Android/Web), 46087969012 (replay standard), 46087969019 (navigation), 46087969021 (contrats), 46087969074 (gate commun), non terminés au constat.
Maturité stricte : 50,0% (35 jaunes, aucun module complet isolé à 75%, aucun vert intégral). Progrès réel à l'intérieur du palier de 50% pour NS-05 présence, NS-16 incidents, NS-17 supervision, NS-22 reporting, NS-25 Livecare et NS-30 audit ; ne pas reclasser sur une seule sous-fonction. La cible 65% implique 21 modules sur 35 passant de 50% à 75% à barème constant. Ce seuil n'est pas atteint. Les principaux écarts des six modules renforcés : parcours matériels/QR/NFC/horaires pour présence, P1 et partage des preuves pour incidents, supervision complète et temps réel, qualification Android et rapports de toutes les sources pour reporting, média/FAQ/chatbot/transfert/partage d'écran pour Livecare, journal unifié des accès et consultations pour audit. Les autres 29 modules restent à terminer. Aucune modification de main, migration hébergée ni déploiement ; l'adaptateur E2E est strictement un banc de recette local, non PostgREST ni auth hébergée. Le changement de méthode n'est pas un changement de barème : ne pas déclarer 65% sans preuves.

## Passe cible 70% — ERP et opérations
Relance des cinq workflows SECURITY sur 33b17b5. Le précédent 95a51f1 est vert sur les cinq, y compris Livecare 8 écritures, reporting 110 lignes et cycle incident 8 notes dans Chromium/PostgreSQL ; gate commun échec hors SECURITY. Nouveau lot : vacations datées avec contrôle de chevauchement par agent et organisation, acceptation/annulation/fin déclarative, maintenance appareil/technicien/date, diagnostic/coût et revue distincte avant clôture, journal et reçu idempotent. Web 10 destinations sous TRUST. SQL assertions positives/négatives, pas de paie, preuve de présence ou certification appareil. Aucun déploiement.

### Codes de contrôle visiteurs/véhicules
Code aléatoire à usage unique, empreinte privée, émission par responsable après examen, validité plafonnée par le dossier, révocation, reçu idempotent, contrôle intersite. Web sous TRUST. Contrôle manuel uniquement : ni QR graphique, ni ouverture, ni enregistrement automatique d'entrée/sortie ; le journal de passages existant est distinct. Assertions SQL de rejeu et révocation. Aucun matériel ou migration hébergée.

### Recettes ERP et codes temporaires sur base réelle de recette
Extension du replay Chromium/PostgreSQL aux vacations (création, conflit, acceptation), maintenance (affectation, démarrage, coût et diagnostic, revue distincte), code visite (émission, consommation et refus de rejeu). Fixtures synthétiques, aucun équipement ni donnée réelle. Nouveaux tests à qualifier. Vague de relance initiale 33b17b5 : cinq workflows SUCCESS (46089794631, 46089794646, 46089794649, 46089794655, 46089794616). SQL ERP sur 0ee94a9 : étape psql SUCCESS.

### Durcissement du parcours maintenance
Suppression des anciennes transitions Web de maintenance, garde SQL obligatoire sur affectation détaillée, démarrage par technicien et revue avant clôture, y compris via l’ancien RPC. Deux refus supplémentaires en assertions. Ne pas assimiler une clôture de dossier à une certification d’équipement.

## Bilan de la vague cible 70% — 28 novembre 2026
Relance globale 33b17b5 : 5/5 workflows SECURITY SUCCESS (contrats B1-B6 46089794646, 543 navigation 46089794655, SQL et Chromium/PostgreSQL 46089794631, replay standard 46089794649, Android/Web 46089794616). Le commit précédent 95a51f1 est également entièrement vert sur ces cinq workflows ; log réel 46087969020 : huit écritures Livecare, 110 lignes reporting et agrégation multisite autorisée, dossier incident de bout en bout et huit notes. Gate commun inter-apps : échec précédent hors SECURITY, non compté comme vert ; aucune modification des autres applications.
Développement ERP 0ee94a9 : cinq workflows SUCCESS (SQL 46089879848, UI 46089879821, contrats 46089879805, navigation 46089879802, replay 46089879786). Le code visiteur/véhicule 0787f50 a franchi l'étape psql du runner 46089957484 et le build Web, ainsi que contrats 46089957377 et replay standard 46089957423. Le runner DB de ce commit poursuit son replay. Recettes Chromium réelles ERP et visites introduites sur a34e32c, 46090023352 en attente au constat. Durcissement maintenance d63c276 : nouveaux workflows 46090060912 SQL, 46090060934 UI, 46090060896 contrats, 46090060907 navigation, 46090060909 replay, 46090060900 gate historique ; en cours ou en file au moment du constat. La nouvelle recette étendue n'est pas encore déclarée PASS.
Bilan strict inchangé : 50,0% (35 jaunes, 0 module complet qualifié isolément à 75%, 0 vert intégral). Modules renforcés notamment NS-05, NS-07, NS-13, NS-14, NS-20, NS-21 et NS-30. La qualification de parcours logiciels partiels ne suffit pas à déclarer la totalité du module. Objectif 70% = 28 modules de 50 à 75% (ou une combinaison équivalente) à barème constant. Les nouveaux travaux restent à compléter : ERP contrats, équipes, remplacements, coûts et autres flux ; maintenance garanties, inventaire, pièces, équipement réel ; accès matériel, QR, registre intégral, Android des nouveaux parcours ; audit unifié ; plus les réserves précédentes. 5 commits de relance/développement/recettes/correction puis cette note. Aucune migration hébergée, aucun merge main, aucun déploiement. Maintien du barème et des preuves.

## Passe corrective et parité terrain Android
Les logs du runner 46090060912 (d63c276) confirment PASS des cinq scénarios Chromium/PostgreSQL : Livecare, reporting, incidents, vacations/maintenance, code visiteur à usage unique. 46090060934 Android/Web PASS. Gate historique 46087969074 : erreurs Kotlin NAXA SERVICES et ZIPPLE (BuildConfig et dépendances), aucune erreur SECURITY identifiée ; ne pas modifier les autres projets. Ajout Compose natif pour revue de pointage, rondes, passages déclarés, signalement interne, vacations, affectation et revue maintenance ; RPC et reçus vérifiés par périmètre, trois tests unitaires de choix d'action. Les rôles restent contrôlés par le serveur. Pas d'émulateur connecté, ni de matériel. Qualification à constater.

### Journal transversal
Vue PostgreSQL security_invoker réunissant opérations terrain, services, ERP, support et accusés incendie, projection sans corps de message, détail, code ou empreinte ; RLS sources préservée. Web : lecture filtrée et export CSV des 100 derniers événements autorisés ; Android : consultation. Assertions droits personnels, intersite, refus anonyme et absence de payload. Pas encore journal de toutes les consultations/connexions ni conservation certifiée. Qualification en cours.

### Bilan de la passe corrective
Sur d63c276 : les cinq workflows SECURITY sont SUCCESS (46090060896, 46090060907, 46090060909, 46090060912, 46090060934). Les logs SQL/E2E prouvent les cinq parcours réels de recette, dont maintenance à revue obligatoire et code visiteur à usage unique. Le dernier gate commun sur ce SHA a été annulé par une révision suivante ; son échec précédent 46087969074 relève des compilations NAXA SERVICES et ZIPPLE et reste hors périmètre. ba56fd0 ajoute les opérations terrain Android et trois tests unitaires ; contrats 46090360893 SUCCESS, Android/Web 46090360830 encore en cours au constat. 229c891 ajoute le journal transversal ; SQL 46090414241, Android/Web 46090414269, replay 46090414208, navigation 46090414216 et contrats 46090414253 relancés. Extension du replay DB à la consultation du journal par deux comptes, absence du secret du code et isolation intersite. Aucun nouveau résultat PASS anticipé. Jauge stricte 50% : 35 modules à couverture partielle ; pas de reclassification globale sans qualification complète. Aucun merge main, déploiement ni migration hébergée. Prochaine priorité : achever les parcours natifs, la gestion des habilitations et la qualification complète des modules logiciels.

## Passe de finalisation — notifications et rondes
HEAD précédent ea57636 : cinq workflows SECURITY SUCCESS (46090483733, 46090483726, 46090483846, 46090483759, 46090483741). Nouveau lot : notifications internes persistantes générées par événements support, vacation, signalement interne et sources incendie/télémétrie, destinataires actifs et limités au site, aucune donnée privée dans le message, déduplication, lecture idempotente et écrans Web/Android. Assertions SQL et replay Chromium/PostgreSQL de la notification de vacation et du cycle de ronde manuelle avec refus du checkpoint hors séquence. Les canaux externes et preuves QR/NFC/BLE/GPS restent non qualifiés ; aucune commande ni diffusion externe. Le gate inter-apps n'est pas un échec SECURITY. Jauge stricte 50% maintenue tant que les modules complets ne sont pas qualifiés.

### Réponse client Livecare unifiée
RPC de réponse client avec reçu idempotent et notification de l’agent affecté, reprise de l’état assigned après attente client, contrôle de la clôture et du périmètre. Web/Compose natif ; remplacement du test de réponse brute par RPC rejoué deux fois, replay étendu à neuf écritures et trois messages. Correction préventive de l’ambiguïté PL/pgSQL du conflit source_id dans le déclencheur notifications. Aucune extension de droits ni suppression d'assertion.

### Clôture de passe et réserves
Échec 46090811502 sur d5379ee confirmé par log PostgreSQL : ambiguïté de colonne source_id dans le conflit du trigger activity_notify. Correctif 39cd316 : ON CONFLICT DO NOTHING, contrainte unique inchangée, plus réponse client Livecare. Le runner 46090871691 a désormais passé l'étape psql intégrale, y compris les assertions de notification et de réponse client ; son replay Chromium/PostgreSQL étendu n'est pas encore terminé. Web d5379ee 46090811493 job 140811031870 SUCCESS, contrats 46090811489 SUCCESS. Nouvelle vague 39cd316 : 46090871678 Android/Web, 46090871736 contrats, 46090871670 navigation, 46090871677 replay, 46090871691 SQL/E2E ; résultats finaux encore attendus au constat. Jauge stricte 50,0% inchangée. NS-06 : ronde manuelle, pas preuves physiques QR/NFC/BLE/GPS ni totalité des fonctions du chapitre 10. NS-25 : conversation bidirectionnelle, pas média, chatbot/FAQ et pièces jointes complets. NS-26 : notifications internes, pas livraison externe FCM/SMS/WhatsApp/e-mail. Ces trois modules renforcés restent jaunes ; 32 autres modules à terminer. Gate commun : révision précédente annulée, dernier échec historique hors SECURITY non corrigé dans ce périmètre. Aucun merge main, migration hébergée ni déploiement. Deux commits de code et cette note.


## Passe cible 80% — rapprochement du cahier v1.1 et notifications externes (28 novembre 2026)

Reprise sur d7bf54c, branche dédiée exclusivement. Les cinq workflows sur 39cd316 sont désormais SUCCESS : SQL/E2E 46090871691, Android/Web 46090871678, contrats B1–B6 46090871736, navigation 46090871670, replay 46090871677. Ceci valide les parcours existants, pas les modules intégralement.

Audit documentaire du cahier v1.1 (35 modules, sections 5–23, 28.5 et 31) rapproché des preuves précédentes de continuité. Registre synthétique des réserves dominantes à fermer ; il ne constitue pas une inspection exhaustive de chaque fichier ni une acceptation des risques :
| Module | Réserve dominante / preuve de sortie |
|---|---|
| NS-01 Core | Auth réelle, révocation session, MFA et matrice complète des droits |
| NS-02 Video | Flux sécurisé local/distant, lecture, recherche et export sur modèles testés |
| NS-03 Audio | Interphonie et audio autorisés, transport et matériel réels |
| NS-04 GPS | Sources réelles, consentement, cartographie et géopérimètres qualifiés |
| NS-05 Presence | QR/NFC, horaires, pauses, exceptions, parité native et terminal |
| NS-06 Patrol | QR/NFC/BLE/GPS, fenêtres, remplaçant, anomalies, preuves et rapport signé |
| NS-07 Access | Contrôleurs réels, politiques, révocation et sécurité des issues |
| NS-08 Alarms | Sources et sirènes locales, escalades, test sur banc autorisé |
| NS-09 Remote | Autorisation renforcée, anti-rejeu et états réels du matériel |
| NS-10 AI Security | Modèles vidéo/audio mesurés, faux positifs, pas d'action vitale autonome |
| NS-11 Fire | Centrale et matériel adaptés, alarme indépendante, recette professionnelle |
| NS-12 Environment | Capteurs et passerelles réels, calibration et défauts |
| NS-13 Visitors | QR, entrées/sorties, historique et droits complets |
| NS-14 Vehicles | Identité véhicule, registre, accès/parking et flotte selon périmètre |
| NS-15 Personal safety | SOS, escalade réelle et procédure du client |
| NS-16 Incidents | P1, preuves partagées contrôlées, qualification native complète |
| NS-17 Control 360 | Supervision complète temps réel, périmètres et mode dégradé |
| NS-18 Edge | Runtime, identité passerelle, transport sécurisé et reconnexion |
| NS-19 Compatibility | Matrice modèle/firmware et résultats de banc |
| NS-20 Maintenance | Inventaire, pièces, garanties, historique et équipement réel |
| NS-21 ERP | Contrats, équipes, remplacements, coûts et droits de formule |
| NS-22 Reporting | Exhaustivité sources, exports et parité Android |
| NS-23 Subscriptions | Quotas arbitrés, périodes, droits et impayés réels |
| NS-24 Payments | Fournisseurs, rapprochement et confirmation serveur réelle |
| NS-25 Livecare | FAQ/chatbot, transfert, pièces jointes, consentement média et partage écran |
| NS-26 Notifications | Préférences/intentions persistantes renforcées ; adaptateurs, destinations vérifiées, livraison, horaires/escalade et audio local à qualifier |
| NS-27 Assistant | IA réelle, droits, qualité et limites |
| NS-28 Languages | FR/EN/Fulfulde exhaustifs, relecture professionnelle des messages critiques |
| NS-29 Admin | Gestion complète des droits, configuration et audit de l'admin |
| NS-30 Audit | Connexions, accès/consultations, conservation et export complet |
| NS-31 Evidence | Partage contrôlé, stockage privé hébergé, intégrité, rétention et export |
| NS-32 Offline | File durable multi-parcours, conflits, chiffrement et reprise sans rejeu dangereux |
| NS-33 Integrations | Contrats inter-apps autorisés, E2E indépendants et révocation |
| NS-34 Backup | Restauration complète sur environnement dédié, intégrité et RPO/RTO |
| NS-35 Partners | Registre, habilitation, périmètre contractuel, révocation et suivi |

Développement NS-26 : a619259 ajoute préférences personnelles par site, consentement explicite et intention de diffusion privée pour FCM, Web Push, SMS, WhatsApp, e-mail ; déduplication par notification/canal, expiration 24h (choix technique de recette non SLA commercial), révocation sans réactivation des anciens éléments, exclusion des sites/membres inactifs, pas de destination ni payload sensible. 11d800f ajoute assertions opt-in, refus canal inconnu/inter-site, non exposition des tables/vues, révocation, réactivation, expiration et membre inactif. Runner 46092420261 : étape psql intégrale SUCCESS, build Web SUCCESS, replay standard de ce commit encore en cours au constat. 9780ddf/2edc5d1 : RPC et UI Web de consentement avec reçu personnel vérifié. 56a565a/ee7e1d8 : parité Compose et validation du reçu natif. 4c1eb8f : scénario Chromium/PostgreSQL de consentement par UI, création d'intentions réelles puis révocation et refus intersite ; nouvelle qualification à constater. Gates 46092461914, 46092461901, 46092461908 sur ee7e1d8 encore en file au constat. Le contrôle UI permet une action explicite mais ne relit pas encore toutes les préférences persistantes au chargement. Aucun worker fournisseur, aucun statut delivered, aucune livraison FCM/SMS/WhatsApp/email réellement réalisée. Aucun changement de comportement des alarmes physiques ; les paramètres de fournisseurs et de SLA du §31 restent ouverts.

Jauge stricte : 50,0% (35 jaunes, 0 module complet isolé à 75%, 0 vert intégral). Cible 80% à barème constant = 42 paliers unitaires de 25 points sur 35 modules (par exemple 28 modules à 75% et 7 à 100%). Cible non atteinte ; aucune reclassification sur le seul socle logiciel. 7 commits de développement et assertions sur la branche, avant la présente note. Aucun merge main, déploiement, migration hébergée, changement des autres applications ou équipement réel. Le dépôt local n'a pas pu être cloné dans cette session (DNS indisponible) ; modifications via GitHub, qualifications sur runners distants. 


## Passe accélérée — NS-22 reporting, NS-30 audit et correction NS-26

Reprise à 8da4ba6. Sur 4c1eb8f, 46092499202 Android/Web SUCCESS, 46092499189 six contrats SUCCESS, 46092499190 Chromium standard SUCCESS ; 46092499209 SQL complet suivi d'un échec Chromium (timeout du libellé Canal, log job 140816403538). Correctif d1d1f1b : nom accessible explicite et locator ajusté sans suppression de recette. Même commit : extension des rapports site/multisite aux vacations, coûts de maintenance revus, signalements, passes visiteurs, paiements confirmés, abonnements, registres, support visible et notifications personnelles ; journal transversal plutôt que seuls événements terrain. Périodes bornées, contrôles manager/site, RLS inchangée ; support et notifications ne sont pas des totaux omniscients. Les abonnements comptabilisés sont les enregistrements de site existants et ne constituent pas une preuve d'entitlement réel organisationnel. SQL 46093011869 : étape psql intégrale SUCCESS, y compris test de 5000 FCFA dans la période, exclusion 9000 FCFA intersite et 7000 FCFA hors période ; fixture navigateur chargée. Replay étendu et compilation Android/Web 46093011830 non terminés au constat.
914dc5e : journal transversal paginé par clé stable (horodatage, source, identifiant, acteur), filtre côté serveur, pages de 100 sans limite totale, export CSV de la page courante Web/Android, source administration soumise à RLS propriétaire ; le corps de messages, secrets et payloads ne sont pas projetés. Assertion sur 121 événements de même timestamp (100+21, absence de doublons et de contenu privé, refus intersite) et adaptation du replay Chromium existant à la RPC. Qualification non constatée sur ce commit au moment de la note. Pas encore audit des connexions, de toutes les consultations ni rétention intégrale/export en une opération. L'export reste volontairement par page, pour limiter la mémoire et la quantité de données exportée d'un seul coup.
Deux commits de code/recettes regroupant 16 entrées de fichiers modifiées/ajoutées, puis cette note. Jauge stricte 50,0% inchangée ; NS-22 et NS-30 renforcés, NS-26 correctif de qualification. Pas de reclassification à 75% sans fermeture des réserves et preuve de recette complète. Aucun main, déploiement, migration hébergée, équipement réel ni autre projet modifié. 


## Passe de fermeture ciblée NS-30 / NS-22 — 28 novembre 2026
Reprise 668ce58. Sur 914dc5e, cinq qualifications SECURITY SUCCESS : SQL/E2E 46093099042, Android/Web 46093098999, Chromium isolé 46093098990, contrats 46093099074, navigation 46093099001. Les précédents 46093011869 et 46093011830 sont également SUCCESS. La correction du locator de notification, le reporting étendu et la pagination audit sont qualifiés sur banc isolé.
dedb0bc : journalisation serveur des restitutions autorisées de preuves personnelles, consultation des habilitations par owner et liste d'intégration par owner/manager. Événements non modifiables par les rôles clients, visibilité personnelle et périmètre site, pas de contenu, digest ni token. Projection enrichie : objet (si disponible), origine logique RPC et identifiant de corrélation ; export CSV Web/Compose et filtre access. Les refus ne sont pas enregistrés par ce mécanisme et les consultations SQL directes hors RPC, connexions hébergées, transport média, exports client et rétention réglementaire ne sont pas couverts. L'origine logique n'est pas une adresse réseau vérifiée. NS-22 : consolidation des compteurs numériques déjà calculés par site, y compris ceux précédemment absents du total multisite ; les compteurs personnels/visibles demeurent soumis aux RLS. SQL complet 46093509471 étape psql SUCCESS (job 140819587140), reste du replay en cours au constat. Android/Web 46093509470, contrats 46093510775, navigation 46093509443, replay 46093509428 déclenchés, non qualifiés sur ce SHA au constat.
4b69ee6 : nouvelle recette Chromium/PostgreSQL de consultation autorisée de la liste d'intégration via l'UI, visualisation de la trace dans le journal et refus intersite ; aucun résultat anticipé. Deux commits code/recettes (10 entrées de fichiers cumulées), puis présente note. Jauge stricte 50,0% maintenue : qualification intégrale isolée de NS-22 et NS-30 non encore démontrée (parité native exécutée contre backend, reporting des sources non encore raccordées, accès hébergés et rétention/audit exhaustif). Aucun changement des critères de maturité. Aucun merge main, déploiement, migration hébergée ou modification des autres applications.


## Passe de clôture NS-22/NS-30 — 28 novembre 2026
Reprise b7a4780. Sur 4b69ee6, SQL/E2E 46093552613 SUCCESS, Android/Web 46093552665 SUCCESS, contrats B1–B6 46093552632 SUCCESS, Chromium isolé 46093552683 SUCCESS ; navigation 46093552647 en cours au dernier constat. La recette de consultation d'intégration et trace serveur est donc qualifiée.
3087283 : export complet d'intervalle et de source (jusqu'à 366 jours, maximum 10 000 événements par réponse ; refus explicite, jamais troncature). Rôle technique NOLOGIN NOBYPASSRLS, hérite des droits authenticated et n'est pas attribué aux clients ; insertion de trace limitée à l'export autorisé. Trace de restitution serveur, non preuve d'écriture finale du fichier sur l'appareil. Web/Compose CSV, test de 121 événements, refus intersite et période invalide, Chromium téléchargement/trace. Validation de période reçue côté Web et désactivation de la sélection pendant chargement, distinction des instantanés appareils. Run SQL/E2E 46093789092 en cours, autres workflows 46093789094, 46093789071, 46093789134, 46093789156 déclenchés.
d2591a2 : rapport site et consolidation étendus aux diagnostics, états source incendie, télémétrie, géopérimètres, preuves personnelles et autorisations média personnelles. Assertions diagnostic expiré, absence de données intersite, indicateurs vides. 059fe1b : scission préventive du constructeur JSON de consolidation pour respecter la limite PostgreSQL de 100 arguments. Qualification du dernier SHA non acquise.
Critères résiduels NS-22 : métriques des sources non raccordées (notamment équipements/transport réels et ERP restant), qualification Android exécutée contre backend, vérification exhaustivité et recette utilisateur. NS-30 : connexions réelles et tentatives refusées, consultations vidéo/audio et lecture enregistrements, couverture intégrale des exports et autres événements du §5.4, rétention arbitrée et testée, qualification native réelle. Les durées et plafonds d'export sont des limites techniques de recette, non des durées de conservation ni SLA. 3 commits code/recette puis cette note. Jauge stricte inchangée 50,0%; cible 51,43% non démontrée, aucune clôture intégrale ni changement du barème. Aucun merge main, déploiement, migration hébergée ou changement d'autres applications.


## Poursuite clôture NS-30 / NS-22 — 28 novembre 2026
Reprise 9d2a949. Les cinq workflows sur 059fe1b sont SUCCESS : SQL/E2E 46093848111, Android/Web 46093848154, contrats 46093848163, Chromium 46093848167, navigation 46093848198 (11 lots). Export complet et nouveaux compteurs de reporting qualifiés sur banc isolé.
0a1070e : traçabilité des refus de consultations sensibles sur site où l'acteur est déjà habilité (lecture membres, intégrations, preuve personnelle non disponible). Aucune identité de cible ni distinction entre inexistence et absence de droit en cas de refus ; pas de trace exposée au site d'un acteur sans appartenance. Assertions de refus, confidentialité, absence de privilège d'écriture. Alignement limite réponse native pour export à 8 millions de caractères, plafond serveur de 7,5 millions d'octets de données ou 10 000 lignes, refus explicite, sans troncature. Le contrat métier 46096199181 est SUCCESS ; SQL/E2E 46096199137 à confirmer entièrement. 
2344ade : politique de conservation par site réservée au propriétaire, durée explicite, gel par défaut, trace des modifications, simulation du nombre de traces de consultation candidates, Web et Compose natif, assertions absence de politique, gel, refus manager et non-suppression. Aucune purge ; la durée de conservation de production et les journaux sources restent à arbitrer. Le périmètre de simulation couvre uniquement sec_access_audit, non les journaux métiers ou médias. Deux commits de code/recettes, 14 entrées de fichiers cumulées, puis cette note. Jauge stricte 50,0% inchangée : les connexions réelles, refus intersite/auth, consultations multimédia effectives, conservation effective et qualification Android réelle restent ouverts, tout comme sources métier non raccordées pour NS-22. Aucun changement des autres applications, main, déploiement, migration hébergée ou suppression de données.


## Passe métier transversale — 28 novembre 2026
Reprise d858de2. Les cinq workflows SECURITY de 2344ade sont SUCCESS (SQL/E2E 46096247118, Android/Web 46096247083, contrats 46096247082, navigation 46096247086, Chromium 46096247106). Gate commun famille 46096247070 FAILURE, non corrigé hors périmètre.
8a22d43 : nouveau registre métier transactionnel avec sept catégories, relations et contraintes dédiées : clients, contrats rattachés à un client actif (dates et montant), équipe (collaborateur habilité au site), actifs (appareil du site et dates de garantie), pièces/consommables (stock non négatif, seuil, mouvements idempotents et historique), partenaires (dates), profils administratifs d'accès (aucune ouverture physique ni habilitation matérielle). Création/archivage, refus d'archiver un client avec contrats actifs ou pièce avec stock, rôles manager/owner et RLS, reçu vérifié. Web et Compose sur 15 écrans B4/B5, assertions SQL, recette Chromium stock et isolation. Modèle inspiré des patterns de gestion d'équipe et mouvements append-only NAXA SERVICES, sans copier les données ni ses règles sectorielles. La lecture catalogue reste limitée à 100 entrées par requête, à paginer ; pas de système complet de contrats, de composition d'équipes multiples ou d'autorisation d'accès réelle.
73f4075 : projection des événements catalogue dans journal transversal (filtre et export), lecture persistante des cinq préférences de diffusion personnelles sur B6.01 et B6.02, aide FAQ/recherche guidée B6.05/06 Web et Android, six réponses documentaires, pas d'IA générative. Recettes E2E ajoutées. Pas de livraison externe ni chatbot conversationnel réel. Deux commits métier (25 entrées de fichiers cumulées) et note. Sur 8a22d43 contrats B1–B6 46100812276 SUCCESS, autres en cours au constat ; sur 73f4075 SQL/E2E 46100866249 et Android/Web 46100866288 déclenchés. Pas de reclassification des modules : jauge stricte 50,0%, les nouveaux parcours sont à qualifier, aucune totalité des 35 modules démontrée. Aucun merge main, migration hébergée, déploiement ou modification des autres projets.


## Recentrage cœur métier — rondes, visiteurs et véhicules — 28 novembre 2026
Reprise e602b90. Les cinq workflows spécialisés du lot 73f4075 sont SUCCESS : SQL/E2E 46100866249, Android/Web 46100866288, contrats 46100866248, navigation 46100866239, Chromium 46100866252. Les cinq workflows spécialisés du lot 8a22d43 sont également SUCCESS. Les acquis ERP sont conservés ; priorité aux fonctions sécurité. 
e6a61c7 : fenêtres horaires facultatives des rondes (maximum 24 h, démarrage hors fenêtre refusé), remplacement d'un agent avant départ réservé au manager/owner et au membre actif du site, événements d'anomalie par agent affecté ou manager, horodatage départ/soumission/revue et reviewer distinct, compteurs retard/anomalies dans reporting site et consolidé. Une ronde commencée peut être soumise tardivement sans perdre les données ; retard signalé. Web/Compose B4.16 et B4.18 raccordés, assertions et Chromium de remplacement/anomalie. Pas de QR/NFC/BLE ni de preuve de présence physique ; pas d'alerte externe. SQL/E2E 46101290688 et Android/Web 46101290610 à confirmer.
0771201 : parité native du code de visite/véhicule à usage unique, émission par manager, vérification/consommation, révocation, historique, reçu serveur strict, token SecureRandom 256 bits non stocké durablement par client. Raccordement Android des historiques de passages et checkpoints et extension des écrans visiteurs/véhicules Web. Code textuel, pas encore scanner QR, aucune ouverture physique. Android/Web 46101327436, contrats 46101327447, navigation 46101327464, replay 46101327431 déclenchés. Deux commits code (11 entrées de fichiers cumulées), puis cette note. Jauge stricte inchangée 50,0% ; pas de reclassification intégrale NS-06/07/13/14. Aucun main, déploiement, migration hébergée, équipement réel ni changement d'autre projet.


## Accélération cœur métier et fonctions transversales — 28 novembre 2026
Reprise 627eb8e. Cinq workflows de e6a61c7 SUCCESS ; les quatre workflows spécialisés déclenchés par 0771201 SUCCESS. Le scope SQL de ce dernier commit est hérité sans changement de e6a61c7.
- 4f0b602 : Control 360 instantané site, 10 indicateurs (appareils contact récent/ancien/inconnu/défaut, incidents ouverts/critiques, avertissements, dernier état incendie actif/défaut, rondes en retard, SOS interne). Seuils hauts environnementaux configurables par manager/owner, limités à un capteur environnement du site ; retrait et audit. Web et Compose B2.25/B3.01-03/B3.22. Les cinq workflows SECURITY sont SUCCESS : SQL/Chromium 46101681961, Android/Web 46101681954, contrats 46101682001, replay 46101682011, navigation 46101681995. Le snapshot est manuel, non temps réel, sans carte ; aucun zéro ne prouve la sécurité, aucune action physique.
- 0a804dd : ouverture média par RPC auditée et consentement issu d'une demande revue, métadonnées manager sans URL, révocation du propriétaire/manager ou titulaire, accès URL personnel uniquement sur contrôle courant du site et origine configurée, suppression du SELECT direct de l'URL, lecture Android VideoView avec origine HTTPS configurée, arrêt à expiration, sortie de l'écran et mise en arrière-plan ; Web renforcé sur six écrans média. Tous les cinq workflows SECURITY SUCCESS (SQL/E2E 46101763331, Android/Web 46101763377, contrats 46101763335, Chromium 46101763375, navigation 46101763334). Pas de flux ou enregistrement réel testé : transport de confiance, validation du grant côté transport pour chaque requête, codecs, non-redirection, contrôle PTZ, clips, export et interphonie restent requis.
- ec47fbb : runtime de référence EDGE (fichiers privés, enveloppes signées HMAC, file bornée persistante, écriture atomique/sync, reprise après redémarrage, confirmation stricte avant retrait, rétention des expirés pour revue, adaptateur ingress à résolution de secret injectée et transport HTTPS sans redirection). Les contrats 46101826336, dont B2 et les nouveaux tests de redémarrage, sont SUCCESS ; SQL/E2E 46101826345, Chromium 46101826335, navigation 46101826352 SUCCESS ; Android/Web 46101826368 à confirmer au dernier constat. Référence de banc, non service hébergé ni connecteur matériel ; pas de découverte/provisionnement réel, chiffrage disque ni gestion de plusieurs processus.
- f4dd18f : remontées intrusion/sabotage/défaut/restauration via rôle gateway approuvé et binding site/appareil, événements idempotents, triage humain accusé/escalade/revue, journal et notifications internes aux responsables ; état de source non modifié par la revue, aucune extinction ou ouverture. Web et Compose B3.03-09. SQL/E2E 46101909383 SUCCESS, Android/Web 46101909405 SUCCESS, contrats 46101909426 et Chromium 46101909336 SUCCESS ; navigation 46101909382 à confirmer. Pas de sirène, modèle IA, secours, transport réel ni intégration déclencheurs physiques.
- 8e1948f : partage de preuve temporaire nominatif (1–1440 min, maximum technique), propriétaire et destinataire habilités au même site, révocation, audit, aucun lien public, téléchargement avec SHA-256 Web/Compose B6.23, 256 Kio max existant. SQL assertions sur 46102012173 SUCCESS, build Web SUCCESS ; Android/Web 46102012224 en cours au dernier constat. Pas de stockage hébergé, pas de rétractation des copies déjà exportées, ni lien incident automatiquement ajouté.
- 07941a4 : QR visiteur/véhicule généré localement et affiché jusqu'à échéance ; scan caméra Android avec ZXing embarqué, Web via jsQR (caméra ou image locale), confirmation serveur toujours explicite, caméra arrêtée après lecture/sortie. Code texte reste disponible. Test Chromium E2E modifié pour générer puis lire l'image QR et consommer une seule fois le code. Dépendances qrcode 1.5.4/jsqr 1.4.0 et ZXing embedded 4.3.0 ; aucune transmission à service QR externe. Recettes 46102094105 (SQL/Chromium), 46102094048 (Android/Web), 46102094049 (contrats), 46102094077 (replay), 46102094287 (navigation) déclenchées ; résultats non acquis à la rédaction. Pas de caméra physique testée ni pointage/rondes QR ou NFC.
Bilan : 6 commits code et 53 entrées de fichiers cumulées, plus cette note. Jauge de construction métier exhaustive non calculable sans inventaire atomique des exigences validées ; ne pas transformer la quantité de commits en pourcentage. Jauge de maturité stricte maintenue à 50,0% : aucun des 35 modules n'a encore satisfait l'intégralité de ses critères. Le 100% n'est pas atteint : restent notamment vidéo/audio avancés (PTZ, archives, interphonie), runtime/transport matériel, GPS/présence/rondes, politiques accès, IA réellement intégrée, abonnements/impayés et paiements, Livecare avancé, langues, offline généralisé, intégrations et restauration complète. Les choix techniques de banc (durée/limites de partage, fraîcheur, TTL et QR) ne constituent pas des SLA commerciaux. Aucun main, déploiement, migration hébergée, modification des autres applications ou équipement physique.


## Clôture de parcours logiciels — 28 novembre 2026
Reprise 587e730. Les cinq workflows spécialisés de 8e1948f SUCCESS ; sur 07941a4, SQL/Chromium 46102094105 SUCCESS (génération QR, lecture image et consommation unique), Android/Web 46102094048 SUCCESS, contrats 46102094049 SUCCESS et Chromium isolé 46102094077 SUCCESS ; navigation 46102094287 à confirmer. 
- 7021af3 : correction de la contradiction commerciale avec §3 : une chronologie payée par organisation, Essentiel sur un seul site, Business/Professional multisites, prochain abonnement à la fin de la période déjà payée (pas de changement rétroactif ni prélèvement), statut actif/expiré/non couvert/non souscrit, historique financier et allocation d'un reçu confirmé unique Web et Android. Le changement d'offre prend effet à l'échéance ; quotas non définis, droits de formule exposés mais non appliqués à l'ensemble des RPC, fournisseur réel absent. SQL/E2E 46102391769 SUCCESS, Android/Web 46102391764 SUCCESS, contrats 46102391755 SUCCESS, Chromium 46102391775 SUCCESS, navigation 46102391776 en attente.
- 135018a : traceurs d'actifs/véhicules uniquement, activation/suspension par manager/owner, ingestion par gateway lié, identifiant événement idempotent, historique paginé (101 positions testées), évaluation géopérimètre avec bande d'incertitude, schéma local de trajectoire et parité de code Web/Compose B4.01-06 ; historique après suspension conservé, pas de suivi permanent des personnes, pas de fond cartographique routier ni alerte de franchissement poussée, pas de matériel ni transport position réel. Limitation historique financier manager au site propre (owner organisation). SQL/E2E 46102476304 SUCCESS, Web SUCCESS, Chromium 46102476315 SUCCESS ; Android 46102476284 FAILURE (Maven Central 429 sur ZXing 4.3.0, trois essais ; pas un résultat de compilation du nouveau code).
- fe3219f : quatre actions de pointage (arrivée/départ/début et fin de pause), capture ponctuelle et reçu strict, historique Web avec état réel. Rapport par vacation sur preuves examinées et fenêtre exacte planifiée, temps travail/pause, retard/départ anticipé, anomalies, totaux nuls pour séquence non complète ; aucun calcul de paie ni preuve physique certifiée. Assertions 370 min de travail, 30 min de pause, 10 min retard et départ anticipé ; SQL/E2E 46102562610 SUCCESS, Web 46102562646 SUCCESS ; Android du même workflow non terminé. Les pointages hors fenêtre, QR/NFC/BLE, correction formelle des anomalies et authentification matérielle restent ouverts.
- 8bdba88 : recettes Chromium/PG supplémentaires sur organisation/personas synthétiques distinctes : allocation puis renouvellement non rétroactif, suivi GPS puis suspension, bilan vacation et pauses. 46102612760 en cours ; réussite de ces scénarios nouveaux non constatée à la rédaction.
- fd0bc04 : inventaire paginé, profil fabricant/modèle/firmware déclaré/référence, inscription par propriétaire, liaison logique à un gateway du site, interdiction d'un second gateway actif, révocation, idempotence et audit ; lecture manager et owner, SQL de réception puis refus après révocation, Web et Compose B2.14/15/17/18/21/22 B6.28/29, recette Chromium inscription/liaison/révocation. Aucun secret provisionné, aucune découverte matérielle, compatibilité non certifiée. SQL/E2E 46102710133 et Android/Web 46102710175 déclenchés, non terminés.
- ccb78ba : cause racine du gate famille 46102562642 identifiée dans le job 140848129981 (TS2307 sur qrcode et jsqr, TS7006 callback) : le générateur historique réécrit le manifest de SECURITY. Ajout spécifique à SECURITY de ces dépendances, type QR, Vite, ZXing et build config SECURITY_MEDIA_ORIGIN dans la prévisualisation jetable, annotation callback ; aucune modification des manifests des autres apps. Gate famille 46102812322, Android/Web 46102812350, contrats 46102812311, Chromium 46102812369 déclenchés. Correction non déclarée qualifiée tant que le nouveau gate n'est pas vert. Le 429 Maven reste externe.
Bilan 6 commits code/recettes/correctifs (49 entrées de fichiers cumulées) puis cette note. Les quatre parcours ont une implémentation fonctionnelle logicielle circonscrite, dont les trois premiers SQL qualifiés ; ne pas extrapoler à 100% de tous leurs modules ni à la production. Jauge stricte 50,0% inchangée. Le 100% métier n'est pas atteint ; restent notamment transport vidéo/audio réel, PTZ/archives/interphonie, règles accès physiques, IA avancée, provider de paiement, droits de formule effectifs, Livecare média, notifications externes, langues, offline général, intégrations et sauvegarde complète. Aucune nouvelle branche, main, déploiement ou migration hébergée.


## Reprise et corrections de qualification — 28 novembre 2026
Reprise 448ce32. Confirmation 7021af3 : les cinq workflows SECURITY sont SUCCESS, navigation incluse 46102391776. 135018a : 4/5 SUCCESS (Android gate 46102476284 FAILURE, Maven 429 ZXing constaté antérieurement). fe3219f : SQL/E2E, contrats, navigation, Chromium SUCCESS ; Android 46102562646 FAILURE. 8bdba88 et fd0bc04 : SQL assertions/fixtures/build Web réussis, E2E bloqué par localisation de la liste de vacations (46102612760 et 46102710133), Android bloqué par syntaxe Kotlin (46102710175 job 140848540673, ligne 16 SecurityNativePresence). Dans le gate famille de ccb78ba 46102812322, les types et builds Web communs et la navigation réelle SECURITY sont SUCCESS ; échec du build Android commun job 140848887588 sur la même syntaxe Kotlin SECURITY, pas d'autre cause corrigée.
- b294b62 : corrige la fonction locale Kotlin de formatage des durées (bloc explicite), nom accessible de la liste des vacations, attente du chargement et sélection par rôle combobox. Recettes 46103509571 (SQL/E2E), 46103509438 (Android/Web), 46103509452 (contrats), 46103509455 (replay), 46103509630 (navigation). Au constat : assertions SQL et build Web réussis, qualifications complètes à confirmer.
- 417b30c : transfert Livecare vers agent explicitement provisionné, actif, du même site, distinct du client et de l'agent courant. Motif obligatoire, état/échéance conservés, reçu idempotent, retrait immédiat de la lecture du dossier et des messages au précédent agent, notification interne au destinataire et au client. Raccord Web/Compose, assertions SQL de reprise et isolation, nouvelle recette Chromium de création/prise en charge/transfert/notification/résolution. Pas de transfert inter-organisation ou vers un compte NAXA central non provisionné, pas d'appel, partage écran ou pièce jointe. CI 46103590407 et 46103590402 lancées.
- abb545e : restriction de la répétition d'un transfert à son acteur initial et contexte exact avant divulgation du conflit ; nom accessible explicite du sélecteur de type matériel, recette ajustée. CI 46103623633 SQL/E2E, 46103623685 Android/Web, 46103623647 contrats, 46103623662 replay, 46103623671 navigation, 46103623679 gate famille déclenchées.
Jauge stricte 50,0% conservée : aucun module entier requalifié sur tous ses critères. 3 commits code/corrections (13 entrées de fichiers cumulées), puis note. Les parcours précédents ne sont pas régressés intentionnellement, mais attendre le résultat de la révision exacte pour confirmer. Pas de main, déploiement, migration hébergée ou modifications d'autres applications.


## Reprise Livecare — pièces jointes — 28 novembre 2026
Reprise 7a52ac5. Confirmation b294b62 : SQL/E2E 46103509571, Android/Web 46103509438, contrats 46103509452 et replay 46103509455 SUCCESS ; navigation 46103509630 encore en file au dernier constat. Le transfert 417b30c : SQL/E2E 46103590407, Android/Web 46103590402 et replay 46103590390 SUCCESS. Pour abb545e : Android/Web 46103623685 et replay 46103623662 SUCCESS, SQL/E2E 46103623633 en cours, contrats/navigation en file.
- dc0cf31 : pièces jointes de dossier Livecare B6.12/13/14, réemploi des preuves personnelles existantes (max 256 Kio), partage explicite, autorisation serveur client et agent actuellement affecté et actif (agent seulement pendant traitement), retrait après transfert/résolution, révocation par auteur autorisé, idempotence création, SHA-256 avant téléchargement, journalisation. Assertions SQL : lecture avant affectation interdite, téléchargement par agent affecté, refus ancien agent, accès nouvel agent, révocation. Aucun lien public, aucune rétractation des copies téléchargées. Interfaces Android et Web, aucun stockage distant ajouté. CI 46103904318 SQL/E2E, 46103904332 Android/Web, 46103904292 contrats, 46103904294 replay, 46103904353 navigation en file à la rédaction.
- 4aff275 : ajout à la liste native autorisée des preuves personnelles, fixture indépendante et recette navigateur création dossier, partage, affectation, téléchargement vérifié et révocation/refus serveur. CI exacte : Famille NAXA — validation groupée 0.1/0.2 46103936335 queued; NAXA SECURITY — responsive and native gate 46103936290 queued; NAXA SECURITY — parallel recipes 50 46103936296 queued; NAXA SECURITY — business contracts B1–B6 46103936304 queued; NAXA SECURITY — Chromium replay isolated 46103936302 queued; NAXA SECURITY — isolated database contract 46103936291 queued.
Bilan 2 commits code/recettes (13 entrées cumulées), puis note. La qualification de la nouvelle pièce jointe reste à confirmer. Le 100% métier n'est pas acquis, jauge stricte 50,0% inchangée. Restent notamment support central interorganisation, appels/partage écran, transport média réel, IA, droits de formule effectifs, offline et intégrations matérielles. Pas de main, déploiement, migration hébergée ni modification d'autre application.


## Bulk de qualification et administration Livecare — 28 novembre 2026
Objectif utilisateur : au moins +5 points par passe, uniquement avec preuve ; échelle stricte inchangée (35 modules, 0/25/50/75/100). Reprise bf93c9b. Sur 4aff275 les cinq workflows SECURITY sont encore en file au premier constat. 
- 4414530 : habilitation/révocation d'agents Livecare par propriétaire du site, membres déjà actifs uniquement, historique d'audit, remise des dossiers ouverts en file sans perte de messages ni échéance, réouverture après résolution vers la file si ancien agent non habilité. Web/Compose B6.15/16 ; assertions SQL d'accès et refus. Aucun droit global ni compte central NAXA créé.
- 1910f4f : sérialisation des changements d'habilitation et transitions de dossiers par verrou site ; recette Chromium/PG propriétaire habilite, agent prend en charge, propriétaire révoque et remet en file, refus de lecture de l'ancien agent ; assertions supplémentaires de réouverture. 15 entrées code/recettes cumulées sur les deux commits.
- Bulk déclenché par push code sur la branche existante. Le registre recipe-lots.json contient exactement 543 cas de navigation responsive (181 écrans × 3 tailles), 11 lots max 50, fail-fast false, max-parallel 11. Contrats B1–B6 en 6 jobs max-parallel 6 ; SQL/E2E, replay Chromium, gate Android/Web et gate famille distincts. Pour 4414530 : navigation 46104365696, contrats 46104365684, SQL/E2E 46104365679, replay 46104365677, Android/Web 46104365670, famille 46104365726, tous déclenchés. Pour 1910f4f : NAXA SECURITY — parallel recipes 50 46104403101 queued; NAXA SECURITY — business contracts B1–B6 46104403068 queued; NAXA SECURITY — Chromium replay isolated 46104403043 queued. Ne pas confondre 543 navigations avec 543 parcours métier E2E complets. 
Jauge stricte 50,0% ; +5 points non acquis : dernières recettes non terminées et aucune clôture entière de module démontrée. L'objectif de cadence n'autorise pas une modification artificielle de la méthode de mesure. Pas de main, déploiement, migration hébergée ou modification autre app. Restent support central NAXA, appels/partage écran, transport matériel, IA, droits effectifs de formule et offline global, entre autres.


## Objectif autonome de fermeture NS-13 / NS-30 / NS-05 / NS-31 — 28 novembre 2026
Objectif demandé : poursuivre jusqu'à fermeture complète des quatre modules (+5,71 points si tous passent de 50 à 100). Aucune réduction arbitraire du périmètre ni modification de l'échelle. Reprise 313ce4f.
- a82f1a4 : cause racine du job 140852357828 / run 46103936291 : référence synthétique avec espaces, refusée par sec_evidence_files_reference_check. Correction des deux fixtures et de la recette Chromium (références avec tirets), sans changer la contrainte.
- 7de92ad (NS-13) : ajout de consume_entry dans sec_visit_pass ; verrou registre avant consommation, contrôle de la séquence et durée, insertion d'entrée et consommation dans une transaction, reçu idempotent, preuve de sortie via sec_field_action, refus de rejeu, pas de commande physique. Web/Compose QR, nouveau scénario SQL ; scénario Chromium QR existant étendu. 098ba45 adapte les assertions de journal au nouveau nom d'opération, sans fuite du secret.
- ea84092 (NS-05) : classification explicite des vacations (non acceptée, prévue, en cours non confirmée, complète, à revoir, preuve manquante/incomplète, annulée), aucun constat automatique d'absence ; assertions SQL et affichage Web/Compose, recette Chromium de bilan.
- 11afd5c (NS-31/30) : inventaire personnel du stockage, compteurs de volume, pagination keyset, vérification serveur SHA-256 et taille, anomalies visibles, journal d'inventaire et de contrôle autorisé/refusé avec objet masqué lors d'un refus. Pas de quota commercial inventé, pas de suppression ni stockage distant. 098ba45 ajoute fixture de fichier volontairement corrompu et parcours Chromium de vérification, détection et consultation du journal.
- 5070ba4 (NS-05) : QR nominatif de vacation B4.09, émission par responsable habilité sur vacation active acceptée, token 256 bits hashé côté serveur, validité maximale 120 secondes (limite technique), destiné au seul agent affecté, GPS ponctuel, consommation atomique et idempotente, création de preuve en attente de revue indépendante, rejet des réutilisations et des autres agents, journal sans token. Web/Compose ; aucun suivi continu, aucune certification de présence physique. 162801d : recette Chromium de génération, lecture image, GPS synthétique, rejet rejeu et revue ; correction Kotlin préventive. 144e54d : adaptation du paramètre de revue au contrat existant 'next'.
- 8 commits code/recettes/correctifs ; plus la présente note. Les workflows sur les révisions successives sont déclenchés. 098ba45 : SQL/E2E 46105239508, Android/Web 46105239420, navigation 46105239433, contrats 46105239400, replay 46105239380, tous en file au dernier constat. 162801d : SQL/E2E 46105356187, Android/Web 46105356189, contrats 46105356188, replay 46105356172, navigation 46105356222 en file. 144e54d : NAXA SECURITY — business contracts B1–B6 46105371776 queued; NAXA SECURITY — isolated database contract 46105371846 queued; NAXA SECURITY — Chromium replay isolated 46105371798 queued; NAXA SECURITY — responsive and native gate 46105371750 queued; NAXA SECURITY — parallel recipes 50 46105371796 queued. Aucun nouveau PASS déduit de l'enregistrement des commits.
Réserves de clôture : NS-13 validation exhaustive et physique du parcours visiteurs ; NS-05 NFC/RFID/BLE et terminal physique, exceptions/absences justifiées et export ; NS-30 connexions réelles, accès aux flux/archives réels, couverture exhaustive des journaux et rétention approuvée ; NS-31 stockage hébergé, quotas/conservation approuvés, qualification réelle. Les tests de la nouvelle révision doivent être exécutés, les autres réserves levées. Jauge stricte 50,0% inchangée ; objectif +5,71 non acquis. Aucun main, déploiement, migration hébergée ou autre application modifiés.


## Deuxième passe de fermeture NS-13 / NS-05 / NS-30 / NS-31 — 28 novembre 2026
Objectif : vert complet et non vert partiel ; aucune réduction de critères. Reprise 3938fa8. 5 commits code/recettes (45 entrées cumulées) :
- e91a40e : NS-05 déclarations manuelles d'arrivée/départ/pauses/absence par agent affecté, justification obligatoire, revue indépendante et idempotente, refus de conflits, pas de coordonnées inventées ; bilan réconcilie les preuves approuvées et identifie une absence examinée, sans calcul de paie ni preuve physique. Web/Compose et assertions SQL.
- 47cf470 : NS-31 politique technique de stockage par propriétaire, limite de volume appliquée par verrou site et trigger, refus au-delà, compteurs agrégés, gel de conservation, simulation des fichiers anciens sans référence historique de partage/support/incident ; aucun quota de formule inventé, aucune purge. Web/Compose, assertions SQL de limite/rejeu/gel et deux recettes Chromium (absence et politique).
- f89b546 : NS-13 registre paginé et historique (100 dernières lignes), états attendu/entré/sorti/expiré/annulé, annulation tracée et révocation des codes, garde sur émission/consommation et passage manuel, sortie toujours consignée si entrée antérieure ; Android/Web et assertions.
- 5bd0f9f : NS-30 prévisualisation agrégée de conservation pour les sources du journal transversal, gel à zéro, export natif catalog corrigé, assertions et scénario Chromium visite annulée, sortie puis refus de réentrée.
- 333649d : confidentialité du registre alignée sur droits existants (opérateur seulement ses demandes ; owner/manager du site), assertions de refus ; validation de données GPS nulles et limite de fin de vacation QR.
Dernières qualifications : NAXA SECURITY — responsive and native gate 46106013432 queued; NAXA SECURITY — Chromium replay isolated 46106013516 queued; NAXA SECURITY — business contracts B1–B6 46106013419 queued; NAXA SECURITY — isolated database contract 46106013434 queued; NAXA SECURITY — parallel recipes 50 46106013459 queued ; précédente révision 5bd0f9f : NAXA SECURITY — Chromium replay isolated 46105964742 queued; NAXA SECURITY — responsive and native gate 46105964704 queued; NAXA SECURITY — business contracts B1–B6 46105964617 queued; Famille NAXA — validation groupée 0.1/0.2 46105964655 queued; NAXA SECURITY — parallel recipes 50 46105964686 queued; NAXA SECURITY — isolated database contract 46105964654 queued. Aucun résultat vert ne peut être déduit de la file. Les runs 144e54d étaient encore queued au dernier contrôle. Pas de PostgreSQL local ni accès réseau GitHub direct dans le conteneur, qualification via GitHub. Restent : NS-13 qualification Android physique/exhaustivité ; NS-05 lecteur NFC/RFID/BLE et terminal réel, export et qualification ; NS-30 connexions et transport média réels, règles de conservation et exécution approuvées ; NS-31 stockage hébergé et quotas/rétention commerciaux approuvés, qualification réelle. Politique technique configurée à la demande du propriétaire, distincte de l'abonnement, aucune destruction. Jauge stricte 50,0% : aucun module déclaré fermé sans preuve ; objectif 55,71% non acquis. Aucun déploiement, main, migration hébergée ni autre application modifiés.


## Troisième passe de fermeture — NS-05 / NS-13 / NS-30 / NS-31
Reprise efa9f9e. Objectif de vert complet inchangé. c4fbc41 : export CSV du bilan par vacation sur Web et Android, champs de provenance/état et non-certification physique ; recette navigateur de téléchargement. Android B6.22 : sélection de fichier via SAF, lecture bornée 256 Kio, SHA-256, reçu serveur strict, rejeu idempotent, téléchargement personnel vérifié et sauvegarde SAF, effacement des buffers en mémoire. cf8ec05 : Web validation de référence, reçu stockage vérifié (id/état/empreinte) et scénario Chromium/PG de chargement, téléchargement octet pour octet et refus de lecture par manager non propriétaire. Deux commits de code, sept entrées de fichiers (six fichiers distincts).
Qualification : cf8ec05: NAXA SECURITY — Chromium replay isolated 46106576948 queued; NAXA SECURITY — parallel recipes 50 46106576971 queued; NAXA SECURITY — business contracts B1–B6 46106576959 queued; NAXA SECURITY — isolated database contract 46106576950 queued; NAXA SECURITY — responsive and native gate 46106576972 queued; Famille NAXA — validation groupée 0.1/0.2 46106576961 queued\nc4fbc41: NAXA SECURITY — responsive and native gate 46106515846 queued; NAXA SECURITY — parallel recipes 50 46106515860 queued; NAXA SECURITY — Chromium replay isolated 46106515852 queued; NAXA SECURITY — isolated database contract 46106515949 queued; NAXA SECURITY — business contracts B1–B6 46106515882 queued; Famille NAXA — validation groupée 0.1/0.2 46106515868 completed cancelled\n333649d: NAXA SECURITY — responsive and native gate 46106013432 queued; NAXA SECURITY — Chromium replay isolated 46106013516 queued; NAXA SECURITY — business contracts B1–B6 46106013419 queued; NAXA SECURITY — isolated database contract 46106013434 queued; NAXA SECURITY — parallel recipes 50 46106013459 queued. Aucun succès déduit d'une file. Vérification du conteneur : pas de psql/postgres/initdb, git distant échoue en résolution DNS. Supabase FAMILLE-NAXA accessible en lecture de métadonnées mais aucune branche de développement isolée recensée ; aucune fixture ou migration injectée dans la base commune. Pas de création de branche facturable. Aucun main/déploiement.
Réserves encore bloquantes : qualification des révisions (SQL/Web/Android), NS-05 NFC/RFID/BLE matériel et épreuves physiques, NS-13 qualification physique et parcours exhaustif, NS-30 événements authentification et transport média réels + conservation effective, NS-31 stockage hébergé et quotas/rétention validés. Export présence et saisie/téléchargement de preuve natifs désormais implémentés mais non qualifiés. Jauge officielle 50,0%, objectif 55,71% non atteint. Ne pas assimiler le stockage PostgreSQL de recette à un stockage de production.


## Désengorgement CI et reprise des preuves de qualification
Reprise 2eb7d36. Audit : 504 runs historiques sur la branche au premier relevé, 42 queued, 9 in_progress et 453 completed (état évolutif). Aucun accès à l'inventaire des runners via le connecteur (endpoint non autorisé), donc cause infrastructure exacte non prouvée. Cinq workflows SECURITY dépourvus de concurrence par branche : db, ui, replay, business, lots. Commit 428d8ff : groupe de concurrence par workflow et ref, cancel-in-progress:false ; conserve la qualification en cours et remplace seulement les pending obsolètes dans le même groupe, sans réduire les matrices B1–B6 ni 11 lots, sans effet sur autres branches/produits. Les runs antérieurs sans groupe ne sont pas automatiquement annulés ; aucune annulation manuelle effectuée.
Preuves nouvellement observées : 162801d contrats B1–B6 46105356188 : 6 jobs SUCCESS. 144e54d gate Web/Android 46105371750 : deux jobs SUCCESS (build et tests, pas instrumentation physique). 144e54d SQL 46105371846 job 140856823376 : étape complète psql assertions SUCCESS, fixture navigateur SUCCESS, build Web SUCCESS, E2E in_progress/non conclu. Ne pas extrapoler aux commits ultérieurs. Dernier code métier cf8ec05 ; nouvelle révision CI 428d8ff : NAXA SECURITY — responsive and native gate 46107020611 queued; NAXA SECURITY — business contracts B1–B6 46107020632 queued; NAXA SECURITY — parallel recipes 50 46107020624 queued; NAXA SECURITY — isolated database contract 46107020636 queued; NAXA SECURITY — Chromium replay isolated 46107020578 queued.
Pas de nouvelles modifications métier non qualifiées pendant cette passe. Conteneur vérifié : aucun serveur PostgreSQL local ni psql, réseau GitHub/npm non résolu. Supabase branche isolée absente ; création potentiellement facturable nécessitant accord explicite. Aucun déploiement ni migration de production. Réserves physiques, stockage hébergé, décisions de rétention et quotas demeurent. Jauge 50,0% stricte tant que le périmètre module et la dernière révision ne sont pas qualifiés ; objectif 55,71% non atteint.


## Reprise de qualification et correction du QR visiteurs
Reprise 574197b. 144e54d : gate Android/Web 46105371750 SUCCESS, replay Chromium 46105371798 SUCCESS, contrats B1–B6 46105371776 SUCCESS. SQL 46105371846 : toutes assertions PostgreSQL SUCCESS, fixture SUCCESS, quatre premiers parcours Chromium/PG PASS (support 9 actions, incidents multisites, cycle incident, vacations/maintenance), puis échec interface QR visiteur ligne 111 (job 140856823376). e91a40e : gate Android/Web 46105730387 SUCCESS et replay 46105730337 SUCCESS ; étape assertions SQL, y compris exceptions manuelles, SUCCESS (job 140857918155 / run 46105730429), E2E bloqué avant la fin. Cause vérifiée : expression régulière doublement échappée dans le bouton consume_entry, imposant un antislash avant le séparateur, donc bouton disabled même avec QR valide. a18ac7c : correction, vérification explicite de l'activation des deux boutons dans E2E, aucune suppression d'assertion. 7c15de6 : validateur unique JS du QR temporaire (UUID canonique, point littéral, 64 hex, 101 caractères), utilisé par rendu, scan, visiteur et pointage ; tests positifs/négatifs dans bulk B4. Contrôle JS direct du validateur PASS dans l'environnement de cette session ; ni compilation complète ni E2E de ce nouveau commit encore prouvés. 2 commits, 7 entrées de fichiers cumulées, puis cette note. Dernières actions : 7c15de6: NAXA SECURITY — parallel recipes 50 46107256088 pending; NAXA SECURITY — Chromium replay isolated 46107255950 pending; Famille NAXA — validation groupée 0.1/0.2 46107255967 queued; NAXA SECURITY — isolated database contract 46107256134 pending; NAXA SECURITY — business contracts B1–B6 46107255965 pending; NAXA SECURITY — responsive and native gate 46107255984 pending\na18ac7c: NAXA SECURITY — Chromium replay isolated 46107196391 completed cancelled; NAXA SECURITY — parallel recipes 50 46107196393 completed cancelled; Famille NAXA — validation groupée 0.1/0.2 46107196411 completed cancelled; NAXA SECURITY — business contracts B1–B6 46107196409 completed cancelled; NAXA SECURITY — responsive and native gate 46107196421 completed cancelled; NAXA SECURITY — isolated database contract 46107196513 completed cancelled\n428d8ff: NAXA SECURITY — responsive and native gate 46107020611 queued; NAXA SECURITY — business contracts B1–B6 46107020632 queued; NAXA SECURITY — parallel recipes 50 46107020624 queued; NAXA SECURITY — isolated database contract 46107020636 queued; NAXA SECURITY — Chromium replay isolated 46107020578 queued. Les groupes CI remplacent progressivement les pending obsolètes (pas d'annulation rétroactive des anciens runs sans groupe). Jauge stricte 50,0% ; quatre modules non fermés, qualification finale, matériel et conservation/stockage réels restent nécessaires. Aucun main/déploiement/migration de production.


## Laboratoire matériel GitHub Actions — environnement virtualisé
Reprise 1014549. Demande utilisateur : utiliser GitHub pour créer un environnement de recettes des réserves matérielles. b7642dc : nouveau workflow .github/workflows/naxa-security-hardware.yml dédié à la branche, AndroidJUnitRunner et matrice API 26 (min SDK) / 35 (target SDK) sur émulateurs KVM, build et instrumentation réelle des primitives de production : QR bitmap/ZXing aller-retour et refus malformé/image vide ; GPS précision/fraîcheur/coordonnées, injection Android LocationManager et refus mock ; ContentResolver local, SHA-256, altération et limites 0/256 Kio/256 Kio+1 ; inventaire des capacités caméra/GPS/NFC/BLE. Sept tests obligatoires par appareil, XML JUnit contrôlé (aucun skipped admis), script refuse un appareil physique, artefacts logs/inventaire 14 jours. Lot EDGE : tests existants de passerelle signée, panne, reprise, rejeu, refus de commandes et contrôle des reçus. faad703 : lot caméra Chromium avec flux getUserMedia Y4M synthétique (QR décodé, flux vide ignoré, fermeture des pistes, aucune écriture serveur), garde supplémentaire côté instrumentation interdisant l'injection sur téléphone physique. Quatre jobs logiques, deux appareils virtuels, 14 exécutions Android attendues, 2 scénarios caméra et 7 tests de passerelle. Aucun déploiement ni migration ni secret. Documentation et reproduction docs/naxa-security/contracts/hardware-lab/README.md. Première exécution 46107524211 (b7642dc) ; version complète faad703 : 46107593923 pending. Actions générales de la révision : NAXA SECURITY — isolated database contract 46107593861 pending; Famille NAXA — validation groupée 0.1/0.2 46107593860 queued; NAXA SECURITY — parallel recipes 50 46107593864 pending; NAXA SECURITY — virtual hardware laboratory 46107593923 pending; NAXA SECURITY — responsive and native gate 46107593823 pending; NAXA SECURITY — Chromium replay isolated 46107593909 pending; NAXA SECURITY — business contracts B1–B6 46107593866 pending. Résultat matériel VIRTUAL uniquement, aucun PASS déduit de la file. Les antennes NFC/RFID/BLE, GPS satellite, qualité optique réelle, matériel de vidéosurveillance et alarmes physiques restent à qualifier sur appareils autorisés ; aucun lecteur NFC/RFID/BLE implémenté dans cette passe. Jauge 50% inchangée jusqu'aux preuves et réserves complètes.


## Qualification indépendante du laboratoire virtuel
Reprise cba8835. Exécution locale Node 22.16.0 des deux suites EDGE, 7/7 PASS, 0 échec, 0 skipped. Quatre blobs vérifiés avec git hash-object et comparés aux SHA retournés par GitHub pour cba8835 : edge-runtime.mjs 5a2081e6140e9a2c3ed4cb261d4e0dabcb7b7420 ; edge-runtime.test.mjs 69b07300b75fa03442e10539e4a87ab2014da0c8 ; gateway-contract.mjs b25e948c6a38efa78aad51063ea0ba668cc077d3 ; gateway-contract.test.mjs ca06d580115e2e3b77f0d09a2291bf748eb55540. Recettes : signature/binding, rejet invalide, reçu, file durable et redémarrage, expiration, ingress et HTTPS. Ce sont des tests logiciels de passerelle virtuelle, aucun équipement réel ni serveur déployé. Contrôle préliminaire caméra locale tenté : navigateur présent mais navigation localhost bloquée ERR_BLOCKED_BY_ADMINISTRATOR ; aucun succès caméra revendiqué. Pas de SDK Android/adb/Gradle/KVM disponible localement. Action reactivecircus/android-emulator-runner@v2.35.0 vérifiée existante et paramètres compatibles dans action.yml. GitHub : ancien run 46107524211 android-lab (35) queued; android-lab (26) queued; edge-lab queued ; version complète 46107593923 pending. Aucun échec instrumenté disponible à corriger ; pas de nouveau commit déclencheur pour ne pas engorger les runners. Qualification virtuelle : 7/23 prouvées indépendamment, 16 non qualifiées (14 Android, 2 caméra Chromium). Pas de vert global, jauge projet 50% inchangée, aucune modification main ni déploiement.
