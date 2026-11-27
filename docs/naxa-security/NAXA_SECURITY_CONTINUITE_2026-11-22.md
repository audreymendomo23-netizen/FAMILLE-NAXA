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
