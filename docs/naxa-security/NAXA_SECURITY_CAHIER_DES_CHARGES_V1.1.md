# NAXA SECURITY 360° — Cahier des charges fonctionnel et technique

**Version :** 1.1  
**Date d'approbation du périmètre :** 22 novembre 2026  
**Produit :** NAXA SECURITY  
**Dépôt de référence :** FAMILLE-NAXA  
**Statut du document :** périmètre fonctionnel validé par le fondateur ; conception et construction technique à réaliser et à qualifier  
**Langue maîtresse :** français ; versions d'interface prévues en français, anglais et Fulfulde  
**Nature de l'offre :** logiciel SaaS/ERP, connectivité, supervision et gestion à distance d'équipements tiers. NAXA ne fournit pas les équipements et n'exploite pas de service de surveillance humaine.


> **Traçabilité documentaire :** le dépôt historique `audreymendomo23-netizen/NAXA` contient le fichier `Cahier_des_charges_09_NAXA_Security.pdf` (branche `main`, blob Git `7997b33c11d8136009f04b0382416bfae350e7a3`, 69 202 octets). Son contenu intégral n'a pas pu être extrait dans cette session car le connecteur GitHub ne restitue pas les fichiers PDF binaires. La comparaison page par page avec ce PDF reste donc une tâche de continuité explicite ; cette version ne prétend pas certifier qu'aucune exigence historique n'a été omise. Le cahier présent est la baseline fonctionnelle consolidée à utiliser sans attendre pour cadrer la construction, sous réserve de cette réconciliation documentaire.

---

## 0. Règles de lecture et gouvernance

Ce cahier est la référence fonctionnelle et technique de NAXA SECURITY 360°. Il rassemble les décisions déjà retenues, les extensions validées le 22 novembre 2026 et les exigences de réalisation/recette. La version 1.1 harmonise le libellé commercial « Essentiel » avec la décision écrite du fondateur et conserve la séparation entre périmètre validé et réalisation à prouver.

### 0.1 Statuts

- **[V] Validé :** décision du fondateur ou cadrage antérieur confirmé.
- **[E] Exigence :** comportement obligatoire à réaliser.
- **[P] À préciser avant commercialisation ou mise en service :** valeur quantitative, fournisseur, délai, quota, règle opérationnelle ou preuve qui n'a pas encore été arrêtée.
- **[C] Condition de conformité :** exigence dépendant d'un fabricant, d'un intégrateur qualifié, d'une autorité ou d'un texte applicable.
- **[N] Non démontré :** fonctionnalité non considérée comme développée ou opérationnelle tant que les preuves ne sont pas produites.

Une exigence décrite ici ne prouve pas son implémentation. Une compilation ne prouve ni la compatibilité d'un matériel, ni le bon fonctionnement d'une alarme, ni l'efficacité d'une IA, ni l'isolement des données.

### 0.2 Ordre de priorité documentaire

1. Les décisions explicites du fondateur consignées dans ce cahier et les décisions ultérieures datées.
2. Le présent cahier NAXA SECURITY 360° V1.0 pour le périmètre produit.
3. Le document de continuité NAXA SECURITY pour l'état de construction, les preuves, les risques et l'ordre de reprise.
4. Les standards, notices et contrats fabricants applicables à chaque équipement.
5. Les obligations légales et réglementaires applicables dans le pays d'installation.

Toute évolution du périmètre, des prix, des droits ou des exigences de sécurité doit être ajoutée dans un registre de décisions, avec date, auteur, ancienne règle, nouvelle règle, motif et impact.

### 0.3 Gouvernance de développement

Méthode obligatoire : **audit → contradictions → cause racine → conception/correction → test et preuve → documentation → état**.

- Aucun secret, mot de passe, jeton, clé privée ou donnée réelle de client dans le dépôt public.
- Aucun déploiement, aucune migration Supabase Production, aucune publication APK et aucune ouverture d'accès matériel sans autorisation spécifique.
- Ne pas modifier les applications NAXA existantes pour contourner les contrats.
- Réutiliser les composants communs seulement après audit de compatibilité et tests de non-régression.
- Toute fonction de sécurité physique doit échouer de manière sûre et conserver l'autonomie des systèmes de sécurité certifiés.

---

# PARTIE I — VISION, POSITIONNEMENT ET PÉRIMÈTRE

## 1. Vision du produit

NAXA SECURITY est une plateforme logicielle de sécurité physique intelligente, de vidéosurveillance, de détection, de supervision à distance et de gestion opérationnelle des personnes, des bâtiments, des équipements et des incidents.

La solution doit pouvoir se connecter à une gamme étendue d'équipements existants, de plusieurs marques et fabricants, à travers des standards ouverts, des API/SDK propriétaires, des passerelles et des interfaces d'entrées/sorties documentées. Le catalogue de compatibilité doit être vérifié par modèle, version de firmware, protocole et fonction.

NAXA fournit :
- l'application Android native ;
- l'application Web/PWA distincte ;
- les logiciels et services Cloud autorisés ;
- le logiciel local NAXA EDGE ;
- les connecteurs, adaptateurs et interfaces logicielles ;
- la configuration logicielle et l'appairage des équipements compatibles ;
- la formation initiale à l'utilisation du logiciel ;
- le support logiciel et la maintenance des composants NAXA ;
- les outils de pilotage, rapports, alertes, automatisations et IA.

NAXA ne fournit pas :
- les caméras, NVR/DVR, détecteurs, alarmes, lecteurs, badges, traceurs GPS, sirènes, interphones, routeurs, serveurs ou autres matériels ;
- les travaux d'électricité, de câblage, de génie civil ou de pose du matériel ;
- la certification d'un système incendie tiers ;
- la télésurveillance humaine opérée par NAXA ;
- une intervention physique sur site en réponse à une alerte ;
- un service de police, de sécurité privée, de secours ou de lutte contre l'incendie.

Le matériel est acheté, détenu et maintenu par le client ou fourni par son installateur/intégrateur tiers. NAXA rend possible son exploitation logicielle à distance lorsque les interfaces, droits, réseaux et capacités de l'appareil le permettent.

## 2. Objectifs stratégiques

1. Accepter une gamme très large de matériels de sécurité sans enfermer le client dans une marque.
2. Réutiliser les caméras, enregistreurs, alarmes, capteurs, détecteurs, contrôleurs et traceurs déjà possédés par le client.
3. Réunir vidéo, audio, GPS, présence, contrôle d'accès, alarmes, détection incendie, rondes, incidents et maintenance.
4. Assurer un traitement local prioritaire, avec une architecture hybride Edge/Cloud.
5. Continuer à protéger localement le site lorsque l'accès Internet ou le Cloud est indisponible.
6. Centraliser le pilotage de plusieurs sites, bâtiments, zones et organisations.
7. Augmenter la qualité de détection grâce à l'IA, sans substituer les décisions algorithmiques aux dispositifs de sécurité certifiés ni aux responsables humains.
8. Fournir un ERP complet des opérations de sécurité dans l'offre Professional.
9. Mutualiser les services transversaux autorisés de FAMILLE-NAXA : authentification, organisations, droits, abonnements, paiements, notifications, support, livechat, IA, langues, audit et synchronisation.
10. Intégrer progressivement NAXA SECURITY aux autres applications de la famille à travers des contrats API et des autorisations explicites.

## 3. Décisions commerciales validées

### 3.1 Formules et prix

Les trois formules commerciales retenues sont **Essentiel, Business et Professional**. Il n'existe pas de quatrième formule Enterprise dans le catalogue tarifaire de référence V1.0.

| Formule | Paiement mensuel | Paiement annuel | Couverture validée |
|---|---:|---:|---|
| Essentiel | **5 000 FCFA/mois** | **60 000 FCFA/an** | Un seul site |
| Business | **20 000 FCFA/mois** | **200 000 FCFA/an** | Multisite au niveau de l'organisation |
| Professional | **50 000 FCFA/mois** | **500 000 FCFA/an** | Tous les produits et services NAXA SECURITY et ERP complet |

Les prix sont exprimés en FCFA. Le catalogue doit les conserver comme montants de référence approuvés, avec devise technique XAF si le moteur financier partagé l'exige.

### 3.2 Règle annuelle

- Essentiel : 60 000 FCFA pour douze mois. Ce prix équivaut à douze mensualités de 5 000 FCFA ; aucun mois gratuit supplémentaire n'est implicite.
- Business : 200 000 FCFA pour douze mois de service, sur la base de dix mensualités de 20 000 FCFA.
- Professional : 500 000 FCFA pour douze mois de service, sur la base de dix mensualités de 50 000 FCFA.
- Le système doit afficher distinctement durée de service, montant facturé, échéance et avantage annuel.
- Aucun renouvellement ne doit modifier rétroactivement une période déjà payée.
- Les renouvellements et prélèvements automatiques sont soumis au consentement et à l'intégration réelle du fournisseur de paiement.
- Le moteur de tarification doit être versionné, auditable et testé.

### 3.3 Périmètre fonctionnel des formules

**Essentiel — un site**
- Une organisation cliente avec un établissement/site couvert.
- Socle de sécurité : parc d'appareils, caméras et enregistreurs compatibles, capteurs compatibles, événements et alertes de base, gestion des utilisateurs du site, historique, état des équipements et consultation autorisée.
- Détection fumée/incendie uniquement par intégration compatible à un dispositif ou système tiers approprié ; la protection incendie locale ne dépend jamais de l'abonnement Cloud.
- Fonctions GPS et présence selon entitlements du catalogue Essentiel, avec quotas à définir.
- Nombre maximal de caméras, appareils, utilisateurs, stockage, conservation et fréquence GPS : **[P] à chiffrer et publier dans le catalogue de quotas**. Aucun quota chiffré n'est inventé par ce cahier.

**Business — multisite**
- Une organisation avec plusieurs établissements/sites et une supervision consolidée.
- Gestion des responsables par site, droits et périmètres régionaux.
- Gestion multisite des caméras, capteurs, détecteurs incendie, alarmes, accès, GPS, présence, visiteurs, rondes et incidents selon les entitlements.
- Règles d'alertes par site, zone, type d'appareil et responsable.
- Tableau de bord consolidé et rapports par site/organisation.
- Plusieurs sites sont inclus dans le principe de la formule ; le plafond chiffré d'appareils, d'utilisateurs, de stockage, de passerelles et les éventuelles extensions de capacité sont **[P] à établir sur la base des coûts réels**. Le client ne souscrit pas un abonnement distinct pour chaque site.

**Professional — tous les produits et services SECURITY et ERP complet**
- Accès à l'ensemble du catalogue fonctionnel NAXA SECURITY.
- ERP de sécurité complet : organisation, sites, bâtiments, zones, utilisateurs, équipes, postes, affectations, visiteurs, accès, appareils, actifs, contrats, rondes, incidents, interventions, maintenance, pièces, historiques, documents, rapports, coûts opérationnels et pilotage.
- Modules vidéo, audio, GPS, présence, patrouille, accès, alarmes, fumée/incendie, environnement, SOS, déclenchements distants, IA avancée, maintenance et intégrations.
- Administration avancée et délégation de droits.
- Intégrations/API et connecteurs spécifiques selon faisabilité et devis éventuel.
- « Tous les produits et services » signifie l'ensemble des produits et services du catalogue **NAXA SECURITY**, et non l'achat gratuit des autres applications de FAMILLE-NAXA ou de leurs abonnements.
- Le droit fonctionnel complet ne signifie pas stockage, bande passante, nombre de caméras, nombre de flux simultanés ou puissance IA illimités. Les limites de capacité doivent être clairement publiées et les extensions identifiées avant souscription.

### 3.4 Extensions

Le cadrage commercial antérieur retient l'achat d'extensions à la carte avec une majoration additive de **20 % du montant de l'abonnement principal par extension**. Cette règle est conservée sous réserve de définir précisément l'unité d'extension dans le catalogue :

- caméra/canal vidéo supplémentaire ;
- passerelle EDGE supplémentaire ;
- capacité de stockage ou durée de rétention supplémentaire ;
- pack de calcul IA ;
- pack GPS ;
- pack de contrôle d'accès ;
- pack de capteurs et alarmes ;
- capacité additionnelle par site ou groupe de sites ;
- connecteur constructeur spécifique ;
- autres extensions activables.

Le catalogue doit éviter de facturer deux fois la même capacité. Il doit présenter le montant de chaque extension, son unité, son effet sur les quotas, sa durée et le calcul des 20 %. La formule exacte et le cumul des extensions sont des règles moteur testées et historisées.

### 3.5 Essai, installation, formation et support

- Période d'essai retenue : 14 jours, avec accès aux fonctions de la formule choisie dans les limites techniques et de sécurité configurées.
- L'installation logicielle, le paramétrage, l'intégration, la formation initiale et les déplacements peuvent faire l'objet de frais uniques distincts de l'abonnement.
- Le mapping des anciens frais d'installation associés à quatre formules historiques doit être réconcilié avec le nouveau catalogue à trois formules avant publication commerciale. Aucun montant d'installation n'est inventé ici.
- NAXA ne vend pas et ne livre pas le matériel. Les travaux matériels sont réalisés par le client ou un prestataire compétent.
- Le support NAXA porte sur le logiciel, les connecteurs NAXA et les fonctions compatibles documentées. Une intervention matérielle est attribuée au fabricant ou à l'installateur concerné.

### 3.6 Moyens de paiement

Moyens retenus dans le périmètre commercial :
1. Orange Money ;
2. MTN Mobile Money ;
3. Virement bancaire ;
4. Facturation B2B avec rapprochement.

Les cartes bancaires ne sont pas incluses dans le périmètre initial validé.

Le système doit prendre en charge :
- création de transaction ;
- référence unique et idempotente ;
- statut pending ;
- vérification serveur auprès du prestataire ;
- webhook authentifié ;
- confirmation effective ;
- activation ou renouvellement des entitlements ;
- facture/reçu ;
- historique ;
- échec, expiration, annulation et remboursement ;
- rapprochement bancaire ou B2B ;
- preuves et audit.

Une capture d'écran, un reçu saisi manuellement ou un numéro de transaction non vérifié ne peut pas activer un abonnement. Une saisie administrative de secours doit rester identifiée, justifiée et auditée, sans se substituer à la confirmation réelle.

---

# PARTIE II — ARCHITECTURE FONCTIONNELLE ET MODULES

## 4. Cartographie générale des modules

| ID | Module | Responsabilité principale |
|---|---|---|
| NS-01 | SECURITY CORE | Organisations, utilisateurs, sites, droits et configuration |
| NS-02 | VIDEO | Caméras, DVR/NVR, flux, enregistrements et recherche |
| NS-03 | AUDIO | Audio entrant/sortant, interphonie et analyse acoustique autorisée |
| NS-04 | GPS | Géolocalisation, trackers, véhicules, personnes et actifs |
| NS-05 | PRESENCE | Pointage, présence, horaires, affectations et visiteurs |
| NS-06 | PATROL | Ronde, itinéraire, checkpoint, contrôle et compte rendu |
| NS-07 | ACCESS | Porte, badge, lecteur, contrôleur et autorisation d'accès |
| NS-08 | ALARMS | Intrusion, panique, sabotage, alarmes et sirènes |
| NS-09 | REMOTE ACTIONS | Commandes sécurisées à distance et scénarios |
| NS-10 | AI SECURITY | Détection, corrélation, priorisation et synthèse IA |
| NS-11 | FIRE & SMOKE | Détecteurs de fumée, incendie, centrales et événements incendie |
| NS-12 | ENVIRONMENT | Gaz, CO, chaleur, eau, température, humidité et risques techniques |
| NS-13 | VISITORS | Pré-enregistrement, badge, autorisation et historique visiteurs |
| NS-14 | VEHICLES | Véhicules, accès, stationnement et suivi de flotte autorisé |
| NS-15 | SOS & PERSONAL SAFETY | Bouton d'urgence, homme à terre et protection de personne isolée |
| NS-16 | INCIDENTS | Déclaration, qualification, actions, responsables, preuves et clôture |
| NS-17 | CONTROL 360 | Centre de supervision multisite et multi-organisation |
| NS-18 | EDGE | Connectivité matérielle, traitement local, règles et fonctionnement dégradé |
| NS-19 | COMPATIBILITY | Catalogue, matrice, essais et statut de compatibilité |
| NS-20 | ASSET & MAINTENANCE | Inventaire, état, maintenance, interventions et garantie |
| NS-21 | ERP OPERATIONS | Équipes, planning, tâches, contrats et gestion opérationnelle |
| NS-22 | REPORTING & BI | KPI, rapports, exports et indicateurs |
| NS-23 | SUBSCRIPTIONS | Plans, tarifs, quotas, entitlements et extensions |
| NS-24 | PAYMENTS | Mobile Money, banque, factures et rapprochement |
| NS-25 | LIVECARE | Livechat, support, agent humain, audio/vidéo et partage d'écran |
| NS-26 | NOTIFICATIONS | Push, SMS, e-mail, WhatsApp et alertes sonores |
| NS-27 | AI ASSISTANT | Assistant utilisateur et aide opérateur |
| NS-28 | LANGUAGE / I18N | Français, anglais et Fulfulde |
| NS-29 | ADMINISTRATION | Administration produit et centrale de configuration |
| NS-30 | SECURITY AUDIT | Journaux, traçabilité et contrôle |
| NS-31 | STORAGE & EVIDENCE | Stockage, intégrité, conservation et export autorisé |
| NS-32 | OFFLINE & SYNC | Persistance locale, outbox, idempotence et résolution des conflits |
| NS-33 | INTEGRATIONS | API et interconnexion autorisée avec les applications de la famille |
| NS-34 | BACKUP & RECOVERY | Sauvegardes, reprise et restauration testée |
| NS-35 | PARTNERS | Fabricants, installateurs, intégrateurs et sociétés tierces |

Les modules forment une plateforme unique. Ils ne doivent pas devenir 35 applications indépendantes.

## 5. SECURITY CORE — organisations, comptes et gouvernance

### 5.1 Organisations et hiérarchie

Le système prend en charge :
- particulier/domicile ;
- PME mono-site ;
- organisation multisite ;
- groupe national ou régional ;
- institution/administration ;
- opérateur de sécurité privée gérant plusieurs organisations clientes.

Hiérarchie cible :

Organisation → région → site/établissement → bâtiment → étage/niveau → zone → appareil/point de contrôle.

Une organisation peut avoir plusieurs sites. Chaque site peut avoir plusieurs bâtiments, étages, zones, sous-zones, accès et équipements. Les bâtiments peuvent être représentés sur plan avec des icônes d'appareils, itinéraires, issues, zones de danger et points de rassemblement.

Les organisations clientes gérées par un prestataire de sécurité doivent rester strictement séparées. Un même compte opérateur peut recevoir une délégation explicite vers plusieurs clients, sans accès transversal implicite.

### 5.2 Architecture des comptes et profils

Profils fonctionnels cibles :
- propriétaire/promoteur de l'organisation ;
- administrateur organisation ;
- directeur général ;
- responsable régional ;
- responsable de site ;
- responsable sécurité ;
- opérateur de supervision ;
- agent de sécurité ;
- superviseur de ronde ;
- responsable des accès ;
- gestionnaire RH/présence ;
- gestionnaire technique/maintenance ;
- responsable informatique ;
- auditeur en lecture contrôlée ;
- visiteur/utilisateur externe à accès limité ;
- partenaire/installateur avec accès de mission limité.

Les fonctions peuvent être combinées si la matrice RBAC le permet. Un contexte actif doit être choisi et un même utilisateur ne peut jamais acquérir des droits simplement parce qu'il appartient à une autre application.

### 5.3 RBAC et périmètres

Le droit effectif dépend au minimum :
- identité ;
- organisation ;
- site ;
- bâtiment/zone ;
- fonction ;
- permission ;
- état du compte ;
- contrat et délégation ;
- type d'objet ;
- opération demandée ;
- état et niveau de sensibilité de l'incident.

Toute permission sensible est contrôlée côté serveur/RLS. Masquer un bouton dans l'interface ne constitue pas une sécurité.

Exemples de droits distincts :
- consulter le direct ;
- lire un enregistrement ;
- exporter une preuve ;
- consulter le GPS d'une personne ;
- consulter les positions d'un véhicule ;
- créer une alerte ;
- acquitter une alerte ;
- fermer un incident ;
- lancer une sirène ;
- diffuser un message vocal ;
- commander une porte ;
- armer/désarmer une zone ;
- gérer un détecteur ;
- isoler un appareil pour maintenance ;
- réinitialiser une centrale incendie (action normalement réservée à la procédure matérielle/technicien autorisé et exclue des actions Cloud ordinaires).

### 5.4 Journal des accès

Tracer les connexions, changements de rôle, consultations de vidéo/audio, lectures d'enregistrements, exports, téléchargements, commandes distantes, acquittements, modifications de règle, suppressions, délégations et accès de support. Les logs doivent inclure acteur, objet, organisation, site, action, date serveur, origine, résultat et identifiant de corrélation.

---

## 6. NAXA VIDEO — vidéosurveillance

### 6.1 Types de matériels

La plateforme doit viser une gamme étendue :
- caméras IP fixes, dômes, bullet et mini-dômes ;
- caméras Wi-Fi compatibles ;
- PTZ motorisées ;
- panoramiques/fisheye et multi-capteurs ;
- caméras thermiques ;
- caméras extérieures et industrielles ;
- caméras de faible luminosité/infrarouge ;
- caméras avec stockage local ;
- encodeurs vidéo analogique/IP ;
- DVR, XVR et NVR ;
- serveurs VMS tiers via API ;
- caméras embarquées ou mobiles via protocoles testés ;
- caméras avec audio/microphone intégré ;
- caméras analytiques capables de fournir des métadonnées.

### 6.2 Protocoles et connecteurs

Priorités :
- ONVIF Profile T pour la vidéo IP avancée, métadonnées, événements, PTZ, entrées/sorties et audio bidirectionnel lorsque supportés ;
- ONVIF Profile G pour la gestion/récupération d'enregistrements sur les appareils compatibles ;
- ONVIF Profile M pour événements et métadonnées analytiques lorsque supportés ;
- RTSP/RTP en complément pour les flux, lorsque l'appareil ne fournit pas d'interface normalisée plus riche ;
- API/SDK spécifiques fabricant documentés et autorisés ;
- API d'enregistreurs/VMS ;
- passerelles et encodeurs pour matériels hérités, après vérification.

La conformité ONVIF ne garantit pas que toutes les fonctions optionnelles d'un produit sont disponibles. Chaque modèle, firmware et fonction doit être testé. Un équipement peut être certifié pour une famille de fonctions et ne pas proposer audio, PTZ, événements ou enregistrement dans la configuration retenue.

### 6.3 Fonctions vidéo

- découverte/appairage de l'appareil ;
- configuration réseau et identifiants protégés ;
- test de connectivité ;
- flux direct multi-caméras ;
- mosaïque configurable ;
- PTZ et préréglages lorsque disponibles ;
- zoom numérique et optique si exposé par le matériel ;
- événements mouvement/tamper ;
- zones et lignes virtuelles ;
- masques de confidentialité ;
- réglages autorisés de qualité ;
- gestion des canaux DVR/NVR ;
- état de connexion et de santé ;
- lecture des enregistrements lorsque API/ONVIF/stockage le permettent ;
- recherche par heure, canal, événement et métadonnées ;
- signets et séquences d'incident ;
- export et partage sécurisé de preuves ;
- conservation locale ou tierce ;
- diagnostic de bande passante et latence ;
- gestion des pannes et notifications.

### 6.4 Flux distant

Le flux RTSP reste prioritairement sur le réseau local ou entre Edge et appareil. Pour le Web et l'accès mobile distant, prévoir un relais ou une passerelle sécurisée qui convertit/relaye les flux via un transport adapté (par exemple WebRTC pour le direct à faible latence), avec authentification éphémère. Ne jamais exposer directement une caméra sur Internet par ouverture de ports improvisée.

Le stockage et la rétention dépendent des capacités du client, de son NVR/serveur et des entitlements. NAXA peut indexer, lire et gérer les enregistrements accessibles, mais ne doit pas promettre qu'un appareil incapable d'enregistrer pourra fournir un historique vidéo.

---

## 7. NAXA AUDIO — audio, interphonie et alertes sonores

### 7.1 Entrées audio

- microphones IP ;
- audio intégré aux caméras ;
- interphones et stations d'appel ;
- centrales et capteurs acoustiques ;
- événements de sirènes ;
- équipements d'analyse de bruit.

Fonctions : audio bidirectionnel lorsque compatible, réception d'événements, classification de sons, détection de bris de verre, alarme acoustique, appel à l'aide et anomalie sonore. La classification acoustique doit être privilégiée à l'écoute ou à la transcription systématique des conversations.

L'audio-surveillance est désactivée par défaut. Son activation dépend de la finalité, de l'information des personnes, des règles applicables, des droits et de la configuration validée.

### 7.2 Sorties audio

- sirène ;
- haut-parleur IP ;
- interphone ;
- annonce locale ;
- messages vocaux préparés ;
- message d'avertissement ;
- message d'évacuation via un système de sonorisation/alarme adapté ;
- communication opérateur/interphone.

### 7.3 Alertes sur terminaux

- sons distincts par niveau ;
- synthèse vocale locale ;
- vibration ;
- répétition ;
- accusé de réception ;
- mode silencieux personnel, sans neutraliser les alarmes locales de sécurité ;
- langue et modèle vocal par destinataire lorsque disponible.

Les messages d'urgence en français, anglais et Fulfulde doivent être relus et approuvés. Un message vocal critique doit rester préenregistré et stocké localement quand il est déclenché par un système local.

---

## 8. NAXA GPS — géolocalisation et suivi

### 8.1 Sources de localisation

- GPS/GNSS des smartphones autorisés ;
- traceurs GPS/GNSS dédiés ;
- boîtiers de suivi de véhicules ;
- balises Bluetooth ;
- passerelles BLE ;
- équipements IoT de localisation ;
- géolocalisation réseau lorsque disponible ;
- systèmes de flotte tiers via API.

### 8.2 Cas d'usage

**Personnes**
- position pendant une mission/vacation autorisée ;
- équipes d'intervention ;
- géolocalisation ponctuelle SOS ;
- historique limité à une finalité et à une durée ;
- pointage de proximité ;
- sortie de zone autorisée ;
- perte de signal ;
- arrêt inhabituel ;
- contrôle de trajet prévu.

**Véhicules**
- position en temps réel ;
- historique de trajet ;
- vitesse et arrêt ;
- itinéraire et déviation ;
- geofencing ;
- entrée/sortie de site ;
- immobilisation ;
- perte d'alimentation ou de signal si le traceur expose ces états ;
- alertes de mouvement hors horaires ;
- rapports de distance/temps.

**Actifs et équipements mobiles**
- localisation d'un actif ;
- sortie de périmètre ;
- mouvement non autorisé ;
- perte de connexion ;
- historique et affectation.

### 8.3 Fonctions cartographiques

- carte générale et vue satellite selon fournisseur ;
- geofences circulaires ou polygones ;
- zones multiples et horaires ;
- itinéraires ;
- checkpoints ;
- positions temps réel ;
- historique ;
- regroupement par organisation/site/équipe ;
- alertes et annotations ;
- plans intérieurs pour étages et bâtiments.

La précision GPS ne doit pas être présentée comme une localisation intérieure exacte. Le positionnement à l'intérieur des bâtiments dépend de technologies spécifiques (BLE/UWB/Wi-Fi) et des équipements installés.

### 8.4 Protection et règles de suivi

- suivi de personnes uniquement selon finalité définie ;
- suivi lié au service, à la mission ou à l'urgence, pas à une surveillance invisible sans fin ;
- information des personnes ;
- périodes activables/désactivables ;
- consentement ou base légale appropriée lorsque requis ;
- accès limité par rôle/site ;
- rétention configurée ;
- historique d'accès ;
- SOS et localisation d'urgence protégés ;
- retrait du suivi lorsque l'autorisation ou la mission prend fin.

---

## 9. NAXA PRESENCE — pointage et présence

### 9.1 Méthodes

- QR code dynamique ;
- NFC/RFID ;
- badge et lecteur ;
- BLE/beacon ;
- géofence/GPS lors d'un pointage autorisé ;
- événements de contrôle d'accès ;
- terminal biométrique tiers, uniquement si l'intégration, la base légale et les conditions de traitement sont validées ;
- pointage manuel avec justification et approbation.

Le pointage doit distinguer une action d'identification, une entrée réelle enregistrée par un contrôleur, une proximité de zone et une estimation d'occupation vidéo. Ces signaux ne sont pas interchangeables.

### 9.2 États

Attendu, présent, en retard, en pause, sortie temporaire, en déplacement, absent, sorti, statut incertain et anomalie à vérifier.

### 9.3 Parcours de pointage

1. L'utilisateur s'authentifie.
2. Le système vérifie son affectation, le site, la zone et l'horaire.
3. Le terminal génère une preuve de pointage (QR, NFC, BLE, GPS ou contrôleur).
4. Le serveur/local Edge vérifie le jeton, la fraîcheur et l'absence de rejeu.
5. L'événement est enregistré avec heure serveur, appareil, organisation, site, zone et méthode.
6. L'utilisateur reçoit une confirmation.
7. Une anomalie est envoyée au responsable selon les règles.
8. Le rapport de présence est mis à jour après synchronisation.

### 9.4 Gestion RH opérationnelle

- collaborateurs ;
- équipes ;
- affectations ;
- fonctions ;
- horaires ;
- vacations ;
- pauses ;
- heures supplémentaires à valider ;
- absences et retards ;
- permutation ;
- validation ;
- export et historique.

NAXA SECURITY ne remplace pas la paie réglementaire ; il fournit les données d'activité et d'horaires. Le traitement paie/fiscal reste dans l'outil métier approprié et sous validation professionnelle.

---

## 10. NAXA PATROL — rondes et agents

- création de parcours ;
- points de contrôle QR/NFC/BLE/GPS ;
- séquence et fenêtre de temps ;
- agent affecté ;
- remplaçant ;
- début/fin ;
- passage confirmé ;
- passage manquant ;
- retard ;
- sortie d'itinéraire ;
- arrêt inhabituel ;
- demande d'assistance ;
- photo/observation autorisée ;
- incident attaché à un checkpoint ;
- rapport et signature électronique selon règles ;
- consolidation multi-sites.

Une ronde complète ne doit pas être déclarée simplement parce que le téléphone s'est déplacé. Chaque checkpoint doit fournir la preuve attendue, avec tolérances et gestion des faux positifs.

---

## 11. NAXA ACCESS — contrôle d'accès

Équipements :
- lecteurs NFC/RFID ;
- claviers ;
- contrôleurs de portes ;
- gâches et serrures électriques ;
- tourniquets ;
- barrières ;
- lecteurs biométriques tiers ;
- interphones/visiophones ;
- terminaux de visite ;
- contrôleurs multi-portes.

Fonctions :
- profils d'accès ;
- badges et identifiants ;
- visiteurs ;
- horaires ;
- zones ;
- groupes d'accès ;
- entrée/sortie ;
- porte maintenue ouverte ;
- porte forcée ;
- refus ;
- anti-passback si matériel compatible ;
- accès temporaire ;
- révocation à distance ;
- journal d'accès ;
- intégration incendie et priorité à l'évacuation via le système certifié.

Les issues de secours ne doivent jamais être bloquées par une règle NAXA. Les comportements de déverrouillage incendie sont conçus et validés par l'intégrateur du système de sécurité incendie, selon les normes et exigences locales.

---

## 12. NAXA ALARMS & SOS

- intrusion ;
- ouverture de porte/fenêtre ;
- mouvement ;
- vibration ;
- bris de vitre ;
- sabotage ;
- perte d'alimentation ;
- bouton panique ;
- alerte silencieuse ;
- sirène ;
- alarme technique ;
- alarme personnelle ;
- alerte de zone ;
- alerte de présence non autorisée ;
- historique, acquittement, escalade et clôture.

Le bouton SOS doit pouvoir être déclenché depuis l'application, un wearable ou un périphérique compatible. Il transmet l'identité et la position disponible, l'heure, le site, le contexte et les contacts configurés. L'utilisateur peut annuler une fausse alerte dans une fenêtre et selon une procédure contrôlée, mais le signal reste journalisé.

NAXA n'assure pas l'intervention humaine. L'organisation cliente définit ses contacts, opérateurs, partenaires et procédures d'urgence. Une transmission automatique à un service public ou centre de secours n'est activée qu'après vérification de la possibilité juridique, technique et contractuelle.

---

## 13. NAXA REMOTE ACTIONS — déclenchements à distance

### 13.1 Commandes possibles

- activer sirène ou sortie relais compatible ;
- diffuser un message vocal ;
- allumer un éclairage de sécurité ;
- orienter une caméra PTZ ;
- activer un scénario ;
- commander une sortie auxiliaire ;
- déclencher une communication interphone ;
- verrouiller/déverrouiller un accès uniquement selon droits et règles de sûreté ;
- armer/désarmer un système d'intrusion selon son API et ses règles ;
- déclencher un signal d'urgence ;
- lancer un message de confinement/évacuation validé par le client et les professionnels compétents.

### 13.2 Contrôle des commandes

Chaque commande comporte :
- auteur et rôle ;
- organisation/site/zone ;
- équipement cible ;
- action et paramètres ;
- raison obligatoire pour une action sensible ;
- vérification serveur de l'autorisation ;
- authentification renforcée selon risque ;
- identifiant unique ;
- nonce/expiration anti-rejeu ;
- état de transmission ;
- réponse technique de l'appareil ;
- état final confirmé ou non confirmé ;
- journal et éventuel incident.

États : brouillon, demande de validation, autorisée, en attente réseau, envoyée, reçue, exécutée, échouée, expirée, annulée.

### 13.3 Double validation

Les actions critiques peuvent exiger deux personnes distinctes. La double validation est configurable par organisation, site, plage horaire, équipement et criticité.

### 13.4 Protection contre les actions dangereuses

- aucune commande ne doit désactiver une protection incendie locale ;
- aucune commande générale ne doit neutraliser les alarmes incendie ;
- aucune commande ne doit retarder un signal incendie pour attendre l'IA ou le Cloud ;
- le déverrouillage des issues en situation d'incendie doit suivre le contrôleur incendie et l'ingénieur/installeur habilité ;
- le déclenchement d'une extinction automatique (gaz, mousse, sprinklers) est exclu des commandes ordinaires NAXA ; toute intégration spécialisée exige un système certifié, une étude de sécurité, un fabricant et un intégrateur habilités, avec logique indépendante et procédures physiques ;
- la désactivation, le silence, l'isolement ou le reset d'un circuit incendie ne sont pas exposés comme un bouton utilisateur ordinaire.

---

# PARTIE III — DÉTECTION FUMÉE ET INCENDIE

## 14. Oui, NAXA peut intégrer les détecteurs de fumée et d'incendie

La compatibilité dépend du matériel et de son interface. NAXA peut gérer une grande variété d'appareils sans fabriquer ni fournir les détecteurs, à condition de s'interfacer avec des systèmes appropriés et de tester chaque modèle.

**Règle fondamentale : NAXA est la couche logicielle de supervision et d'intégration. Le détecteur, la centrale et les dispositifs d'alarme incendie certifiés restent le système local de sécurité des personnes. NAXA ne devient pas le contrôleur incendie certifié par le seul fait qu'il reçoit un signal.**

### 14.1 Familles de matériels à prendre en charge

**Détecteurs de fumée**
- optiques/photoélectriques ;
- ionisation lorsque légalement autorisés et maintenables ;
- aspiration ;
- détecteurs de fumée par faisceau ;
- détecteurs multisensoriels ;
- détecteurs avec relais/contact de sortie ;
- détecteurs radio adressables via leur centrale ;
- détecteurs autonomes connectés via passerelle, en tant que couche complémentaire.

**Détecteurs d'incendie**
- détecteurs thermiques à seuil fixe ;
- détecteurs de chaleur différentielle ;
- détecteurs combinés fumée/chaleur ;
- détecteurs multisensoriels fumée/CO/chaleur ;
- détecteurs de flamme UV/IR ;
- câble linéaire thermique ;
- détection par aspiration ;
- détecteurs vidéo de flamme/fumée, uniquement comme technologie complémentaire et évaluée pour son risque d'erreur ;
- systèmes spécifiques pour cuisines, locaux techniques, parkings, entrepôts, data centers et environnements industriels.

**Centrales et systèmes incendie**
- centrales conventionnelles par zones ;
- centrales adressables ;
- systèmes multi-boucles ;
- panneaux de contrôle incendie ;
- systèmes d'alarme vocale/évacuation ;
- panneaux de détection par aspiration ;
- systèmes d'extinction avec état de supervision, sans commande à distance non autorisée ;
- répétiteurs, annonciateurs, modules d'entrée/sortie et passerelles réseau.

**Équipements annexes**
- sirènes et flashs ;
- diffuseurs vocaux ;
- déclencheurs manuels ;
- indicateurs d'action ;
- modules de relais ;
- alimentations secourues ;
- capteurs de débit/pression/vannes si le système expose des états ;
- contacts de portes coupe-feu et clapets, lorsqu'une intégration est disponible ;
- détecteurs de défaut électrique et température des tableaux, si matériels compatibles.

### 14.2 Moyens d'intégration

Priorité, selon équipement :
1. API IP/SDK officiellement documenté du fabricant de la centrale ;
2. protocole industriel ou bâtiment exposé et documenté, tel que BACnet ou Modbus lorsqu'il est prévu par le fabricant ;
3. passerelle certifiée du fabricant ;
4. module d'interface supervisé fourni par l'installateur/constructeur, avec sorties d'état et contacts secs adaptés ;
5. contact sec/entrée supervisée depuis une centrale incendie vers une passerelle Edge, après étude technique ;
6. passerelle radio/IoT certifiée ou validée pour le contexte ;
7. connecteur spécialisé tiers.

Une interface contact sec peut fournir un état binaire ou plusieurs états selon le module. Elle ne doit pas être improvisée, raccordée directement au détecteur sans schéma ou utilisée pour perturber le circuit de sécurité. L'intégration se fait sur une interface prévue par le fabricant et installée par une personne compétente.

Zigbee, Z-Wave, Wi-Fi et MQTT peuvent être utilisés pour certains détecteurs connectés grand public ou passerelles, mais un détecteur connecté grand public ne remplace pas un système incendie conforme requis par le bâtiment. Le statut de compatibilité et le domaine d'emploi doivent être explicites.

### 14.3 Fonctions spécifiques fumée

- état normal ;
- préalarme fumée ;
- alarme fumée ;
- niveau/valeur analogique si exposé ;
- défaut capteur ;
- contamination/encrassement si exposé ;
- batterie faible ;
- perte radio ;
- perte de connexion ;
- sabotage ;
- appareil retiré ;
- maintenance/essai ;
- défaut de boucle/zone ;
- retour à la normale ;
- historique et rapport.

### 14.4 Fonctions spécifiques incendie

- état normal ;
- préalarme ;
- feu confirmé par centrale ;
- activation déclencheur manuel ;
- alarme générale ;
- défaut de zone/boucle ;
- court-circuit/circuit ouvert ;
- alimentation principale absente ;
- batterie de secours faible ;
- appareil désactivé/isolé ;
- défaut de transmission ;
- activation sirène/flash ;
- état évacuation ;
- défaut d'un équipement annexe ;
- supervision de la maintenance ;
- rétablissement après intervention.

Les états d'un détecteur, les états de la centrale et les états calculés par l'IA doivent rester distincts. Une alarme confirmée par la centrale ne peut pas être abaissée par l'IA.

### 14.5 Niveaux d'événement incendie

- **Information :** appareil ajouté, maintenance planifiée, test programmé.
- **Défaut/supervision :** panne, batterie faible, perte de boucle, isolé, sabotage, communication interrompue.
- **Préalarme :** niveau de fumée/chaleur ou événement préalarme fourni par le système.
- **Alarme incendie :** signal d'alarme fourni par le détecteur/centrale ou événement validé selon la logique de la centrale.
- **Alarme générale/évacuation :** état fourni par le système local autorisé.

NAXA conserve la priorité et l'état d'origine du système incendie. L'IA peut ajouter un résumé, un contexte, une caméra à ouvrir ou les contacts à notifier, mais elle ne change pas la classe de sécurité de l'alarme.

### 14.6 Interaction de bout en bout — scénario fumée

**Préconditions :**
- détecteur de fumée ou centrale compatible ;
- emplacement et zone connus ;
- interface de communication validée ;
- passerelle locale NAXA EDGE active ;
- règles de notification et contacts configurés ;
- dispositif local de signalisation installé et validé séparément.

**Séquence :**
1. Le détecteur de fumée mesure un événement et transmet l'information à son panneau/contrôleur.
2. Le panneau applique sa logique locale certifiée et déclenche le signal local requis.
3. Le panneau ou la passerelle expose un événement fumée à NAXA EDGE via une interface approuvée.
4. EDGE timestamp l'événement, identifie l'organisation, le site, le bâtiment, l'étage, la zone, l'appareil et la source.
5. Le moteur de règles crée un événement de sécurité, sans attendre le Cloud.
6. La carte du site ouvre la zone et affiche les issues, zones voisines et équipements concernés.
7. NAXA affiche la caméra correspondante si elle existe et si l'utilisateur a le droit de la consulter.
8. Le moteur de corrélation peut rapprocher l'événement d'une hausse de température, d'un détecteur voisin, d'une alarme CO ou d'un événement vidéo ; ces signaux ajoutent du contexte sans retarder la sirène locale.
9. Les personnes désignées reçoivent push, son, SMS/e-mail/WhatsApp selon leur profil, les canaux autorisés et les capacités disponibles.
10. Les destinataires peuvent accuser réception. L'accusé n'arrête pas l'alarme locale.
11. Si aucun responsable n'acquitte dans le délai configuré, une escalade est envoyée aux contacts secondaires.
12. Un incident fumée est créé avec chronologie, sources, statuts, actions et preuves autorisées.
13. L'intervention physique et la vérification du lieu relèvent du client, de ses agents ou des services de secours.
14. Le retour à la normale est enregistré seulement lorsque le système source signale l'état rétabli ; une vérification/inspection peut rester obligatoire.
15. Le rapport de clôture conserve l'origine, les accusés, les actions et le motif de clôture.

### 14.7 Interaction de bout en bout — scénario incendie

**Préconditions :** centrale incendie ou système adapté, détecteurs et alarmes installés et maintenus, schéma des zones, interface compatible, contacts, consignes et plan d'évacuation validés.

**Séquence :**
1. Un détecteur (fumée, chaleur, flamme, multisensoriel ou déclencheur manuel) signale un événement.
2. La centrale locale décide de son état (préalarme, alarme de zone ou alarme générale) selon sa configuration certifiée.
3. La centrale active sans dépendance à NAXA les dispositifs locaux prévus : sirènes, flashs, sonorisation et sorties de sécurité selon l'installation.
4. NAXA EDGE reçoit l'état et transmet l'événement à l'application et au Cloud si disponibles.
5. NAXA ouvre la vue du bâtiment, l'étage et la zone, avec le plan et la position du détecteur.
6. Les caméras autorisées de la zone peuvent s'afficher en contexte, mais ne conditionnent jamais l'alarme.
7. Les messages de notification/évacuation prédéfinis peuvent être proposés et, lorsqu'ils sont raccordés au système d'alarme vocale approuvé, déclenchés selon la matrice d'autorisation.
8. Le responsable reçoit une alerte prioritaire ; les contacts de secours ou partenaires tiers peuvent être affichés.
9. Le système trace les accusés de réception et escalade les alertes non acquittées.
10. Les portes/contrôles d'accès se comportent selon la logique incendie certifiée : les issues ne sont pas bloquées et les fonctions d'évacuation gardent la priorité.
11. Les actions de sécurité ordinaires (intrusion, surveillance) sont subordonnées aux règles incendie.
12. NAXA crée un incident de niveau critique, conserve l'heure de l'alarme et la chronologie.
13. Les opérateurs consultent uniquement les données autorisées.
14. La remise en service se fait après inspection et réarmement selon les instructions du fabricant et du responsable compétent.
15. NAXA consigne le rétablissement, le responsable, les défauts éventuels, les interventions et le rapport final.

### 14.8 Modes dégradés et panne Cloud

- La centrale incendie et les dispositifs locaux continuent à fonctionner sans Internet.
- Le signal local ne dépend jamais d'une notification push ou d'un appel API Cloud.
- EDGE conserve les événements localement et les synchronise ensuite.
- Si EDGE est arrêté, la centrale incendie reste autonome.
- La perte de communication est signalée comme un défaut distinct de l'alarme incendie.
- Une alarme reçue pendant une coupure doit être synchronisée avec son heure d'origine, son ordre et son identifiant.
- Une panne NAXA ne doit pas empêcher l'alarme locale de fonctionner.

### 14.9 Commandes incendie à distance — limites strictes

NAXA peut afficher des états et transmettre certaines commandes auxiliaires lorsque le fabricant et l'installateur les autorisent : annonce vocale, commande d'affichage, signal externe, éclairage ou notification.

NAXA ne doit pas exposer dans l'interface utilisateur ordinaire :
- désactivation générale du système incendie ;
- silence global empêchant les avertisseurs locaux ;
- isolement d'une zone sans procédure physique/compétente ;
- reset Cloud automatique après alarme ;
- arrêt non autorisé de ventilation ou d'extinction ;
- commande de vannes, sprinklers, gaz ou systèmes d'extinction sans étude et dispositif certifié.

Le silence, le reset ou l'isolement doivent être effectués selon la procédure du fabricant, par une personne autorisée, avec traçabilité et validation adaptée. Aucune IA ne prend ces décisions.

### 14.10 Test, maintenance et preuve

- mode test clairement signalé ;
- destinataires de test ;
- procédure de mise en test autorisée ;
- avertissement contre les fausses alertes publiques ;
- contrôle de batterie ;
- état de communication ;
- échéance de maintenance ;
- test fonctionnel selon fabricant ;
- contrôle de l'intégrité des circuits ;
- historique d'entretien ;
- rapport de défaut ;
- rapport de mise en service ;
- validation par installateur/technicien compétent.

Les essais utilisent les méthodes et outils prescrits par le fabricant et la norme applicable. Ne pas provoquer de fumée, flamme ou rejet de gaz réel hors procédure professionnelle contrôlée.

---

# PARTIE IV — IA, ALERTES ET INCIDENTS

## 15. NAXA AI SECURITY ENGINE

### 15.1 Analyses vidéo

- détection de personne/véhicule ;
- franchissement de ligne ;
- intrusion de zone ;
- occupation et comptage anonyme ;
- stationnement prolongé ;
- objet laissé ou retiré ;
- mouvement inhabituel ;
- sabotage/caméra masquée ;
- caméra déplacée ;
- comportement ou mouvement incompatible avec un horaire/zone, avec règles transparentes ;
- analyse thermique/flamme lorsque capteur approprié ;
- recherche d'événements dans les métadonnées.

### 15.2 Analyses audio

- sirène ;
- bris de verre ;
- choc ;
- appel à l'aide/cri lorsque faisable et juridiquement autorisé ;
- bruit industriel anormal ;
- signal acoustique d'un équipement ;
- événement acoustique persistant.

Ne pas transcrire automatiquement les conversations ni identifier les personnes par la voix. Les fonctions d'analyse doivent être paramétrées, justifiées et limitées.

### 15.3 Corrélation multimodale

Exemples :
- ouverture de porte + mouvement vidéo + badge refusé ;
- caméra déconnectée + perte d'alimentation + alarme de sabotage ;
- mouvement + sortie de zone + absence de pointage valide ;
- préalarme fumée + température en hausse + deuxième détecteur ;
- présence dans une zone interdite + horaire fermé ;
- GPS d'un agent + checkpoint de ronde non atteint ;
- traceur véhicule + mouvement hors zone ;
- alarme intrusion et déclenchement manuel.

La corrélation ne doit pas retarder un système local certifié. Elle sert à enrichir le contexte, prioriser et aider les responsables.

### 15.4 Alertes

Niveaux :
- P1 : événement critique nécessitant une action immédiate selon le plan du client ;
- P2 : événement grave ou fortement suspect ;
- P3 : anomalie importante ou maintenance ;
- P4 : information, statistique ou action non urgente.

La gravité et la confiance IA sont séparées. Une alarme incendie issue de la centrale reste une alarme incendie même si l'IA n'a pas d'image ou classe l'image comme incertaine.

### 15.5 Gestion anti-bruit

- déduplication ;
- regroupement par incident ;
- fenêtre de corrélation ;
- règles par site/zone/horaire ;
- seuils configurables et historisés ;
- suppression des répétitions non pertinentes sans masquer la source ;
- maintien des alarmes critiques ;
- accusés et escalades ;
- mesure des faux positifs et faux négatifs ;
- retour opérateur pour amélioration.

### 15.6 Assistant IA

- expliquer un événement ;
- résumer le journal du site ;
- rechercher les séquences par métadonnées ;
- proposer une checklist d'intervention ;
- préparer un rapport ;
- signaler les équipements en maintenance ;
- analyser les tendances ;
- aider à configurer des règles ;
- guider l'utilisateur ;
- proposer des actions réversibles et autorisées.

L'assistant ne déclenche pas seul les commandes sensibles et ne prétend pas avoir vérifié une personne, une intrusion ou un incendie lorsque les données ne le prouvent pas.

---

## 16. NAXA VISITORS, VEHICLES et PERSONAL SAFETY

### 16.1 Visiteurs

- pré-enregistrement ;
- identité et informations nécessaires ;
- rendez-vous/raison ;
- QR temporaire ;
- badge ;
- personne hôte ;
- site/zone autorisé ;
- entrée et sortie ;
- expiration automatique ;
- liste des visiteurs présents ;
- visiteur non sorti ;
- historique et rapport.

### 16.2 Véhicules

- flotte autorisée ;
- plaque si la lecture est disponible et légitime ;
- QR/badge véhicule ;
- entrée/sortie ;
- barrières et parkings ;
- places/aires ;
- historique de circulation ;
- alerte véhicule inconnu ;
- GPS de flotte ;
- rapport.

La reconnaissance de plaque est une fonction sensible qui nécessite une finalité et des conditions de traitement appropriées.

### 16.3 Sécurité personnelle

- bouton SOS ;
- géolocalisation d'urgence ;
- alerte d'immobilité ;
- détection de chute lorsque l'appareil supporte la fonction ;
- détection de perte de verticalité si le capteur le permet ;
- alerte homme à terre ;
- check-in de travailleur isolé ;
- rappel de sécurité ;
- vérification de situation ;
- escalade si aucune réponse ;
- historique.

La chute ou l'immobilité détectée par un téléphone n'est pas une preuve médicale. Il faut présenter une alerte à confirmer.

---

# PARTIE V — ERP COMPLET ET PILOTAGE 360°

## 17. ERP de sécurité — périmètre Professional

- gestion des organisations, contrats et sites ;
- bâtiments, plans et zones ;
- inventaire des équipements ;
- profils, équipes et affectations ;
- planning, vacations et horaires ;
- présence et pointage ;
- rondes et checkpoints ;
- visiteurs et accès ;
- alarmes et règles ;
- événements et incidents ;
- demandes/interventions ;
- ordres de travail ;
- maintenance préventive/corrective ;
- planning d'entretien ;
- documents, garanties et licences ;
- pièces et consommables de maintenance ;
- fournisseurs/installateurs tiers ;
- contrats de maintenance ;
- tickets support ;
- rapports ;
- suivi des coûts opérationnels ;
- indicateurs par site et organisation ;
- historique d'audit ;
- abonnements et facturation ;
- export PDF/CSV/XLSX selon disponibilité.

La gestion financière opérationnelle peut enregistrer budgets, coûts et engagements, mais ne remplace pas une comptabilité certifiable SYSCOHADA ou la paie réglementaire.

## 18. Incidents et interventions

Chaque incident contient :
- identifiant ;
- source ;
- heure de première détection ;
- état courant ;
- priorité ;
- organisation/site/bâtiment/zone ;
- appareil/source ;
- personnes responsables ;
- description ;
- pièces et preuves ;
- historique ;
- actions ;
- notification/accusé ;
- intervenant ;
- commentaire et diagnostic ;
- décision et motif de clôture.

États : nouveau, en qualification, confirmé, assigné, en cours, en attente d'information, en attente d'un tiers, résolu, clôturé, réouvert.

Une alerte automatique ne doit pas être confondue avec un incident confirmé. Le système conserve la distinction entre événement brut, incident créé, confirmation humaine, action et résolution.

## 19. Maintenance et santé des appareils

- disponibilité ;
- heartbeat ;
- version ;
- firmware ;
- signal réseau ;
- température interne lorsque disponible ;
- alimentation ;
- stockage ;
- statut d'enregistrement ;
- santé du capteur ;
- batterie ;
- qualité de transmission ;
- dernière communication ;
- historique de défaut ;
- maintenance préventive ;
- ticket et ordre de travail ;
- contact du fournisseur ;
- garantie/fin de support ;
- rapport de diagnostic.

NAXA ne met pas à jour le firmware d'un équipement si le fabricant ne fournit pas une procédure sûre et autorisée. Toute opération de mise à jour nécessite sauvegarde de configuration, fenêtre de maintenance et retour arrière.

---

# PARTIE VI — COMPATIBILITÉ ET CONNECTIVITÉ MATÉRIELLE

## 20. Principe général : architecture multi-marque, multi-fabricant

Le moteur de compatibilité est fondé sur des adaptateurs interchangeables. L'application métier ne doit pas connaître les détails propriétaires de chaque appareil.

### 20.1 Familles à prendre en charge

| Famille | Matériels visés | Interfaces possibles |
|---|---|---|
| Vidéo | caméras IP, PTZ, dômes, NVR/DVR, encodeurs, VMS | ONVIF, RTSP/RTP, API/SDK, passerelle |
| Audio | microphones, haut-parleurs, interphones, sirènes | ONVIF, SIP/API, RTSP, I/O, API constructeur |
| Intrusion | détecteurs, centrales, claviers, sirènes | API, IP, bus fabricant, contact supervisé, passerelle |
| Fumée/incendie | détecteurs, centrales, alarmes, déclencheurs manuels | API fabricant, passerelle certifiée, I/O supervisée, protocole documenté |
| Accès | lecteurs, portes, tourniquets, contrôleurs | ONVIF Access Control si applicable, API, Wiegand/OSDP via contrôleur adapté, relais |
| GPS | trackers véhicules/personnes/actifs | API HTTP, TCP/UDP documenté, MQTT, protocole fabricant |
| IoT | température, eau, gaz, vibration, énergie | MQTT, Modbus, BACnet, Zigbee/Z-Wave via gateway |
| Présence | badge, NFC, QR, BLE, biométrie tiers | NFC/RFID, BLE, QR, API, événements contrôleur |
| Environnement | fumée, CO, chaleur, fuite, humidité | contact/centrale, API, BACnet/Modbus, gateway |
| Interphonie | visiophones et contrôle d'entrée | SIP, ONVIF, API fabricant |
| Sécurité personnelle | SOS, wearable, chute | BLE, GPS, API, événements appareil |

Ces familles d'interface sont des objectifs d'intégration. Chaque protocole dépend du modèle, de la licence, du fabricant et de la conformité. Un appareil ne devient pas compatible par le seul fait qu'il utilise Wi-Fi ou qu'il annonce une API.

### 20.2 NAXA Compatibility Registry

Pour chaque modèle :
- fabricant ;
- gamme ;
- modèle ;
- révision matérielle ;
- firmware ;
- protocole ;
- version du connecteur ;
- fonctions supportées ;
- fonctions conditionnelles ;
- limites ;
- modèle d'authentification ;
- type de flux ;
- fréquence d'événement ;
- exigences réseau ;
- essai de sécurité ;
- essais fonctionnels ;
- date du dernier test ;
- version de test ;
- testeur ;
- statut de certification interne ;
- note et preuve.

Statuts :
- **Certifié NAXA :** testé sur matériel/firmware défini, matrice complète vérifiée ;
- **Validé :** fonctions principales testées ;
- **Partiel :** certaines capacités seulement ;
- **Expérimental :** connecteur en test, non vendu comme stable ;
- **Non pris en charge :** aucune garantie d'interopérabilité.

NAXA ne revendique pas une certification officielle ONVIF ou fabricant pour un produit qui ne l'a pas obtenue. Le statut « certifié NAXA » signifie uniquement recette interne sur le périmètre décrit.

### 20.3 Compatibilité et limites

- modèle inconnu : mode découverte uniquement, sans activer de commande ;
- firmware non testé : avertissement ;
- fonctions non exposées : non affichées comme disponibles ;
- API propriétaire inaccessible : statut partiel ou non pris en charge ;
- clé/licence nécessaire : doit être fournie légalement par le client ou fabricant ;
- absence d'enregistrement sur caméra : renvoi au NVR ou serveur tiers ;
- flux RTSP sans événements : vidéo disponible, IA locale possible si capacité suffisante, commandes absentes ;
- appareil hors réseau : état non joignable, pas de fausse promesse de contrôle.

---

## 21. NAXA EDGE — passerelle locale

### 21.1 Rôle

NAXA EDGE est le composant local entre les équipements et les applications NAXA.

Il assure :
- découverte et connectivité ;
- stockage sécurisé des identifiants d'appareils ;
- adaptateurs protocolaires ;
- normalisation des événements ;
- traitement vidéo/audio local selon droits ;
- exécution des règles locales approuvées ;
- relais sécurisé des flux ;
- file d'attente d'événements ;
- cache de configuration ;
- gestion des commandes ;
- mode hors connexion ;
- santé et diagnostic ;
- synchronisation signée ;
- mise à jour contrôlée.

### 21.2 Déploiement

Le logiciel EDGE peut être installé sur les ordinateurs/serveurs du client ou sur une machine dédiée fournie par lui ou son intégrateur. NAXA ne fournit pas cette machine.

Environnements cibles à tester : Linux x86_64 et ARM64, Windows selon connecteurs disponibles, virtualisation/conteneurs lorsque les capacités matérielles et l'accès réseau le permettent. La matrice réellement supportée sera publiée après essais. Ne pas affirmer la compatibilité d'un environnement non testé.

### 21.3 Sécurité EDGE

- identité unique de passerelle ;
- certificat/jeton par équipement ;
- secrets chiffrés ;
- rotation ;
- mises à jour signées ;
- démarrage contrôlé ;
- segmentation réseau ;
- pare-feu ;
- liste de flux autorisés ;
- audit ;
- détection d'altération ;
- sauvegarde de configuration ;
- retour arrière ;
- révocation distante ;
- accès de support temporaire, tracé et consenti.

### 21.4 Architecture hybride

- Vidéo/audio prioritairement local.
- Les flux complets ne sont pas envoyés au Cloud par défaut.
- Le Cloud reçoit les événements, métadonnées, états, alertes et extraits explicitement autorisés.
- La visualisation distante passe par un relais sécurisé et authentifié.
- Les règles de sécurité locale critiques fonctionnent indépendamment du Cloud.
- Une panne Internet n'arrête ni la centrale incendie, ni les alarmes locales, ni l'enregistrement assuré par le matériel client.

---

# PARTIE VII — MODULES TRANSVERSAUX FAMILLE NAXA

## 22. Réutilisation transversale — sans duplication aveugle

NAXA SECURITY doit consommer les services communs de FAMILLE-NAXA après audit et validation de chaque contrat. L'existence d'un package ne prouve pas sa maturité opérationnelle.

### 22.1 Identité et Auth

- création/activation de compte selon gouvernance ;
- connexion ;
- OTP si activé ;
- récupération et changement mot de passe ;
- renouvellement de session ;
- PIN local ;
- biométrie locale Android ;
- appareils actifs ;
- révocation ;
- historique ;
- protection anti-bruteforce ;
- MFA renforcée pour commandes sensibles.

Les identités peuvent être communes au niveau technique, mais les autorisations et profils sont isolés par application et organisation.

### 22.2 Profil et préférences

- informations personnelles minimales ;
- photo/avatar ;
- langue ;
- thème ;
- notifications ;
- appareils ;
- sécurité ;
- sessions ;
- support ;
- abonnement ;
- factures ;
- consentements et préférences de confidentialité.

### 22.3 Organisations et multi-sites

Réutiliser les contrats d'organisations/sites après vérification des champs, règles RLS, relations, délégations et capacités à gérer bâtiments/zones/appareils. Si les modèles transversaux sont insuffisants, étendre de manière additive et versionnée, sans détourner des tables spécifiques à une autre application.

### 22.4 Billing Core

Réutiliser le catalogue partagé, le calcul des échéances, les versions tarifaires, les périodes, entitlements, essais, extensions, prorata si adopté, historique et règles annuelles. Le catalogue NAXA SECURITY demeure propre à SECURITY. Les prix sont ceux définis en section 3.

### 22.5 Paiements

Réutiliser les adaptateurs autorisés Orange Money, MTN Mobile Money, banque et facturation B2B, après vérification du fournisseur, clés, webhooks, idempotence et rapprochement. NAXA SECURITY ne doit pas inventer de confirmation de paiement.

### 22.6 Notifications

Canaux : push/FCM, Web Push, SMS, WhatsApp Business, e-mail et alertes audio locales. Les préférences définissent canaux, horaires et escalades. Les alertes P1/feu ont des règles prioritaires qui ne sont pas supprimées par le mode silencieux du téléphone ; la signalisation locale demeure indépendante.

### 22.7 Livechat et support NAXA LIVECARE

- FAQ ;
- chatbot ;
- conversation agent humain ;
- transfert bot→agent ;
- ticket ;
- audio/vidéo selon fournisseur ;
- partage écran avec permission explicite ;
- pièces jointes privées ;
- historique ;
- satisfaction ;
- SLA et priorité ;
- escalade technique ;
- affectation au bon support produit ;
- distinction entre incident de sécurité physique et demande de support logiciel.

Le support NAXA n'est pas un opérateur de télésurveillance et ne répond pas à la place des contacts d'urgence du client.

### 22.8 IA Gateway et assistant

Toute IA distante passe par une passerelle serveur versionnée. Les secrets ne sont jamais dans l'application. Les appels sont bornés, journalisés, surveillés et facturés selon entitlements. Les traitements vidéo/audio locaux doivent être évalués selon capacités du client et finalités.

### 22.9 Langues — trois langues obligatoires

- français (fr-CM) ;
- anglais (en-CM) ;
- Fulfulde (ff-CM).

Traduction intégrale attendue pour :
- écrans et navigation ;
- paramètres ;
- alertes ;
- notifications ;
- e-mails ;
- SMS et modèles WhatsApp ;
- tickets/support ;
- reçus et factures ;
- rapports et exports ;
- assistant IA ;
- messages vocaux ;
- messages d'évacuation et consignes critiques.

Le Fulfulde doit être rédigé et relu par des personnes compétentes, avec validation terminologique du vocabulaire sécurité/incendie. Les messages d'évacuation doivent être préparés et approuvés avant leur activation. Un choix de langue dans les préférences ne vaut pas preuve que les ressources sont complètes.

### 22.10 Offline & synchronisation

- Room ou stockage local adapté Android ;
- stockage EDGE local ;
- outbox/inbox ;
- identifiants stables ;
- idempotence ;
- retry avec backoff ;
- ordre des événements ;
- horodatage local et serveur ;
- conflits ;
- état de synchronisation ;
- reprise ;
- purge contrôlée ;
- contrôle anti-rejeu ;
- resynchronisation sans doublon.

Les commandes à distance ont une expiration courte. Une commande sensible en attente pendant une perte de réseau ne doit pas être exécutée après reconnexion si sa fenêtre d'autorisation a expiré.

### 22.11 Stockage, sauvegarde et preuves

- objets privés ;
- URL signées à durée limitée ;
- chiffrement ;
- intégrité/hash ;
- politique de conservation ;
- export tracé ;
- partage contrôlé ;
- sauvegarde ;
- restauration ;
- test périodique de restauration ;
- séparation données de clients ;
- gestion des demandes légales et droits.

### 22.12 Administration centrale

La console centrale FAMILLE-NAXA peut superviser la disponibilité de l'application, l'état de souscription, les métriques techniques et le support selon ses droits. Elle ne doit pas offrir un accès libre aux vidéos, audios, positions GPS ou identités des clients. Tout accès support exceptionnel doit être limité, temporaire, justifié et audité.

---

## 23. Interconnexions avec les autres applications

Les applications suivantes peuvent se connecter à SECURITY par API et autorisation :
- NAXA : pharmacies et locaux autorisés ;
- NAXA HOTEL : bâtiments, espaces communs, accès et incidents ;
- NAXA SERVICES : locaux, interventions et maintenance ;
- LOYABLE : bâtiments locatifs, espaces communs et caméras autorisées ;
- BOOTIK : boutiques, réserves et entrepôts ;
- ZIPPLE : bars/restaurants et établissements ;
- CAMPUS237 : établissements et campus ;
- autres solutions du portefeuille, selon contrat approuvé.

Règles :
- SECURITY demeure la source de vérité des appareils, flux, événements, droits vidéo et journaux de sécurité.
- Une application consommatrice n'affiche que les ressources déléguées.
- Un rôle ou abonnement d'une application ne donne pas automatiquement le droit d'accès à SECURITY.
- Les tokens sont limités à l'organisation, au site, à l'objet et à l'opération.
- Toute intégration dispose de contrats versionnés, tests d'accès négatifs et journalisation.
- Les données de sécurité ne doivent pas être recopiées en masse dans l'application consommatrice.

---

# PARTIE VIII — UX, ÉCRANS ET PARCOURS

## 24. Navigation principale

Proposition d'organisation des écrans :
1. Accueil / Dashboard ;
2. Live / Vidéo ;
3. Carte / GPS ;
4. Alertes ;
5. Présence ;
6. Rondes ;
7. Accès et visiteurs ;
8. Détecteurs / Incendie ;
9. Appareils ;
10. Incidents ;
11. Maintenance ;
12. Rapports ;
13. Organisation / Sites ;
14. Abonnement ;
15. Livechat / Support ;
16. Profil / Paramètres.

La navigation s'adapte au rôle et à l'abonnement. Aucun écran masqué par l'UI ne remplace une autorisation serveur.

## 25. Dashboard 360°

- statut général des sites ;
- alarmes actives ;
- incidents critiques ;
- caméras en ligne/hors ligne ;
- centrale incendie et zones ;
- détecteurs en défaut ;
- état des passerelles EDGE ;
- personnes présentes selon les droits ;
- rondes en cours et en retard ;
- alertes GPS ;
- accès refusés ;
- appareils en maintenance ;
- stockage disponible ;
- incidents non acquittés ;
- actions récentes ;
- abonnements/quotas ;
- support en cours.

Le tableau ne doit pas afficher de nombres fictifs. Toute donnée doit avoir une source, une date de rafraîchissement et un état de fraîcheur.

## 26. Écrans détaillés

**Video Wall**
- mosaïque ;
- filtre organisation/site/zone ;
- état des caméras ;
- direct ;
- PTZ ;
- événement ;
- lecture ;
- favori ;
- export autorisé.

**Map & GPS**
- sites ;
- geofences ;
- véhicules ;
- équipements ;
- personnes autorisées ;
- rondes ;
- SOS ;
- historique.

**Alerts Center**
- priorité ;
- type ;
- site ;
- source ;
- heure ;
- état ;
- accusé ;
- escalade ;
- action ;
- incident lié.

**Fire & Smoke Center**
- état de chaque centrale ;
- zones ;
- détecteurs ;
- préalarme ;
- alarme ;
- défaut ;
- isolement ;
- maintenance ;
- test ;
- plan du bâtiment ;
- chronologie.

**Devices**
- inventaire ;
- compatibilité ;
- firmware ;
- santé ;
- passerelle ;
- connecteur ;
- identifiants protégés ;
- maintenance.

**Presence & Patrol**
- équipes ;
- pointages ;
- horaires ;
- checkpoints ;
- rondes ;
- anomalies ;
- validation.

**Remote Actions**
- liste autorisée ;
- confirmation ;
- double validation ;
- état d'exécution ;
- audit ;
- annulation possible si non exécutée et encore révocable.

---

# PARTIE IX — SÉCURITÉ, PRIVACY ET CONFORMITÉ

## 27. Sécurité des applications et appareils

- TLS pour les communications ;
- authentification forte ;
- contrôle d'accès par défaut refusé ;
- chiffrement des secrets au repos ;
- stockage secret Android protégé ;
- rotation/révocation ;
- appareils enrôlés ;
- limitation des tentatives ;
- journal d'audit ;
- protection contre rejeu ;
- validation stricte des commandes ;
- séparation des réseaux ;
- VPN/tunnel sécurisé ou relais authentifié pour EDGE ;
- aucun port vidéo public ;
- durcissement des passerelles ;
- mise à jour signée ;
- inventaire de versions ;
- analyse vulnérabilité ;
- test d'intrusion ;
- plan de réponse ;
- sauvegarde et restauration.

### 27.1 Protection des données personnelles

La solution doit intégrer privacy by design et privacy by default :
- finalités documentées ;
- minimisation ;
- information ;
- bases légales/consentement selon cas ;
- durées de rétention ;
- droits des personnes ;
- traitement des données sensibles ;
- localisation des données et transferts ;
- contrats responsable/sous-traitant ;
- contrôle d'accès ;
- audit des consultations ;
- réponse à incident ;
- suppression/anonymisation lorsque requise.

Les vidéos, audio, GPS, biométrie et données de présence nécessitent une analyse particulière. La loi camerounaise n° 2024/017 du 23 décembre 2024 relative à la protection des données personnelles est une référence obligatoire pour l'exploitation au Cameroun. Les exigences exactes, autorisations/formalités, rôles et textes d'application doivent être confirmés par un conseil juridique camerounais et l'autorité compétente avant production.

### 27.2 Incendie et responsabilité

- La centrale incendie et son matériel demeurent l'autorité locale de détection/alarme.
- NAXA est une interface logicielle d'intégration, pas un organisme de certification.
- Les installations, raccordements, essais et maintenances du système incendie sont confiés aux professionnels compétents.
- Le client demeure responsable du plan de sécurité, des consignes et des personnes de secours qu'il désigne.
- NAXA ne garantit pas une intervention humaine.
- Les fonctions IA vidéo/acoustique sont complémentaires ; elles ne remplacent pas les détecteurs requis ni une centrale incendie adaptée.

---

# PARTIE X — TESTS, RECETTE ET CRITÈRES DE SORTIE

## 28. Stratégie de qualification

La validation comporte plusieurs couches :

1. Tests unitaires des domaines, règles et connecteurs.
2. Tests contractuels API et formats d'événements.
3. Tests d'intégration sur simulateurs.
4. Tests sur appareils physiques multi-marques.
5. Tests de sécurité et de cloisonnement.
6. Tests hors connexion et réseau instable.
7. Tests de charge, vidéo et stockage.
8. Tests IA sur jeux de données contrôlés et réalistes.
9. Tests d'alarmes incendie par procédures fabricant/technicien.
10. Tests Android et Web/PWA séparés.
11. Tests restaurations.
12. Recette utilisateur.
13. Revue conformité et exploitation.

### 28.1 Recette matériel

Pour chaque appareil :
- identifier le modèle exact ;
- relever firmware ;
- vérifier licence ;
- confirmer interface disponible ;
- connecter en réseau isolé ;
- tester authentification ;
- tester les fonctions annoncées ;
- couper/reprendre réseau ;
- vérifier sécurité ;
- mesurer latence ;
- vérifier événements ;
- valider commande si autorisée ;
- produire rapport et preuves ;
- attribuer statut de compatibilité.

### 28.2 Recette fumée/incendie

Les tests doivent être réalisés sur une installation de recette ou lors d'une intervention planifiée, par une personne compétente et selon les procédures du fabricant. Ne pas produire un incendie ou un risque réel pour simuler une alerte.

Contrôler :
- réception d'une préalarme ;
- réception d'une alarme ;
- identification de zone et détecteur ;
- réception de défaut ;
- perte de communication ;
- perte alimentation ;
- batterie faible si simulable ;
- notification locale ;
- notification Cloud ;
- fonctionnement lors d'une coupure Internet ;
- resynchronisation ;
- accusé réception ;
- escalade ;
- rapport ;
- retour à la normale ;
- non-interférence avec la centrale locale.

### 28.3 Recette GPS/présence/rondes

- position valide ;
- position imprécise ;
- perte GPS ;
- permission retirée ;
- arrière-plan ;
- batterie basse ;
- géofence ;
- QR expiré/rejoué ;
- badge inconnu ;
- badge révoqué ;
- pointage concurrent ;
- hors connexion ;
- conflit ;
- synchronisation ;
- ronde manquée ;
- SOS ;
- autorisation expirée.

### 28.4 Recette commande distante

- accès non autorisé rejeté ;
- double validation ;
- commande expirée ;
- rejeu bloqué ;
- appareil hors ligne ;
- réponse tardive ;
- commande reçue sans exécution ;
- état confirmé ;
- journal complet ;
- annulation ;
- comportement fail-safe ;
- priorité incendie.

### 28.5 Critères VERT GLOBAL

NAXA SECURITY ne peut être déclaré VERT GLOBAL que si :
- toutes les fonctionnalités du périmètre approuvé sont développées ou explicitement exclues par une décision tracée ;
- toutes les formules et règles d'abonnement sont testées ;
- les paiements et entitlements sont réellement connectés et vérifiés ;
- les appareils certifiés dans le catalogue ont des preuves de tests ;
- les alarmes locales fonctionnent indépendamment de NAXA ;
- les scénarios fumée/incendie sont testés avec centrale et matériel adaptés ;
- les commandes distantes sont sécurisées et leurs états prouvés ;
- les droits et l'isolation inter-organisations sont testés côté serveur ;
- le GPS et les présences sont recettés ;
- les langues FR/EN/Fulfulde sont complètes et relues ;
- le support/livechat est réellement connecté ;
- Android et Web/PWA sont testés distinctement ;
- les notifications réelles sont reçues ;
- les tests de charge, restauration et sécurité sont passés ;
- les intégrations famille sont prouvées ;
- les réserves sont fermées ou formellement acceptées avec risque ;
- les rapports de recette et documents de continuité sont mis à jour.

Aucun pourcentage de complétude basé sur le nombre d'écrans ne vaut preuve d'achèvement.

---

# PARTIE XI — FEUILLE DE ROUTE DE CONSTRUCTION

## 29. Ordre de réalisation

### Lot 0 — Audit et conception détaillée
- audit monorepo ;
- architecture Android/Web/EDGE ;
- modèles organisation/site/zone ;
- contrats de services communs ;
- modèle sécurité et threat model ;
- modèle de données ;
- catalogue protocoles ;
- critères de test.

### Lot 1 — Core, Auth, organisations et RBAC
- comptes ;
- sites ;
- zones ;
- rôles ;
- abonnement/entitlements ;
- audit ;
- i18n ;
- navigation.

### Lot 2 — Edge et matériel
- agent local ;
- gestion identifiants ;
- registre compatibilité ;
- connecteurs ONVIF/RTSP ;
- appareils et passerelles ;
- heartbeat ;
- événements normalisés.

### Lot 3 — Vidéo/audio
- visualisation directe ;
- NVR/DVR ;
- enregistrements ;
- audio ;
- interphones ;
- notifications.

### Lot 4 — Intrusion et commandes distantes
- détecteurs ;
- centrales ;
- sirènes ;
- relais ;
- scénarios ;
- commandes ;
- audit et double validation.

### Lot 5 — Fumée et incendie
- interfaces certifiées et passerelles ;
- modèles d'état ;
- cartes de zones ;
- workflows fumée/incendie ;
- escalades ;
- mode hors connexion ;
- tests installateur.

### Lot 6 — GPS, présence, rondes et visiteurs
- GPS ;
- geofencing ;
- pointage ;
- badge ;
- rondes ;
- SOS ;
- visiteurs ;
- véhicules.

### Lot 7 — IA Security
- détection ;
- corrélation ;
- anti-bruit ;
- priorisation ;
- assistant ;
- reporting.

### Lot 8 — ERP, incidents et maintenance
- inventaire ;
- interventions ;
- contrats ;
- tâches ;
- maintenance ;
- rapports.

### Lot 9 — Services transversaux
- billing ;
- paiement ;
- Livecare ;
- support ;
- notifications ;
- sauvegarde ;
- console administrative ;
- intégrations.

### Lot 10 — Web/PWA, langues et qualification
- Web/PWA ;
- FR/EN/Fulfulde ;
- accessibilité ;
- tests ;
- sécurité ;
- matériels physiques ;
- charge ;
- restauration ;
- Release signée.

L'ordre pourra être parallélisé uniquement lorsque les contrats et dépendances sont stables. La sécurité incendie, la sûreté et la compatibilité matérielle ne sont jamais considérées comme achevées sur la seule base d'une interface simulée.

---

# PARTIE XII — REGISTRE DES POINTS À CHIFFRER OU À CONFIRMER AVANT PRODUCTION

## 30. Décisions déjà fixées

- [V] NAXA ne fournit pas le matériel.
- [V] NAXA fournit la solution logicielle et la gestion à distance.
- [V] NAXA ne fournit pas de surveillance humaine.
- [V] Architecture hybride Cloud/On-Premise et traitement local prioritaire.
- [V] Compatibilité multimarque/multifabricant par protocoles, API, connecteurs et essais.
- [V] Modules vidéo, audio, GPS, présence, rondes, accès, alarmes, IA, incendie, commandes distantes, ERP, support et intégrations.
- [V] Essai de 14 jours.
- [V] Essentiel : 5 000 FCFA/mois ; 60 000 FCFA/an ; un site.
- [V] Business : 20 000 FCFA/mois ; 200 000 FCFA/an ; multisite.
- [V] Professional : 50 000 FCFA/mois ; 500 000 FCFA/an ; tous les produits/services SECURITY et ERP complet.
- [V] Paiements Orange Money, MTN Mobile Money, virement et facturation B2B.
- [V] Langues français, anglais et Fulfulde.
- [V] Une souscription globale par organisation.
- [V] Extensions à +20 % par extension selon catalogue.
- [V] Interconnexion possible avec les autres applications selon droits et API.

## 31. Paramètres à chiffrer/arrêter sans remettre en cause la conception

- [P] Quotas numériques caméras, canaux, appareils, sites additionnels, utilisateurs, passerelles et flux simultanés.
- [P] Stockage inclus, rétention et prix de capacité supplémentaire.
- [P] Budget de calcul IA local/Cloud.
- [P] Plafonds GPS, fréquence et durée d'historique.
- [P] Nombre de rondes, agents et checkpoints inclus par formule.
- [P] Matrice exacte des fonctions IA par formule.
- [P] Montants de frais uniques installation/formation mis à jour pour les trois formules.
- [P] Délai de grâce et niveau de consultation autorisé après impayé.
- [P] SLA support et plages horaires contractuelles.
- [P] Fournisseurs concrets pour SMS, WhatsApp Business, FCM, WebRTC et appels.
- [P] Procédure d'escalade client et contacts d'urgence par organisation.
- [P] Liste de marques/modèles prioritaires à acheter pour les essais.
- [P] Politique de conservation vidéo/audio/GPS et localisation des données.
- [P] Répertoire des installateurs/incendie/contrôleurs d'accès et responsabilités contractuelles.
- [P] Conditions d'activation de l'assistance à distance et de l'accès support temporaire.
- [P] Définition détaillée des unités d'extension.

Ces points ne doivent pas être remplacés par des chiffres inventés. Les champs sont configurables et la vente d'une capacité n'est possible que lorsque son coût, sa limite et ses conditions sont publiés.

---

# ANNEXE A — SOURCES TECHNIQUES ET RÉGLEMENTAIRES

Les références ci-dessous orientent la conception. Leur applicabilité au type de bâtiment, au matériel et au pays de déploiement doit être confirmée par un professionnel compétent.

1. **ONVIF — Profile T** : vidéo avancée, H.264/H.265, événements de mouvement/sabotage, métadonnées, PTZ, entrées/sorties numériques et audio bidirectionnel lorsqu'ils sont supportés : https://www.onvif.org/profiles/profile-t/
2. **ONVIF — Profiles** : principes de conformité et limites d'interopérabilité ; les fonctions conditionnelles doivent être vérifiées par produit : https://www.onvif.org/profiles/
3. **ISO 7240-1:2025** : définitions et composants des systèmes de détection et d'alarme incendie : https://www.iso.org/standard/79791.html
4. **ISO 7240-14:2013**, réexaminée et confirmée en 2025 : conception, installation, mise en service et entretien des systèmes de détection/alarme incendie dans et autour des bâtiments : https://www.iso.org/standard/57982.html
5. **ISO 7240-27:2025** : détecteurs ponctuels multi-capteurs fumée/CO et éventuellement chaleur : https://www.iso.org/standard/85565.html
6. **ISO 7240-15:2014**, confirmée en 2025 : détecteurs combinant fumée et chaleur : https://www.iso.org/standard/63053.html
7. **NFPA 72, édition 2025** : code de référence relatif aux systèmes de détection, signalisation, communications d'urgence, essais et maintenance : https://www.nfpa.org/codes-and-standards/nfpa-72-standard-development/72
8. **Cameroun — Décret n° 2018/1969/PM du 15 mars 2018** fixant les règles de base de sécurité incendie dans les bâtiments : https://www.minhdu.gov.cm/wp-content/uploads/2024/05/Decret-no-2018-du-15-mars-2018-fixant-les-regles-de-base-de-securite-incendie-dans-les-Batiments.pdf
9. **Cameroun — Guide du Corps National des Sapeurs-Pompiers, édition 2023**, procédure de demande d'une notice technique pour installation d'un système de sécurité incendie : https://mindef.gov.cm/wp-content/uploads/2023/08/TOME-5-APM-NATIONAL-FIRE-BRIGADE-USER-GUIDE.pdf
10. **Cameroun — Loi n° 2024/017 du 23 décembre 2024 relative à la protection des données à caractère personnel** : https://www.prc.cm/fr/actualites/actes/lois/7588

---

# ANNEXE B — GLOSSAIRE

- **NAXA EDGE :** logiciel/passerelle local qui connecte les matériels et continue les traitements autorisés sans Cloud.
- **ONVIF :** standards d'interopérabilité pour certains équipements de sécurité IP.
- **RTSP/RTP :** protocoles de transport/lecture de flux média.
- **DVR/NVR :** enregistreurs vidéo numériques ou réseau.
- **PTZ :** caméra orientable, inclinable et zoomable.
- **I/O :** entrées/sorties numériques.
- **Contact sec :** interface électrique de signalisation, à raccorder selon spécification fabricant.
- **RLS :** sécurité au niveau des lignes de données côté base.
- **RBAC :** contrôle d'accès par rôles.
- **Entitlement :** droit fonctionnel activé par l'abonnement.
- **Geofence :** périmètre géographique déclenchant des règles.
- **Outbox :** file locale des événements à synchroniser.
- **Webhook :** notification serveur-à-serveur authentifiée.
- **Préalarme :** état antérieur à une alarme selon la logique du système source.
- **Centrale incendie :** équipement local spécialisé qui gère les détecteurs et avertisseurs.
- **Télésurveillance humaine :** supervision assurée par des opérateurs ; non fournie par NAXA.

---

**Fin du cahier des charges NAXA SECURITY 360° V1.1.**  
**Règle de clôture :** le présent document valide le périmètre et les exigences. Il ne déclare aucune fonctionnalité du module Android, du Web/PWA, de NAXA EDGE, d'un fournisseur de paiement ou d'un équipement tiers comme déjà livrée. La qualification VERT GLOBAL dépendra des preuves définies dans les sections 28 et 29.
