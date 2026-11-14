# Audit Prompt 0.5 — Hors connexion et synchronisation

Date : 14 novembre 2026  
Cible backend : Supabase NAXA Production `eouwtuusnsuxaejsxknf` — PostgreSQL 17.11.0.002  
Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`, branche `main`  
Nature : audit du code GitHub et lectures SQL/catalogue uniquement. Aucun DDL/DML, aucune migration, aucun réglage ou déploiement.

## 1. Conclusion exécutive

**Prompt 0.5 : AUDIT DE DÉPART PARTIEL — NON VERT.**

Le dépôt possède déjà des briques initiales :
- dix files Room séparées, une par application Android ;
- une file IndexedDB commune dans `packages/offline-web` ;
- un contrat `SyncEnvelope` et une politique de conflit de base dans `packages/contracts` ;
- un backend NAXA qui traite déjà certaines opérations hors ligne pharmacie (correction de stock et ventes de caisse).

Mais ces briques ne constituent pas encore un moteur complet de synchronisation commun :
- pas de moteur Android partagé de synchronisation trouvé dans `packages/core-android` ;
- pas de synchronisation réseau, lot, retry, backoff ou accusé durable dans la file Web inspectée ;
- les files Android ne stockent qu'un événement minimal et n'ont pas de transport ni de worker de synchronisation prouvés ;
- le backend existant est spécifique à la pharmacie, au stock et à la caisse ; il ne couvre pas les dix applications ;
- les tolérances de 7/14 jours ne sont pas établies comme politique globale par application ;
- aucune protection DB append-only complète n'a été prouvée pour les preuves SMS inspectées.

La bonne correction est une architecture de synchronisation commune avec adaptateurs métier, pas dix moteurs ni un nouveau backend.

## 2. Preuves côté dépôt

### 2.1 Android — dix files Room

Les dix fichiers suivants existent :
- `apps/android/kiosko/src/main/java/cm/naxa/kiosko/OfflineQueue.kt`
- `apps/android/bootik/src/main/java/cm/naxa/bootik/OfflineQueue.kt`
- `apps/android/zipple/src/main/java/cm/naxa/zipple/OfflineQueue.kt`
- `apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/OfflineQueue.kt`
- `apps/android/cotiz/src/main/java/cm/naxa/cotiz/OfflineQueue.kt`
- `apps/android/loyable/src/main/java/cm/naxa/loyable/OfflineQueue.kt`
- `apps/android/naxa-hotel/src/main/java/cm/naxa/naxahotel/OfflineQueue.kt`
- `apps/android/campus237/src/main/java/cm/naxa/campus237/OfflineQueue.kt`
- `apps/android/naxa-security/src/main/java/cm/naxa/naxasecurity/OfflineQueue.kt`
- `apps/android/grillad/src/main/java/cm/naxa/grillad/OfflineQueue.kt`

Les dix implémentations suivent le même schéma minimal : Room, `eventId` comme clé primaire, `appId`, type d'agrégat, JSON, séquence appareil, horodatage local et état ; insert IGNORE, liste des événements queued et mise à jour d'état.

Limites observées :
- les fichiers sont dupliqués dans les dix modules au lieu d'utiliser un DAO/engine partagé ;
- aucune méthode de claim atomique des événements à envoyer, lease, compteur d'essais, prochaine tentative ou accusé serveur ;
- aucune validation de transition d'état ;
- aucune contrainte démontrée de payload immuable après insertion ;
- aucune API réseau ni worker de synchronisation dans ces fichiers ;
- aucun test dédié de cette file n'a été trouvé dans les chemins inspectés.

Le générateur `scripts/bootstrap-foundations.mjs` réécrit ces dix fichiers. Toute correction future doit modifier le générateur puis reconstruire/persister le résultat, sinon les changements seront perdus au prochain bootstrap.

### 2.2 Web/PWA

`packages/offline-web/src/index.ts` :
- utilise IndexedDB avec store `events`, clé `eventId` ;
- expose `enqueue`, `listQueued`, `setQueueState` ;
- ne contient pas de transport, batching, retry, backoff, horloge ancrée, conflit ni accusé serveur.

Les dix service workers Web partagent le même contenu SHA et ne mettent en cache que le shell, le manifeste et les assets GET. Cela permet une ouverture partielle hors connexion, mais ce n'est pas une synchronisation des données métier.

### 2.3 Contrats partagés déjà présents

`packages/contracts/src/index.ts` contient :
- `SyncEnvelope` avec `eventId`, `appId`, organisation, lieu, acteur, appareil, agrégat, version, séquence, `occurredAt`, version de schéma et payload ;
- `decideConflict` : égalité de version → accept ; vente/paiement/abonnement → revue manuelle ; inventaire → compensation ; autres → revue manuelle.

Ces règles constituent le contrat existant à préserver et compléter. Elles contredisent l'application uniforme de la règle historique « le plus ancien enregistrement serveur gagne » : les conflits financiers et métiers ne doivent pas être écrasés par une règle LWW générique.

### 2.4 Absence de tests dédiés

Les scripts et assertions SQL retrouvés couvrent les prompts 0.3 et 0.4. Aucun runner ni suite dédiée Prompt 0.5 n'a été identifié dans `supabase/local-tests` ou les fichiers de test examinés. Les tests des packages `contracts` ne couvrent que deux décisions de conflit et ne prouvent pas une synchronisation.

## 3. Preuves backend NAXA — lecture seule

### 3.1 Opérations hors ligne existantes

Tables constatées dans le projet réel :
- `public.offline_operations` : exclusivement `stock_set_quantity`, avec operation_id, pharmacie, produit, quantité, horodatage de base, auteur, appareil, séquence, modified_at, statut et résultat.
- `public.naxa_offline_sales` : ventes différées pharmacie, operation_id, appareil, utilisateur, pharmacie, session caisse, séquence, modified_at, payload, statut, résultat et dates.
- `private.naxa_offline_lww_config` : ligne de configuration avec `enabled_at = 2026-11-05 03:27:44.260589+00`.
- `public.appareils` : appareil pharmacie, utilisateur, installation_id, jeton hashé, actif et dernière synchronisation.
- `public.stock_manager_movement_journal` : journal utilisé par les corrections de stock.

### 3.2 RPC de synchronisation existantes

`public.naxa_apply_offline_operation_v1` :
- vérifie appareil actif et fraîcheur de synchronisation maximale de 7 jours ;
- vérifie profil actif, rôle, pharmacie, périmètre et privilèges ;
- impose `operation_id`, payload stable et séquence appareil strictement croissante ;
- refuse un horodatage manquant, hors fenêtre appareil/serveur ou antérieur à l'activation du journal ;
- limite le cas traité à `stock_set_quantity` et refuse les stocks lotisés ;
- applique une logique LWW spécifique basée sur `modified_at`, séquence et identifiant, puis prend en compte les mouvements postérieurs du journal ;
- conserve un résultat idempotent et renvoie un statut conflict/failed/applied.

`public.naxa_apply_offline_sale_v1` :
- vérifie appareil actif, fraîcheur de synchronisation maximale de 7 jours, profil, rôle caisse, pharmacie et session de caisse ;
- contrôle identifiant d'opération, payload, séquence appareil, prix serveur, total serveur, montant reçu et lignes ;
- retourne le résultat initial si la même opération est renvoyée avec le même contenu ;
- renvoie conflict ou failed si les prix, le stock, la session ou les contrôles métier ne passent pas ;
- ne doit pas être remplacée par un simple « premier JSON arrivé gagne ».

`public.offline_stock_set_quantity` :
- réserve l'identifiant d'opération, vérifie le propriétaire et le payload ;
- écrit une correction stock dans le journal avec horodatage serveur et marque l'opération appliquée.

ACL observées : les fonctions `naxa_apply_offline_operation_v1`, `naxa_apply_offline_sale_v1` sont SECURITY DEFINER, EXECUTE service_role, pas authenticated. `offline_operations` a une policy SELECT own pour authenticated ; les écritures passent par les fonctions contrôlées.

**Portée :** ces fonctions ne sont pas un moteur générique multi-applications. Ne pas étendre leur surface de privilèges ni leur logique aux autres applications sans nouvelle conception et tests.

### 3.3 Durée hors connexion et abonnements

Les RPC pharmacie rejettent les appareils dont la dernière synchronisation dépasse 7 jours. Le schéma `public.abonnements` contient notamment `formule`, début, échéance, statut et montant mensuel ; les abonnements Promoteur ont une table séparée.

Aucune matrice globale démontrée n'associe les dix applications aux paliers Essentiel, Pro et Réseau avec des tolérances de 7/14 jours. Les valeurs historiques du prompt ne peuvent donc pas être appliquées en dur à tous les acteurs et applications sans cartographie des plans et règles d'abonnement.

### 3.4 Preuves SMS et immutabilité

Les tables inspectées comprennent `naxa_promoteur_payment_sms_evidence`, `naxa_admin_payment_capture_events`, `naxa_payment_evidence_intake`, ainsi que les confirmations de paiement livraison et univers.

Les triggers relevés sur `naxa_payment_evidence_intake` servent au rapprochement à l'arrivée d'un crédit SMS ; aucun trigger append-only ou refus UPDATE/DELETE n'a été observé sur les tables de preuves sélectionnées. Les grants de `service_role` incluent INSERT, UPDATE et DELETE sur les tables de preuves inspectées.

Conclusion limitée : l'immuabilité DB des preuves SMS n'est pas démontrée. Les accès directs clients sont restreints dans les grants inspectés, mais cela ne suffit pas à garantir l'append-only contre une mutation serveur. Il faut auditer les chemins d'écriture, les RPC et le journal de correction avant de proposer un garde-fou additif.

## 4. Contradictions et causes racines

1. **Dix files Android quasi identiques au lieu d'un moteur partagé.** Cause : le générateur initial a matérialisé un squelette par application, sans service commun de synchronisation.
2. **File Web réduite à IndexedDB sans transport.** Cause : le package sert de stockage local minimal, pas de moteur de sync.
3. **Règle historique « plus ancien serveur gagne » incompatible avec les conflits métier NAXA.** Cause : confusion entre idempotence du même événement et résolution de deux événements différents sur un même agrégat.
4. **Tolérance 7/14 jours non raccordée à une matrice de plans globale.** Cause : les abonnements Production existants sont métier/spécifiques ; les paliers du prompt ne sont pas encore normalisés pour les dix applications.
5. **LWW pharmacie spécifique déjà actif pour certaines opérations de stock.** Cause : évolution métier NAXA antérieure ; le remplacer globalement risquerait de casser la cohérence des mouvements.
6. **Immutabilité des preuves SMS non prouvée au niveau DB.** Cause : les tables de preuves sont alimentées par des services privilégiés dont les grants autorisent aussi UPDATE/DELETE ; aucun trigger append-only observé sur l'échantillon.
7. **Détection de recul d'horloge absente des files inspectées.** Cause : aucune ancre serveur/horloge monotone persistée dans les files Android/Web actuelles.

## 5. Décisions de conception à préserver

- Une seule file métier locale par application peut rester physiquement séparée, mais son DAO, ses transitions, son retry et son transport doivent être mutualisés.
- Garder l'enveloppe d'événement versionnée de `packages/contracts`, en ajoutant les métadonnées d'idempotence, de retry et d'accusé nécessaires.
- Distinguer l'idempotence d'un événement du conflit entre deux événements distincts.
- Préserver les règles métier existantes : paiement/vente/abonnement → revue contrôlée ; inventaire → compensation ou algorithme NAXA spécifique ; pas de LWW global.
- Garder l'heure serveur comme autorité ; horodatage local uniquement comme indice, jamais comme preuve de validation.
- Préserver les données locales en cas d'échéance ou d'horloge suspecte ; bloquer les mutations risquées et demander une synchronisation.
- Ne pas ajouter de table générique de preuves SMS avant d'avoir démontré l'absence d'équivalent dans NAXA.

## 6. État et interdictions

**Prompt 0.5 : AUDIT DE DÉPART PARTIEL / NON VERT.**  
Prompt 0.4 reste PARTIEL / NON VERT ; Prompt 0.3 reste PARTIEL / NON CLOS.

Aucun DDL/DML, changement de policy/ACL, migration, réglage Auth, Edge Function, déploiement ou publication n'a été effectué sur Supabase réel. Les requêtes ont lu le catalogue, les définitions de fonctions, les politiques, les grants et les structures ; aucun SMS, paiement ou donnée personnelle n'a été extrait.

## 7. Reprise exacte

1. Concevoir le modèle commun de file et l'API d'adaptateur métier à partir de `SyncEnvelope`, sans modifier encore le backend.
2. Implémenter les tests TypeScript de transitions, idempotence client, batch partiel, retry et conflits par domaine.
3. Implémenter ensuite le moteur IndexedDB commun et son transport abstrait ; vérifier la persistance après reload.
4. Implémenter le DAO/worker Room commun dans `packages/core-android`, puis remplacer les dix files générées en modifiant aussi `scripts/bootstrap-foundations.mjs`.
5. Cartographier les plans/tolérances et les domaines métier des dix apps avant de coder le verrouillage 7/14 jours.
6. Auditer les RPC et droits d'écriture des preuves SMS, puis proposer des garde-fous append-only testés sur PostgreSQL 17 éphémère.
7. Ajouter les tests PostgreSQL des opérations NAXA existantes en non-régression ; ne pas toucher au backend réel.

