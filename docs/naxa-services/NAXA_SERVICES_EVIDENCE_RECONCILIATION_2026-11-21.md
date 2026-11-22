# NAXA SERVICES — audit de confrontation des déclarations et des preuves

**Date :** 21 novembre 2026  
**Dépôt :** audreymendomo23-netizen/FAMILLE-NAXA  
**Branche auditée :** work/naxa-services-completion-20261120  
**HEAD au début de l'audit :** 697d58fcef969ba5bcf2b2f10ecfe21eba46a004  
**Périmètre :** cahier des charges, déclarations de livraison, code Android/Web, API Auth/Edge, SQL candidates, tests et gates CI.

## 1. Méthode et règle de preuve

Une fonctionnalité ne sera pas déclarée inachevée parce qu'un appel d'outbox n'a pas de snapshot. Il faut confronter :
1. ce que le cahier des charges ou le document de construction affirme livré ;
2. le code de l'écran, du repository, de l'API/Edge ou du worker qui réalise le parcours ;
3. le test qui valide cette fonction, s'il existe ;
4. une contre-preuve spécifique qui établit la limite réelle (écran local, appel API absent, garde fail-closed, worker limité, secret absent, workflow non exécuté, ou validation externe non fournie).

### Statuts employés

| Statut | Sens |
|---|---|
| VERT LOCAL | Le parcours métier existe sur l'appareil / Room et est livré comme fonction locale. |
| VERT API/CONTRAT | Le client, l'endpoint et les tests/contrats existent ; cela ne prétend pas que l'endpoint est déployé en production. |
| VERT CI/LABORATOIRE | Le job automatisé ou le scénario PostgreSQL jetable a terminé avec succès. |
| PARTIEL | Une partie du flux est présente, mais un maillon fonctionnel explicite reste absent ou non branché. |
| ROUGE PROUVÉ | Une contre-preuve directe montre que l'exécution de bout en bout annoncée n'existe pas dans le périmètre contrôlé. |
| BLOQUÉ EXTERNE | La suite dépend d'un projet, d'un secret, d'un compte marchand, d'une clé, d'une autorisation ou d'un visa professionnel qui n'est pas disponible dans les éléments vérifiés. |
| À QUALIFIER | Les éléments disponibles ne permettent pas de conclure ; aucune supposition ne doit être transformée en anomalie. |

Les mentions « local », « API/contrat », « laboratoire » et « production » ne sont pas interchangeables.

## 2. Déclarations de livraison effectivement confirmées

### 2.1 Parcours Android locaux

Les sections 30, 34, 39 et 41 du dossier de construction décrivent des modules Android construits dans Kotlin/Jetpack Compose et Room. La présence des écrans et fonctions est corroborée par :
- MainActivity.kt : routes et écrans d'accueil, agenda, pressing, caisse, profil, notifications et promotions ;
- ErpModules.kt : catalogue de services, CRM local, stock, transferts, rapports, organisation, sites, postes et support ;
- ManagementModules.kt : facturation préparatoire, abonnements en demande locale, achats/fournisseurs, fiscalité préparatoire, objectifs, équipe, charges récurrentes et fidélité ;
- LocalErpStore.kt : entités Room, DAO et mutations locales.

**Qualification : VERT LOCAL** pour les parcours locaux effectivement décrits et présents. Leurs opérations ne doivent pas être déclarées absentes au seul motif qu'elles ne sont pas encore synchronisées au serveur.

### 2.2 Authentification et administration d'organisation

Le document de construction déclare l'authentification, les sessions, le provisionnement et les périmètres. Le client AuthApi.kt contient les appels login, refresh, récupération, changement de mot de passe, logout, profil d'organisation, sites, postes, acceptations légales, locale, onboarding, provisionnement et récupération administrée. L'Edge Auth index.ts contient les fonctions de création/liste des sites et postes, mise à jour profil, activité, documents légaux, onboarding, membres et révocation.

Le code Android utilise effectivement :
- api.updateOrganizationProfile() dans OrganizationWorkspaceContent ;
- api.createSite() lors de la création de site ;
- api.createWorkstation() et api.listWorkstations() pour les postes ;
- une session serveur et les sites affectés retournés par Auth.

**Qualification : VERT API/CONTRAT** pour ces parcours Auth/administration ciblés. Leur disponibilité réelle dépend toujours du déploiement de l'Edge Auth sur un projet dédié.

### 2.3 Parrainage PME

La section 38 décrit le code de parrainage PME, le tableau de suivi et les récompenses par vagues de cinq. ReferralScreen.kt et AuthApi.kt appellent le service Edge referrals ; le contrat Deno couvre création/association/tableau de bord et webhook HMAC de première souscription payée.

**Qualification : PARTIEL**. Le parcours et les contrats sont construits, mais les éléments du dossier (§38.4 et §39.6) précisent que le webhook de paiement réel n'est pas raccordé et que l'activation d'un entitlement demeure pending_entitlement tant que le moteur de souscription ne l'a pas appliqué.

### 2.4 Parrainage client et promotions

La section 47.3 déclare CustomerPromotionsContent raccordé à la passerelle customer-promotions, avec tableau de bord, création/publication de campagne, génération/association de codes et consultation des filleuls/récompenses. Le fichier Android contient plusieurs appels authApi.customerPromotionsRequest(). L'Edge index.ts expose ces actions. Les tests PostgreSQL jetables vérifient l'attribution avant première vente payée, qualification après vente entièrement payée, double-envoi idempotent, deux récompenses selon le mode bénéficiaire et rejet de l'auto-parrainage.

**Qualification : VERT UI/API/CONTRAT** pour le parcours et les règles testées en base jetable. **PARTIEL** pour la récompense réellement consommée par le ledger/registre métier : la section 47.3 dit explicitement que son émission doit rester raccordée au registre approuvé. CRM global et synchronisation de toutes les fiches client restent des sujets distincts.

### 2.5 Notifications Android et briefings locaux

La section 47.5 confirme une route NOTIFICATIONS, une inbox authentifiée, l'enregistrement/révocation du token, la permission Android, les états read/actioned et le nettoyage local à la déconnexion. MainActivity.kt route vers NotificationInboxContent ; AuthApi.kt possède notificationInbox(), acknowledgeNotification(), registerPushToken() et revokeCurrentDevicePushTokens(). Les tests instrumentés contrôlent que l'opt-in et l'association de membre sont effacés à la déconnexion.

En outre, MainActivity programme les briefings locaux de 07:00 et 19:00 ; il programme le worker quotidien des charges récurrentes.

**Qualification : VERT UI/CLIENT/CONTRAT** pour l'inbox et la gestion locale du registre ; **VERT LOCAL** pour les briefings/rappels locaux.

**Limite prouvée :** ces éléments ne prouvent pas qu'un message FCM réel est envoyé et reçu par plusieurs appareils. Le worker Edge requiert service account Firebase, clé de chiffrement, secret worker et environnement Supabase déployé. Le build CI ne reçoit pas les propriétés Firebase de projet et le job exécute des tests de contrat, non une livraison FCM réelle.

### 2.6 Roue promotionnelle

La section 47.4 indique que l'interface prépare les campagnes et lots en brouillon ; aucun tirage public ni activation Android n'est offert. Le SQL/Edge contient le moteur de tirage et les contrôles. Le test PostgreSQL rejette les campagnes non autorisées ou en brouillon.

**Qualification : VERT GARDE TECHNIQUE / BLOQUÉ EXTERNE POUR L'ACTIVATION.** La désactivation est délibérée, en attente d'avis/autorisation juridique. Il ne faut pas qualifier le moteur technique absent, ni déclarer la fonction autorisée en production.

### 2.7 Moteurs financiers testés

Le package finance-core présente des contrats testés :
- initiation de paiement et refus de considérer un simple HTTP 2xx/202 comme paiement confirmé ;
- vérification provider, référence, montant, devise et preuve serveur ;
- machine à états de paiement ;
- calcul de commission seulement après prestation achevée et paiement confirmé, règle approuvée et partage total valide ;
- extourne de commission append-only ;
- politique fiscale versionnée, approuvée et effective-datée.

Les tests finance.test.js vérifient ces invariants.

**Qualification : VERT LIBRAIRIE/TEST.** Cela ne prouve pas que les écrans Android calculent automatiquement les commissions, qu'un adaptateur marchand réel est configuré, ni qu'une politique fiscale approuvée existe pour l'organisation.

## 3. Contre-preuves directes : limites réellement établies

### 3.1 Synchronisation Android

SupplierSyncCoordinator.kt se décrit explicitement comme un coordinateur manuel et opt-in, « supplier-cycle events only ». Son set supportedActions contient exactement quatre actions : supplier.saved, purchase.ordered, purchase.receipt.confirmed et supplier.payment.recorded. Il lit uniquement ces actions dans l'outbox. Il bloque les achats avec article de stock non mappé et les paiements fournisseurs espèces sans session de caisse distante.

Le gate de contrat commun confirme le format des enveloppes et politiques de conflit ; il ne prouve pas un handler universel pour tous les modules.

**Qualification : ROUGE PROUVÉ pour la synchronisation ERP universelle.** La preuve est la portée explicite du coordinateur actif, et non l'affirmation que les autres 51 événements seraient 51 fonctions manquantes.

### 3.2 Les 55 points d'outbox : interprétation correcte

LocalErpStore.kt contient 55 appels au helper enqueue. Quatre événements du cycle fournisseur portent un snapshot explicite pris en charge par le coordinateur actuel ; les autres utilisent le fallback aggregate_id/site_id.

Ce décompte est uniquement celui des points d'émission. Il mélange des familles métier, journaux de gestion, états, copies locales et opérations qui peuvent aussi posséder un endpoint direct (Auth/site/poste, etc.). Il ne peut pas être transformé sans analyse en « 51 fonctions à construire ».

Le vrai travail de fermeture est une matrice d'action à action :
1. identifier le call site et le type de donnée ;
2. vérifier si une API directe effectue déjà la mutation ;
3. déterminer si l'événement outbox est un journal/audit local ou une mutation à répliquer ;
4. pour les seules mutations à répliquer, vérifier snapshot, ID, dépendances, handler, reçu transactionnel, conflits et tests.

### 3.3 Fonctions locales et limites serveur correspondantes

Les preuves suivantes confirment une livraison locale, mais aussi une limite de réplication :
- Catalogue/CRM : ErpModules.kt utilise les repositories Room ; des LocalOnlyNotice explicitent l'absence de synchronisation ou d'automatisation CRM.
- Pressing/agenda : MainActivity.kt crée et modifie les tickets/rendez-vous dans le repository Room ; l'écran précise que l'alerte serveur et la synchronisation restent à raccorder.
- Stock/transferts : ErpModules.kt utilise importInventoryBatch/createInventoryTransfer/recordInventoryMovement en Room et affiche une mention locale.
- Caisse/ventes/dépenses : LocalErpStore.kt et MainActivity.kt réalisent les opérations locales ; l'UI affiche qu'un paiement Mobile Money pending n'est pas confirmé et que l'espèce est enregistrée localement.
- Charges récurrentes : le Worker WorkManager et l'interface de paiements partiels/complétés sont présents ; les mentions indiquent des rappels locaux et pas de synchronisation serveur.
- Fidélité : les quatre programmes existent, les activités sont enregistrées manuellement et l'écran indique que l'interconnexion automatique à la caisse attend l'API ERP.
- Équipe/paie : pointages locaux séquencés et commissions/avances/primes saisies manuellement en pending_review ; l'écran indique que la validation RH/paie serveur et la synchronisation restent à raccorder.
- Rapports/pilotage : les données proviennent de Room et l'écran avertit qu'ils ne constituent pas un rapport réseau synchronisé.

**Qualification : VERT LOCAL pour les parcours locaux présents ; ROUGE PROUVÉ pour leur réplication serveur universelle là où l'écran et la mutation l'indiquent.**

### 3.4 Web/PWA

apps/web/naxa-services/src/main.tsx utilise fetch pour Auth uniquement. Les opérations du portail appellent addLocalEntry(), qui modifie l'état React, et le formulaire affiche explicitement Brouillon local. Le package.json exécute les tests de session Auth ; le build Vite est vert. La file IndexedDB packages/offline-web existe mais n'est pas importée par les pages métier NAXA Services.

**Qualification : VERT AUTH/BUILD ; ROUGE PROUVÉ pour la parité ERP Web et la synchronisation métier Web.** Le Web est une expérience d'aperçu local authentifiée, pas encore le portail métier complet.

### 3.5 Notifications FCM réelles

Le client Android est implémenté et l'Edge worker existe. La contre-preuve porte sur l'environnement réel : les variables BuildConfig Firebase sont alimentées par propriétés Gradle qui restent vides par défaut ; le worker Edge refuse l'envoi si ses secrets/configuration ne sont pas présents. Le workflow CI teste le type-check et les contrats, pas un envoi vers un token d'appareil réel.

**Qualification : PARTIEL / BLOQUÉ EXTERNE pour l'envoi réel.** Ne pas marquer le centre de notifications Android ou les briefings locaux comme absents.

### 3.6 Mobile Money réel

finance-core possède des contrats et une registry d'adaptateurs qui échoue fermée lorsqu'aucun adapter n'est enregistré ; le test vérifie ce comportement. Les écrans gardent Mobile Money en attente tant que la confirmation fournisseur n'existe pas. Les preuves documentaires déclarent qu'aucun compte marchand, KYC, sandbox, webhooks et rapprochement réels ne sont configurés.

**Qualification : VERT CONTRAT/TEST ; BLOQUÉ EXTERNE pour une transaction MTN/Orange réelle.**

### 3.7 Commissions, fiscalité, SYSCOHADA et paie

- Calculateur de commission et test unitaire : code disponible, mais ManagementModules.kt saisit manuellement un montant et crée un enregistrement pending_review ; aucune preuve d'appel automatique à calculateCommission depuis la clôture de prestation/caisse.
- Moteur fiscal et tests : code disponible, mais l'écran fiscal prépare un tax_estimate local en statut draft avec la mention accountant_validation_required ; aucune déclaration n'est transmise.
- Journal d'écritures local : les écrans le qualifient de comptes symboliques et non de plan SYSCOHADA certifié.
- Paie : pointages locaux et mouvements variables manuels ; aucun parcours complet bulletin/cotisations/déclarations CNPS et visa professionnel n'est démontré.

**Qualification : VERT LIBRAIRIE/TEST pour les moteurs présents ; ROUGE PROUVÉ pour automatisation commission intégrée ; NON QUALIFIÉ / BLOQUÉ PAR VISA pour SYSCOHADA, fiscalité appliquée et paie/CNPS réglementaires.**

### 3.8 Release, RLS et sauvegardes

- RLS : les drafts v1-v7 sont exécutés sur PostgreSQL 17 jetable par le job runtime RLS, en plus des contrôles statiques. VERT LABORATOIRE, pas preuve de déploiement sur Supabase hébergé.
- Backup/restore : run 44942987790 réussit sur deux DB jetables. VERT LABORATOIRE, pas preuve de DR hébergé.
- Release : le workflow signé vérifie la présence de quatre secrets privés et exécute assembleRelease/apksigner ; le gate courant produit un APK Debug. BLOQUÉ PAR CLÉ/SECRETS tant qu'aucune exécution signée n'est réussie.
- Recette : les tests instrumentés exécutés sont sur émulateur Android ; aucune preuve fournie d'une recette physique multi-marques/imprimantes/réseau instable.

## 4. Matrice de statut synthétique

| Domaine | Code / UI | Test / preuve | Limite démontrée | Statut juste |
|---|---|---|---|---|
| Android local (pressing, agenda, caisse, stock, CRM, charges, fidélité, équipe, pilotage) | Présent | Unitaires et instrumentés selon domaines ; UI explicite | Données Room non globalement répliquées | VERT LOCAL / sync ROUGE |
| Auth/organisation/sites/postes | API client + Edge | Auth contract CI et runtime RLS jetable | Déploiement dédié non prouvé | VERT API/CONTRAT |
| Parrainage PME | UI + API + Edge | Deno contract CI | webhook paiement / entitlement non appliqués | PARTIEL |
| Parrainage client | UI + API + Edge + SQL | PostgreSQL jetable + Deno contract | ledger réel et déploiement hébergé | VERT CONTRAT / PARTIEL ledger |
| Notifications Android | UI + client token + inbox + Edge worker | Instrumented token test + Deno + PG jetable | push FCM réel non prouvé | VERT UI/CONTRAT / BLOQUÉ FCM |
| Roue | UI draft + SQL/Edge | PG jetable teste legal gate | autorisation légale | GARDE TECHNIQUE VERTE / activation bloquée |
| Sync ERP Android | coordinateur 4 actions | contrat outbox vert | autres mutations pas dans le coordinateur | ROUGE global |
| ERP Web/PWA | Auth et aperçu local | build + tests Auth | formulaires métier React local | ROUGE parité métier |
| Finance-core | moteurs paiement/commission/fiscal | unitaires CI | pas d'adaptateurs ni intégration UI complète | VERT librairie / PARTIEL |
| Mobile Money | moteur et contrats | tests d'états/intégrité | aucun marchand/sandbox/webhook réel | BLOQUÉ externe |
| SYSCOHADA/paie | registres locaux | quelques tests finance | plan/ledger et paie réglementaires non validés | NON QUALIFIÉ |
| Supabase/RLS | SQL candidate | PostgreSQL 17 jetable runtime RLS | aucun environnement NAXA Services hébergé | VERT labo / BLOQUÉ déploiement |
| Backup/restore | scripts chiffrés | run 44942987790 | bases jetables seulement | VERT labo / DR hébergé à faire |
| Release | workflow signing | validation de secrets intégrée | APK debug seulement, pas de signed release | BLOQUÉ clé/secrets |

## 5. Gates CI et branche

Sur le commit de départ 697d58fc, le workflow 44946137015 a terminé **12/12 jobs SUCCESS**. L'artefact associé est l'APK Debug 14724147044, 13 571 429 octets, digest d'archive SHA-256 edfa9665b220a1442b1a82455d6da2e07f221172d7b226761cf25c95b46b5e7e.

Le workflow 44942987790 a terminé 1/1 job SUCCESS pour backup et restauration chiffrés sur PostgreSQL 17 jetable. Le commit ac239b9 est celui de ce workflow backup, pas celui du dernier gate technique.

Le commit 697d58fc ne contenait que des mises à jour documentaires par rapport à 38df9449. La branche main demeure à 6836f377.

## 6. Décision de passage à Supabase

Cette confrontation ne rend pas globalement vert le produit ; elle évite de réouvrir comme « manquantes » les fonctions locales et les API qui sont déjà effectivement codées. Les vrais lots qui demeurent rouges ou bloqués sont ceux dont une contre-preuve précise existe :
- synchronisation ERP Android universelle au-delà du cycle fournisseur ;
- connecteurs ERP Web/PWA métier ;
- rapprochement exact des événements outbox non couverts (à qualifier par famille, pas dénombrer arbitrairement) ;
- émission réelle FCM ;
- paiement marchand MTN/Orange ;
- entitlements du parrainage PME et émission des récompenses dans le ledger métier ;
- commission automatique depuis les prestations encaissées ;
- comptabilité SYSCOHADA et paie/fiscalité appliquées, après validations professionnelles ;
- Release signée, DR hébergé et recette terrain.

Les éléments explicitement bloqués par comptes, secrets, contrats et visas ne peuvent pas être rendus verts par des mocks. Les éléments de code réalisables doivent être traités comme des lots fonctionnels et prouvés par handlers / UI / tests concrets.

Aucune création de projet Supabase et aucune migration sur le projet pharmacie ne sont autorisées par cet audit.


---

## 7. Addendum — qualification exhaustive N1 (22 novembre 2026)

Le registre dédié `NAXA_SERVICES_OUTBOX_REGISTRY_2026-11-22.md` établit une bijection **55/55** entre les appels `enqueue()` et les fiches de qualification : 44 mutations indépendantes, 6 effets composites, 1 ledger dérivé, 1 miroir serveur, 1 miroir Auth direct et 2 helpers locaux legacy non appelés. Le coordinateur borné accepte 11 codes d'action fournisseur/articles/mouvements, sans être un synchroniseur universel.

Le garde-fou `scripts/naxa-services/verify-outbox-registry.mjs` compare méthode, agrégat, expression d'action et ligne source, vérifie l'absence de doublon/événement orphelin, recalcule le sous-ensemble des 11 actions, et contrôle que les créations site/poste actives restent servies par AuthApi. Il est branché au workflow technique.

**N1 : VERT COMPLET — inventaire/qualification 55/55.** Les 33 handlers de mutation restants et la synchronisation Android universelle restent des travaux N2/N3 et ne sont pas réputés implémentés par le présent audit.
