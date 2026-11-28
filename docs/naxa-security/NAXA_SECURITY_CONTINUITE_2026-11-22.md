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
