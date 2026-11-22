# NAXA SERVICES — document de continuité dédié

**Version :** 1.3  
**Date de mise à jour :** 22 novembre 2026  
**Dépôt :** `audreymendomo23-netizen/FAMILLE-NAXA`  
**Branche de travail :** `work/naxa-services-completion-20261120`  
**HEAD applicatif du dernier gate technique :** `c9883a31fbabe32a294eb42515841080847b3508`  
**Statut global :** **CI TECHNIQUE VERT 12/12 ; N1 VERT 55/55 ; N2 VERT 44/44 ; N3 PARTIEL / NON VERT MULTI-APPAREILS ; NON VERT OPÉRATIONNEL / PRODUCTION**

Ce document est le point de reprise spécifique de NAXA SERVICES. Il complète `docs/CONTINUITE.md` et le registre `NAXA_SERVICES_REMAINING_RED_GATES_2026-11-21.md`. Il ne remplace pas les cahiers des charges ni les décisions métier.

## 1. Consigne de gouvernance et périmètre de cette reprise

1. Travailler sur `work/naxa-services-completion-20261120` uniquement. La branche `main` ne doit pas être modifiée, fusionnée ou déployée dans cette séquence.
2. Ne pas créer de projet Supabase et ne pas appliquer de draft SQL au projet historique NAXA / pharmacie.
3. Les drafts v1 à v7 restent des candidats contrôlés par CI sur PostgreSQL jetable. Les workflows de test n'autorisent pas à les appliquer sur un environnement réel.
4. Ne jamais ajouter de clés, certificats privés, fichiers service-account, tokens, mots de passe, données clients réelles ou secrets de fournisseurs au dépôt public.
5. Un lot ne passe au vert que si le parcours métier complet est démontré par un test reproductible et une preuve. Un écran, un stub, un contrat isolé ou un build ne constituent pas une preuve de fonction opérationnelle.
6. Les intégrations externes et visas professionnels sont suivis séparément ; ils ne sont ni simulés ni déclarés disponibles.

## 2. État Git et preuves CI

### 2.1 Branche et commits vérifiés

- Branche de travail vérifiée : `work/naxa-services-completion-20261120`.
- Dernier HEAD applicatif effectivement vérifié par le gate 12/12 : `ada9bc2fe4986925a6afcc07238c0bbdc11f2073`. Le présent commit est une mise à jour documentaire ultérieure ; il ne doit pas être présenté comme un nouveau commit applicatif testé.
- Dernier gate technique associé à ce HEAD : [44953846842](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44953846842), terminé le 21 novembre 2026 à 21:59 UTC, **12/12 jobs en succès**.
- Le gate antérieur [44944767801](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44944767801) est un point de contrôle historique, désormais remplacé par le run 44953846842.
- Le workflow séparé de sauvegarde/restauration [44942987790](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44942987790) a terminé **1/1 job en succès** sur le commit `ac239b915777dfa0bfdb0b45dddc902f6a28aafb`. Il s'agit d'un drill sur deux bases PostgreSQL jetables, pas d'une restauration hébergée.
- Aucun projet Supabase NAXA Services n'a été créé ; aucun draft n'a été appliqué au projet historique NAXA / pharmacie. Cette reprise documentaire et les développements de la branche n'autorisent aucune migration ou mise en production.
- La branche `main` n'est pas la branche de travail de cette intervention ; aucune fusion ou déploiement vers `main` n'est prévu par ce document.

### 2.2 Ce que couvre le gate technique

Les douze jobs réussis couvrent : Auth et périmètres, build Web, contrat de synchronisation offline, catalogue tarifaire Famille, paiements/commissions/fiscalité, API de parrainage, contrats FCM/notifications, promotion/parrainage client, comptabilité fournisseurs/prévisions, vérification statique RLS/SQL, compilation et tests Android instrumentés, PostgreSQL 17 et tests RLS runtime sur base jetable.

Ce résultat valide le socle CI et les contrats testés. Il ne prouve pas que toutes les fonctions affichées par Android et Web sont opérationnelles.

### 2.3 Artefacts

- APK Android **Debug** : artefact [14726537650](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44953846842), taille **13 578 529 octets**.
- Digest SHA-256 de l'archive de l'artefact : `6945196a120541fde9a952300803127ab3ce01dac16eac5918f1bb62cfd78cd1`.
- Il s'agit d'une APK Debug destinée à la revue technique, pas d'une APK Release signée. Le keystore/certificat du propriétaire et les quatre secrets GitHub du workflow Release restent requis.

## 3. Architecture présente et limite de qualification

### 3.1 Android

L'application Android NAXA Services est construite nativement avec Kotlin et Jetpack Compose. Room porte les données locales et l'outbox. Le cycle fournisseur/achats dispose d'un coordinateur de synchronisation manuel, limité et opt-in.

Le fait que l'APK compile et que les tests instrumentés locaux réussissent ne signifie pas que les données ERP de tous les modules sont répliquées.

### 3.2 Web/PWA

Le portail Web utilise React, Vite et une session Auth réelle. Il est une application Web séparée, pas une conversion de l'application Android. Les modules ERP Web doivent appeler les mêmes contrats métier sécurisés que l'Android et utiliser une file offline adaptée.

À la date de l'audit, les modules métier Web sont encore en mode brouillon local. Le build Vite vert ne vaut pas parité ERP Web.

### 3.3 Backend

Les drafts PostgreSQL v1 à v7 et les Edge Functions présentes sont vérifiés par des tests de contrat et PostgreSQL jetable. Le seul projet Supabase visible est le projet historique NAXA / pharmacie, qui est explicitement exclu de cette reprise.

## 4. Synchronisation ERP — constat technique détaillé

L'audit de LocalErpStore.kt dénombre 55 appels au helper d'outbox. Ce chiffre mesure des points d'émission techniques, pas 55 fonctionnalités manquantes.

Au HEAD applicatif `ada9bc2`, `SupplierSyncCoordinator.kt` reste un coordinateur manuel, opt-in et limité ; il ne constitue pas un synchroniseur ERP universel. Son ensemble `supportedActions` accepte désormais **11 codes d'action** : `supplier.saved` ; quatre variantes `inventory_item.*` ; trois variantes `inventory_movement.*` ; `purchase.ordered` ; `purchase.receipt.confirmed` ; `supplier.payment.recorded`. Les 11 points d'émission correspondants ont des snapshots dédiés et des handlers Edge/RPC pour le cycle fournisseur et les prérequis articles/mouvements de stock. Cette évolution remplace la description historique qui ne comptait que quatre actions.

Le dernier comptage du fichier `LocalErpStore.kt` confirme **55 points d'émission** : **11 avec snapshots métier dédiés** et **44 avec payload de repli `aggregate_id/site_id`**. Les 44 événements de repli ne sont pas rejouables par ce coordinateur avec son contrat actuel ; cela ne prouve pas, à lui seul, que 44 fonctionnalités sont absentes. Certaines opérations ont des chemins API directs distincts de l'outbox (Auth, profil organisation, sites, postes, parrainage PME, parrainage client/promotions et centre de notifications). D'autres sont explicitement des registres locaux Room. Chaque call site doit être classé fonction par fonction avant d'ajouter un handler.

Il faut donc distinguer : opération locale construite, opération envoyée par un endpoint dédié, et opération répliquée par la synchronisation générique. Ne pas déduire l'état d'une fonctionnalité de la seule présence de son événement dans l'outbox.

Autres limites du cycle fournisseur :
- les achats avec lignes stock restent bloqués tant que les articles locaux n'ont pas de mapping d'identifiant distant ;
- les règlements fournisseurs en espèces restent bloqués tant qu'une session de caisse distante équivalente n'existe pas ;
- l'activation est refusée par défaut et le projet historique NAXA est explicitement interdit.

### 4.1 Agrégats et événements à couvrir

Les codes d'action doivent être recensés et associés à leur payload et handler. Les familles observées dans les appels d'enqueue incluent :
- fournisseur, commandes, réceptions, règlements et écritures comptables ;
- article, mouvement, valorisation, transferts de stock et inventaire importé ;
- charges récurrentes, paiements de charge, fidélité, activité et récompenses ;
- pressing, changement d'état, rendez-vous, reports et liste d'attente ;
- sessions de caisse, ventes, paiement confirmé/annulé et dépenses ;
- profil d'organisation, sites, postes de travail et services ;
- clients, mises à jour clients, suivis CRM et demandes de support ;
- autres enregistrements de gestion propres aux modules.

Le registre exhaustif N1 `NAXA_SERVICES_OUTBOX_REGISTRY_2026-11-22.md` classe les 55 call sites un par un. Il constitue la référence de qualification et doit être mis à jour par le contrôle automatisé à chaque évolution de `LocalErpStore.kt` ; ne jamais inventer un mapping serveur par ressemblance de nom.

### 4.2 Critères obligatoires par événement

Chaque événement doit avoir :
1. un code d'action stable et versionné ;
2. un identifiant d'événement idempotent et des IDs d'agrégat stables ;
3. un snapshot métier complet mais minimisé (pas de secrets et pas de champs superflus) ;
4. les dépendances nécessaires explicites (IDs article, caisse, vente, commande, etc.) ;
5. organisation, site, poste et acteur cohérents avec la session ;
6. un handler serveur typé et une mutation métier transactionnelle ;
7. un reçu persistant idempotent dans la même transaction que la mutation ;
8. une stratégie de conflits et de reprise ;
9. des tests positifs, négatifs, double-envoi, payload divergent, interruption et multi-appareils.

Aucun envoi générique de simples pointeurs locaux ne doit être introduit.

## 5. Web/PWA — état corrigé et travaux obligatoires

Le portail Web utilise React, Vite et une session Auth réelle. Il reste une application Web séparée de l'Android Kotlin/Compose ; les deux clients doivent partager les contrats métier et règles d'autorisation, et non le même code d'interface.

**Avancée vérifiée au HEAD `ada9bc2` :** la création d'un article de stock authentifiée utilise `normalizeInventoryItemDraft`, génère des identifiants stables, enfile l'événement dans `packages/offline-web` via IndexedDB, appelle l'action serveur `save_inventory_item`, exige un reçu serveur et n'acquitte la file qu'après validation du reçu. Les états de nouvelle tentative/rejet sont traités. Cette action Web ciblée ne représente pas une parité ERP globale.

**Limite qui reste démontrée :** les autres formulaires et écrans de gestion (agenda, pressing, caisse/ventes, prestations, CRM, mouvements et inventaires, achats/réceptions/paiements, charges, fidélité, équipe, rapports et administration) ne sont pas tous raccordés à des API de domaine avec persistance et reçus serveur. Plusieurs opérations continuent d'utiliser `addLocalEntry()` et l'état React local. Elles ne doivent pas être présentées comme des opérations ERP Web persistées ou confirmées côté serveur.

Critères de fermeture :
- chaque parcours métier Web livré est connecté à une API de domaine autorisée, avec validation et scope organisation/site/poste/rôle identiques à l'Android ;
- les écritures offline sont persistées dans IndexedDB avec IDs stables, dépendances, reprises et états de conflit/rejet ;
- chaque mutation n'est déclarée confirmée qu'après un reçu serveur vérifié ;
- les écrans relisent l'état serveur et le cache local après rechargement ;
- les tests couvrent online/offline, reconnexion, onglets multiples, double soumission, crash/reprise, changement de session, conflit et droits ;
- la matrice de parité est tenue fonction par fonction. Le build Vite seul ne vaut pas parité métier.

## 6. Intégrations et contrôles réglementaires encore rouges

| Domaine | État présent | Condition réelle de fermeture |
|---|---|---|
| Firebase/FCM | Code OAuth2/service-account, token chiffré, worker et contrats présents ; aucun push réel prouvé | Projet Firebase dédié, secrets déposés dans le coffre, envoi FCM réel et test sur appareil |
| Mobile Money MTN/Orange | Noyau multi-opérateur et états alignés ; mode fail-closed sans marchand configuré | Contrats/KYC, sandbox, webhooks signés, bénéficiaires, frais, tests de rapprochement et contrôles fraude |
| Commissions | Moteur/versionnement et écritures d'ajustement disponibles | Barème approuvé par chaque organisation, dates d'effet, validation des partages et extournes |
| SYSCOHADA | Cycle fournisseur/écritures et contrôles financiers partiels | Plan de comptes complet, journaux et périodes, contrôles équilibre, états et visa expert-comptable |
| Fiscalité | Moteur de règles effectives-datées sans taux par défaut | Paramètres fiscaux Cameroun validés pour la société et l'opération par professionnel compétent |
| Paie/CNPS | Couverture et paramètres non qualifiés | Règles de salaire, cotisations, retenues, bulletins et déclarations validés professionnellement |
| Roue promotionnelle | Code et contrat serveur préparés, fonction désactivée | Avis juridique écrit, autorisation applicable, règles et décision d'activation |
| Release Android | APK Debug généré | Keystore/certificat du propriétaire, secrets CI, signature et vérification de l'APK Release |
| Sauvegarde | Drill chiffré/restauration jetable réussi | Runbook, restauration de l'environnement hébergé dédié et test de reprise après sinistre |
| Recette appareil | Build et tests émulateur réussis | Tests sur appareils physiques, imprimantes, réseau dégradé, accessibilité et Fulfulde |

Ces éléments ne sont pas tous résolubles par du code seul. Les validations externes ne doivent pas être simulées. Les secrets sont ajoutés uniquement par leurs propriétaires dans les coffres correspondants.

## 7. Registre de sortie avant Supabase

| Lot de travail | Preuve obligatoire | Statut |
|---|---|---|
| Inventaire des 55 points d'outbox (N1) | Registre exact 55/55 ; 44 mutations indépendantes avec contrat, 6 effets composites, 1 ledger dérivé, 1 miroir serveur, 1 miroir API directe, 2 helpers locaux obsolètes ; bijection vérifiée par script CI | **VERT N1** — détails dans `NAXA_SERVICES_OUTBOX_REGISTRY_2026-11-22.md` et `.json` |
| Cycle fournisseur et prérequis stock | 11 codes d'action acceptés par le coordinateur manuel : fournisseur, articles, mouvements, commande, réception et règlement | PARTIEL — périmètre étendu ; synchronisation manuelle/opt-in, mapping article requis et caisse espèces encore bloquante |
| Autres domaines Room | Plusieurs écrans et registres fonctionnent localement ; mentions LocalOnly et fonctions API directes à comparer | ROUGE pour réplication universelle ; VERT LOCAL pour les parcours locaux attestés |
| Handlers serveur ERP par domaine | Edge accounting couvre le cycle fournisseur, post_sale_inventory, objectifs et lecture performance ; vérifier le raccordement effectif de chaque action | PARTIEL — pas de preuve de couverture de tous les agrégats |
| Reçus transactionnels et conflits globaux | Tables/contrats de reçus et conflits présents dans les drafts ; coordinateur actif limité au cycle fournisseur | PARTIEL — pas de preuve mutation + reçu atomiques pour tous les domaines |
| Sync Android universelle | Aucun coordinateur générique couvrant tous les agrégats ; coordinateur manuel fournisseur uniquement | ROUGE — synchronisation globale non démontrée |
| Sync Web/PWA ERP | Auth réelle ; opérations Web dans l'état React local, sans utilisation de la file IndexedDB partagée | ROUGE — parité métier et sync Web non livrées |
| Parité fonctionnelle Web | Build Vite et tests Auth réussis ; pas de connecteurs ERP métier démontrés dans les modules opérationnels | ROUGE — aperçu métier local uniquement |
| Finance applicative complète | Moteurs autonomes et tests présents ; plusieurs écrans gardent des registres locaux ou saisies manuelles | PARTIEL — séparer moteur testé, intégration métier et validation professionnelle |
| Firebase/FCM réel | Push reçu sur appareils de test | BLOQUÉ PAR PROJET/SECRETS |
| Mobile Money réel | Sandbox opérateur, webhook vérifié et rapprochement | BLOQUÉ PAR CONTRATS/ACCÈS |
| Release signée | Certificat propriétaire et vérification signature | BLOQUÉ PAR CLÉ/SECRETS |
| Conformité roue | Visa écrit et autorisation applicable | BLOQUÉ PAR VALIDATION EXTERNE |
| Recette/DR | Appareils physiques + restauration environnement dédié | À FAIRE |

## 8. Ordre strict de reprise

1. **N1 TERMINÉ —** matrice des 55 call sites et dépendances établie, qualifiée et contrôlée automatiquement. Ne pas rouvrir N1 sans changement du code source ou contre-preuve.
2. Compléter les snapshots et les validations des outbox, sans modifier les workflows d'activation par défaut.
3. Concevoir et tester les handlers métiers serveur sur PostgreSQL jetable, avec reçus transactionnels, scopes et conflits.
4. Répliquer les parcours Android, automatiser la file et tester la reprise multi-appareils.
5. Raccorder les modules Web/PWA et atteindre la parité métier, sans prétendre convertir automatiquement le Kotlin en Web.
6. Terminer les moteurs de finance/comptabilité/paie et leurs tests ; obtenir les validations professionnelles sur les paramètres.
7. Réaliser les tests d'intégration Firebase/Mobile Money lorsque les projets, contrats et secrets existent.
8. Signer la Release avec le matériel cryptographique du propriétaire ; effectuer les recettes physiques et l'exercice DR hébergé.
9. Exécuter un gate fonctionnel final sur le dernier HEAD et produire un dossier de preuves par module.
10. Seulement après ces étapes, demander la création de Supabase NAXA Services isolé et dérouler le processus de migration contrôlé.

## 9. Règles de non-régression

- Ne jamais connecter cette application au projet Supabase de la pharmacie.
- Ne jamais considérer une réponse HTTP 2xx/202 comme preuve de mutation enregistrée.
- Un événement n'est marqué synchronisé que sur reçu serveur vérifié.
- Ne jamais supprimer un événement local non acquitté lors d'une erreur, expiration ou conflit.
- Les transactions financières ne doivent pas être imputées sur le seul fait d'une commande ou d'un paiement initié.
- Les secrets restent hors Git et les données client réelles sont exclues des fixtures publiques.
- La roue promotionnelle reste désactivée sans validation juridique.
- `main` et la production restent inchangées.

## 10. Décision de passation

**État actuel :** les fondations de build, de contrats, de sécurité SQL jetable et de sauvegarde/restauration laboratoire sont vertes. L'application complète et sa synchronisation ne sont pas vertes.

**Prochain objectif technique :** remplacer le flux outbox à références minimales par un protocole d'événements métier complet, handler par handler, puis raccorder les modules Web/PWA. Aucun passage à Supabase avant preuves de sortie fonctionnelle.

Document complémentaire : `docs/naxa-services/NAXA_SERVICES_SYNC_PROTOCOL_V1.md`.

---

## 12. Mise à jour de continuité et définition des huit gates — 22 novembre 2026

Cette section est la référence courante et prévaut sur les chiffres de HEAD, les descriptions de synchronisation et les statuts d'artefact des sections historiques précédentes. Elle formalise les huit points de fermeture déjà ordonnés dans le registre des points rouges. Les huit gates sont des portes de preuve ; ils ne signifient pas que huit modules isolés suffisent à rendre le produit prêt à commercialiser.

### 12.1 Référence technique courante

- Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA`.
- Branche : `work/naxa-services-completion-20261120`.
- HEAD applicatif validé par le gate 44953846842 : `ada9bc2fe4986925a6afcc07238c0bbdc11f2073`.
- Dernier gate : [run 44953846842](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44953846842), **12/12 jobs SUCCESS**.
- Contrôles couverts : build Web et tests de session Auth ; contrats Auth/périmètres/modes métier ; politiques paiement/commissions/fiscalité ; comptabilité fournisseurs/prévisions ; sécurité statique SQL ; build et tests Android unitaires/instrumentés sur émulateur ; schéma et RLS runtime PostgreSQL 17 jetable ; contrats notifications/FCM ; parrainage client/promotions ; API de parrainage ; tarifs Famille ; contrat de synchronisation inter-applications.
- Artefact : APK Debug `14726537650`, 13 578 529 octets, SHA-256 archive `6945196a120541fde9a952300803127ab3ce01dac16eac5918f1bb62cfd78cd1`.
- Sauvegarde/restauration : run distinct `44942987790`, 1/1 SUCCESS sur deux bases PostgreSQL jetables. Le run et son commit ne sont pas le HEAD du dernier gate technique.
- Non démontré : déploiement Supabase hébergé dédié, dispatch FCM réel, transactions marchandes Mobile Money réelles, synchronisation ERP universelle, parité complète Web/PWA, Release signée et recette physique.

### 12.2 Ce que signifie « mise au vert »

Un statut vert est toujours accompagné de son niveau et de sa preuve :

- **VERT LOCAL** : le parcours métier fonctionne sur l'appareil et sa base locale, avec tests du flux local. Cela ne prouve ni réplication ni disponibilité multi-appareils.
- **VERT API/CONTRAT** : client, endpoint/handler et contrat sont présents ; les tests de validation sont passés. Cela ne prouve pas que l'endpoint est déployé dans un environnement réel.
- **VERT LABORATOIRE** : migration candidate appliquée à une base jetable, tests SQL/RLS exécutés et résultats conservés. Cela ne prouve pas l'isolation d'un projet Supabase hébergé.
- **VERT INTÉGRATION** : environnement fournisseur/Firebase réel ou sandbox officielle configurée, secrets installés dans un coffre, et parcours de bout en bout exécuté avec preuve observable.
- **VERT OPÉRATIONNEL** : le scénario métier complet est utilisable par l'utilisateur, depuis l'écran jusqu'à la mutation serveur, au reçu, au ledger/état attendu, à la reprise et à l'audit ; les tests négatifs et de non-régression passent.
- **VERT PRODUCTION** : version signée et déployée sur l'environnement dédié, contrôle d'accès et observabilité actifs, sauvegarde/restauration opérationnelle, procédure de retour arrière et recette utilisateur approuvée.

Un niveau inférieur ne doit jamais être présenté comme un niveau supérieur. Un build, un écran, une simulation, un endpoint non déployé, un HTTP 2xx/202 sans reçu, ou un test sur base jetable ne suffit pas à déclarer un parcours opérationnel ou en production.

### 12.3 Les huit gates et leur définition de sortie

| N° | Gate | État vérifié au 22/11/2026 | Définition précise de la mise au vert |
|---:|---|---|---|
| 1 | Inventaire et qualification des événements métier | **VERT N1 — 55/55** | Registre canonique `NAXA_SERVICES_OUTBOX_REGISTRY_2026-11-22.md` + JSON détaillé : 44 mutations à répliquer avec contrat v1 (dont 11 déjà reconnues par le coordinateur borné et 33 contrats destinés aux gates de réalisation suivants), 6 enfants composites, 1 projection comptable dérivée, 1 miroir de confirmation serveur, 1 miroir d'API directe et 2 helpers locaux non appelés. Chaque ligne contient source exacte (méthode/agrégat/action), codes d'action possibles, source de vérité, champs de snapshot, scopes org/site/poste, acteur, appareil, dépendances, handler cible, reçu, idempotence, conflit, retry et tests. Le script `scripts/naxa-services/verify-outbox-registry.mjs` compare la bijection exacte des 55 appels, vérifie les 11 actions réellement déclarées par `SupplierSyncCoordinator.kt` et contrôle les chemins API directs/legacy. Le workflow CI exécute ce contrôle. Le N1 est fermé ; N2/N3 restent des gates distincts et ne sont pas déclarés verts par cette qualification. |
| 2 | Handlers et mutations serveur | **PARTIEL — contrats/RPC en laboratoire, pas de backend hébergé dédié** | Chaque action issue de la matrice possède un handler typé et un RPC transactionnel ; Auth vérifie organisation, site, poste, rôle et propriété de l'agrégat. La mutation métier et son reçu idempotent sont persistés atomiquement. Un double envoi identique renvoie le même résultat ; un même ID avec payload divergent est rejeté ; une dépendance manquante ou un scope invalide est bloqué ; un crash/retry ne crée ni doublon ni perte. Tous les scénarios sont testés positivement et négativement sur PostgreSQL jetable et, après autorisation, sur l'environnement dédié. Le gate est vert lorsque toutes les actions du gate 1 ont une implémentation serveur prouvée, et non lorsque quelques RPC compilent. |
| 3 | Synchronisation Android globale | **PARTIEL — moteur d’envoi Android et passerelle serveur présents ; réplication bidirectionnelle multi-appareils non démontrée** | Le code Android porte maintenant 92 codes d’action distincts dans `SupplierSyncCoordinator`, valide les snapshots/scopes et exige un reçu serveur cohérent avant de marquer une outbox `synced`. `NaxaServicesSyncWorker` et WorkManager assurent une tentative périodique connectée avec retry ; l’activation reste conditionnée à `NS_ENABLE_SUPPLIER_SYNC=true`, à une configuration Famille dédiée différente du projet pharmacie et au choix « Rester connecté ». Le serveur `ns_apply_sync_event` applique les mutations, vérifie l’appareil/session, l’idempotence et la séquence par appareil. En revanche, aucun endpoint/flux de pull n’est exposé à l’application et aucun traitement des mutations distantes pour mettre à jour les projections Room n’est démontré. Les tests présents couvrent snapshots, retry, migration et ordre local ; ils ne prouvent pas une réplication A↔B. **N3 reste non vert** tant que la récupération incrémentale, l’application idempotente dans Room et les tests bout-en-bout sur deux appareils ne sont pas passés. |
| 4 | Web/PWA et parité métier | **PARTIEL — Auth/build et création d'article stock reliée ; autres parcours incomplets** | Tous les modules Web annoncés sont raccordés aux mêmes contrats métier sécurisés que l'Android, avec file IndexedDB, persistance, reçus, retries et conflits ; les données restent visibles après rechargement et concordent entre Web, Android et serveur. Tests online/offline, reconnexion, multi-onglet, double clic, crash, changement de session et scopes passent. Au HEAD courant, la création d'article de stock authentifiée utilise la file offline et l'action serveur `save_inventory_item` avec vérification du reçu ; ce chemin précis ne vaut pas parité ERP. Les autres formulaires qui passent encore par `addLocalEntry()` restent des brouillons locaux et doivent être connectés ou explicitement présentés comme tels. |
| 5 | Finance, comptabilité, commissions, fidélité et récompenses | **PARTIEL — moteurs/tests présents ; automatisations et visas non achevés** | Une vente/prestation ne produit un revenu qu'après confirmation de paiement ; les commissions se calculent automatiquement à partir d'une prestation achevée, payée et d'un barème daté approuvé ; les partages, plafonds, annulations et extournes sont audités. Les programmes de fidélité restent les quatre programmes indépendants déjà prévus, configurables par activité ; leur fermeture exige le déclenchement depuis les événements métier réels, un ledger idempotent et la synchronisation, sans inventer de seuils ou barèmes non validés. Le parrainage PME conserve la règle décidée : récompense par vagues de cinq PME ayant chacune terminé leur première souscription payante (parrain mensuel : un mois/cycle offert ; parrain annuel : un mois supplémentaire d'Accès à la fin de la période annuelle ; vagues 5, 10, 15… répétables) ; le webhook de paiement doit déclencher le crédit réel d'entitlement, pas seulement un statut `pending_entitlement`. Le parrainage client doit relier son contrat API au ledger/récompense réel. Le catalogue tarifaire Famille et sa règle annuelle 10 mois payés pour 12 mois de service, à date d'effet du 1er mai 2027, sont testés comme politiques ; ils ne prouvent pas une collecte réelle. SYSCOHADA, fiscalité camerounaise, paie et CNPS requièrent plan de comptes complet, paramètres datés et visa de professionnels compétents. Les barèmes de commission et taux non confirmés ne doivent pas être inventés. |
| 6 | Intégrations externes : Mobile Money et FCM | **BLOQUÉ EXTERNE / CONTRATS TESTÉS SEULEMENT** | FCM : projet Firebase propre à NAXA Services, configuration Android, service-account et secrets de chiffrement/worker installés dans un coffre, worker déployé, token enregistré/révocable, push réellement reçu sur appareils de test, statut de livraison contrôlé et scénario de panne/reprise prouvé. Mobile Money : contrats/KYC MTN MoMo et Orange Money, accès sandbox, identifiants marchands/bénéficiaires, clés et webhooks signés, frais confirmés, validation montant/devise/référence/idempotence, notification serveur et rapprochement bancaire/ledger de bout en bout. Le moteur fail-closed et les contrats CI sont utiles, mais ne constituent pas une transaction réelle. Les messages WhatsApp préparés et déclenchés par l'utilisateur restent distincts d'un service d'envoi automatique. |
| 7 | Release, conformité, sauvegarde et recette terrain | **PARTIEL / BLOQUÉ PAR CLÉS, AVIS ET RECETTE PHYSIQUE** | La Release Android doit être construite avec le keystore du propriétaire, les quatre secrets requis stockés dans GitHub Secrets, puis vérifiée par `apksigner` et checksum ; une APK Debug ne satisfait pas ce critère. La sauvegarde/restauration doit être exécutée sur l'environnement hébergé dédié avec restauration complète, contrôle d'intégrité et exercice de reprise après incident ; le drill sur deux DB jetables est seulement VERT LABORATOIRE. Les scénarios doivent être acceptés sur appareils physiques, imprimantes, réseau dégradé, permissions, batterie, accessibilité, FR/EN et Fulfulde relu par un locuteur compétent. La roue promotionnelle reste désactivée jusqu'à avis juridique écrit et autorisation applicable. Les validations comptables/fiscales/sociales sont traitées au gate 5, pas simulées ici. |
| 8 | Gate final, dossier de preuves et passage Supabase dédié | **NON LANCÉ — suspension volontaire** | Le dernier HEAD repasse l'ensemble des gates automatisés ; un dossier fonction par fonction relie exigence, code, API, test, résultat, artefact et preuve terrain. Les gates 1 à 7 ont chacun leur niveau vert exigé pour le périmètre de lancement, aucun blocage critique non accepté ne subsiste, et la matrice montre les limites explicitement exclues de la première version. Ce n'est qu'après cette revue que le propriétaire peut autoriser la création d'un projet Supabase NAXA Services isolé, distinct de celui de la pharmacie, l'application contrôlée des migrations, le déploiement des Edge Functions/secrets et les tests réels Auth/RLS/receipts/backup/restore. Aucun draft ne sera jamais appliqué au projet historique NAXA / pharmacie. |

### 12.4 Éléments déjà décidés à préserver — ne pas rouvrir sans arbitrage

- Les parcours locaux Android Room déjà livrés (catalogue/prestations, rendez-vous, pressing/tickets, caisse/ventes/dépenses, CRM, stock/import, fournisseurs/achats, équipe/pointage, multi-sites/postes, charges récurrentes, quatre fidélités et pilotage) sont conservés. Leur absence de réplication serveur ne justifie pas de les reconstruire.
- Pour le stock, conserver le parcours WhatsApp fournisseur initié par l'utilisateur : contact fournisseur, seuil bas, proposition de commande et message prérempli ; ne pas inventer un service d'envoi automatique.
- Les charges récurrentes gardent fréquence, échéance, paiement partiel/total, historique et rappels locaux ; la réplication et les rappels multi-appareils sont une couche distincte.
- Les quatre programmes de fidélité sont indépendants et configurables par activité ; les seuils, points et montants de récompense doivent être proposés puis validés, jamais supposés.
- Les décisions de parrainage PME et de facturation annuelle décrites au gate 5 sont conservées. Les offres de prix NAXA Services qui se contredisent dans les anciens dossiers restent à arbitrer ; aucun tarif final n'est choisi dans cette mise à jour.
- Les trois modes d'exploitation (PME autonome ; établissement avec plusieurs postes ; organisation multisite) et les périmètres organisation/site/poste doivent rester testés et séparés.
- La roue promotionnelle reste coupée tant que l'avis juridique/autorisation n'est pas obtenu. NAXA Services ne doit pas être raccordé à la base historique de la pharmacie.

### 12.5 Ordre d'exécution après cette mise à jour

1. **N1 terminé / vert :** conserver le registre 55/55 et son garde-fou CI. Toute nouvelle émission doit ajouter sa qualification au même changement de code.
2. Élargir les handlers/RPC et leurs reçus transactionnels selon la matrice, en conservant les tests PostgreSQL jetables.
3. Construire les coordinateurs Android par agrégat avec les dépendances et la résolution de conflits, puis couvrir multi-appareils.
4. Étendre la file Web/PWA des parcours déjà intégrés (à commencer par stock) à chaque module du périmètre validé.
5. Relier les événements de caisse/prestation aux commissions, fidélités, parrainages, paiements et journaux ; obtenir les visas métier et professionnels.
6. Obtenir les environnements et contrats Firebase/Mobile Money, puis réaliser les essais intégrés réels.
7. Préparer signature, conformité, recette physique et restauration hébergée.
8. Exécuter un gate final complet, constituer le dossier de preuves et seulement ensuite soumettre la création du projet Supabase dédié à autorisation.

**Décision de continuité au 22 novembre 2026 :** le dépôt est **VERT CI 12/12** sur le HEAD applicatif mentionné ; le laboratoire PostgreSQL 17 et RLS est vert, et la restauration laboratoire est **VERT 1/1** sur son run distinct. Le point N1 est désormais **VERT 55/55**, avec registre versionné et contrôle de complétude intégré à la CI. NAXA SERVICES n'est pas déclaré globalement vert : N2 à N8 conservent leurs statuts distincts. Aucun Supabase NAXA Services hébergé, aucune Release signée et aucune intégration marchande/FCM réelle ne sont attestés à cette date.


## 13. Fermeture du point de contrôle N1 — 22 novembre 2026

- **Résultat : VERT N1 — 55/55 call sites qualifiés.**
- **Preuve CI N1 :** le job `Cross-application offline synchronization contract` du run [44964977570](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44964977570) est **SUCCESS** sur le commit `b34cd4b9301be1fafa9691ba4ed513057b2581fc`. Sortie vérifiée : `status=PASS`, `source_call_sites=55`, `registry_rows=55`, `current_bounded_coordinator_actions=11`, `exact_callsite_bijection=true`; répartition 44/6/1/1/1/2.
- Matrice lisible : `docs/naxa-services/NAXA_SERVICES_OUTBOX_REGISTRY_2026-11-22.md`.
- Registre machine : `docs/naxa-services/NAXA_SERVICES_OUTBOX_REGISTRY_2026-11-22.json`.
- Contrôle bloquant : `scripts/naxa-services/verify-outbox-registry.mjs`, appelé par le job `Cross-application offline synchronization contract` dans le workflow technique.
- Le garde-fou vérifie l'identité exacte méthode/agrégat/expression action de chacun des 55 appels ; il échoue devant un ajout, retrait, renommage ou doublon non qualifié. Il vérifie aussi que les 11 actions déclarées par le coordinateur borné correspondent exactement aux 11 lignes qualifiées comme déjà prises en charge et que les helpers de création de site/poste considérés comme obsolètes restent sans appelant.
- Comptage : 44 mutations à répliquer, 6 enfants composites non expédiables isolément, 1 ledger dérivé, 1 miroir de confirmation serveur, 1 miroir d'API directe, 2 helpers locaux legacy.
- **Périmètre fermé :** N1 ne construit pas les 33 handlers encore contractuels, n'étend pas le coordinateur Android et ne développe pas la parité Web. Ces réalisations restent sous N2/N3/N4, sans être reportées dans N1.


### 13.1 Précision sur le transport source

Le registre constate deux contraintes concrètes à conserver pour N2/N3 : le modèle `LocalOutboxEvent` n'inclut pas directement l'ID d'installation ni l'acteur ; ils doivent être résolus à partir de la session Auth et de l'appareil enregistré. La séquence Room est actuellement calculée par organisation dans la base locale ; le protocole futur doit l'associer à l'installation pour l'unicité côté serveur. Enfin, `loyalty_program.updated` est organisationnel (`site_id=null`) et ne peut pas être pris par le coordinateur borné qui exige aujourd'hui un site. Ces limites sont documentées dans le registre et ne constituent pas des lignes non qualifiées du N1.
---

## 14. Reprise et audit du point de contrôle N2 — 22 novembre 2026

### 14.1 N1 reste fermé et intégralement vert

- **Décision maintenue : N1 = VERT COMPLET, clôturé.**
- Preuve de référence N1 : run https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44964977570, job Cross-application offline synchronization contract, PASS, source_call_sites=55, registry_rows=55, exact_callsite_bijection=true.
- Aucune reprise de l'inventaire N1 n'est nécessaire. Les travaux N2 ne changent ni le périmètre ni la qualification des 55 call sites. Toute évolution future du code source reste protégée par le même contrôle.

### 14.2 Critères N2 appliqués à l'audit

N2 ne consiste pas à ajouter des noms de fonctions ou des contrats. Pour chaque mutation REMOTE_MUTATION, les conditions cumulatives sont :
1. handler/RPC serveur concret, typé et appelé par une passerelle contrôlée ;
2. identité du membre dérivée de la session Auth et vérification d'un appareil/installation actif ;
3. scope organisation/site/poste et rôle contrôlés côté serveur, sans faire confiance aux identifiants d'acteur envoyés par le client ;
4. validation des champs, dépendances et états métier ;
5. mutation métier et reçu d'idempotence persistés dans une seule transaction ;
6. même event_id + même contenu = même reçu ; même event_id + contenu divergent = rejet ;
7. concurrence, erreurs de dépendance, échecs et rollback testés sur PostgreSQL jetable ;
8. grants explicites, SECURITY DEFINER avec search_path vide, tables server-only non accessibles directement aux clients ;
9. action non reconnue refusée par défaut, sans marquage ni reçu fictif.

### 14.3 Résultat N2 au présent audit

**PARTIEL — 17/44 call sites**

Le premier lot implémente une passerelle atomique public.ns_apply_sync_event dans le draft v4, expose l'action apply_sync_event dans l'Edge Function naxa-services-accounting, et valide l'enveloppe entrante dans sync_contract.ts.

**17 call sites sur 44** sont maintenant couverts et testés : OBX-001, OBX-002, OBX-003, OBX-004, OBX-006, OBX-007, OBX-008, OBX-009, OBX-010, OBX-011, OBX-012, OBX-032, OBX-033, OBX-035, OBX-036, OBX-037 et OBX-039. Les handlers complémentaires couvrent les frais récurrents et la fidélité ; les 11 actions bornées du cycle fournisseur/stock sont également accessibles via la passerelle atomique. Le registre JSON marque précisément ces 17 lignes.

**Comportement testé :**
- reçu applied et mutation sur le même commit transactionnel ;
- digest SHA-256 calculé par PostgreSQL à partir du payload JSONB ;
- verrou d'idempotence par organisation et event_id ;
- rejeu identique retournant le résultat antérieur ;
- rejeu divergent rejeté ;
- membre hors scope site refusé ;
- mutation invalide provoquant le rollback du reçu ;
- appareil enregistré, non révoqué et lié à la session Auth exigé.

**Preuve CI :** run https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44969249875, commit de code 76fb1cb1fcad91c10ec4e764e4a25c9f1b34ab72. Les jobs PostgreSQL 17/runtime RLS, sécurité statique SQL et contrats accounting/sync ont réussi. La vérification complète du workflow reste distincte des trois jobs de validation N2 ; ne pas déduire un gate global 12/12 de ces succès isolés.

### 14.4 Conditions N2 non encore vertes

**27/44 call sites restent sans handler serveur démontré :** OBX-013, OBX-014, OBX-015, OBX-016, OBX-018, OBX-019, OBX-022, OBX-023, OBX-027, OBX-028, OBX-029, OBX-030, OBX-031, OBX-034, OBX-038, OBX-040, OBX-041, OBX-042, OBX-043, OBX-044, OBX-045, OBX-047, OBX-048, OBX-049, OBX-053, OBX-054 et OBX-055.

Ces lignes couvrent pressing et transitions, rendez-vous et liste d'attente, sessions de caisse, ventes, annulations de ventes Mobile Money, dépenses, catalogue de services, clients, suivis CRM, valorisation de stock, demandes de support, pointages du personnel, documents de gestion, transferts multisites et transitions métier. Elles ne peuvent pas être déclarées terminées au moyen d'un handler générique qui contournerait leurs invariants.

Le dispatcher applique un refus par défaut pour les actions non prises en charge : pas de reçu applied, pas de faux succès. Le point N2 reste **PARTIEL / NON VERT** jusqu'à la preuve des 44/44 mutations indépendantes.

### 14.5 Frontières à ne pas franchir

- N1 est clos et ne doit pas être refait.
- N2 porte sur les handlers et mutations serveur ; le coordinateur automatique Android, les workers, l'ordre global, les mappings clients et la réplication multi-appareils restent N3.
- La file et les opérations métier Web/PWA restent N4.
- Le projet Supabase NAXA Services dédié n'est pas créé ; le draft v4 reste candidat CI sur PostgreSQL jetable. Aucun draft n'est appliqué au projet historique NAXA/pharmacie.
- main, les migrations hébergées et la production ne sont pas modifiées.

### 14.6 Ordre de traitement N2 restant

Traiter les 27 call sites restants par groupes de domaines, tout en conservant l'allowlist fail-closed :
1. catalogue/clients/CRM/support (services, clients, suivis, support) ;
2. pressing et rendez-vous/liste d'attente ;
3. caisse, ventes, paiements/annulations et dépenses ;
4. valorisation de stock et transferts multisites ;
5. pointages et documents de gestion/états ;
6. tests transactionnels inter-domaines, revue des grants et gate de clôture 44/44.

Ne pas engager le N3 tant que le dispatcher N2 n'a pas un handler et un test transactionnel pour chacun des 44 call sites indépendants.
 
---

## 15. Point de contrôle N2 — mise à jour après intégration serveur (22 novembre 2026)

**Cette section remplace le bilan intermédiaire 17/44 de la section 14.3 et la liste provisoire 27 call sites de la section 14.4.** Le N1 reste fermé ; aucun travail N2 n'a rouvert son inventaire.

### 15.1 Décision N1 — VERT COMPLET maintenu

- **N1 = VERT COMPLET, clôturé.**
- Référence de preuve : run CI https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44964977570, job Cross-application offline synchronization contract : 55 appels source, 55 lignes de registre, bijection exacte, aucun orphelin, doublon ou entrée injustifiée.
- Sur le run courant https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44983959405, le même contrôle N1 a encore réussi. Le registre conserve ses valeurs historiques implementation_status ; le suivi N2 est porté par un champ distinct n2_handler_status.

### 15.2 Bilan N2 mis à jour

**PARTIEL — 43/44 mutations indépendantes**

- Les 44 lignes REMOTE_MUTATION sont maintenant reliées à 92 codes d'action.
- Les 92 codes sont présents dans l'allowlist TypeScript ATOMIC_SYNC_ACTIONS, sans doublon ni code manquant, et chacun est routé par le dispatcher SQL ns_apply_sync_event.
- 43/44 call sites ont un handler serveur concret, des privilèges contrôlés et une preuve runtime/CI.
- 1/44 reste conditionnel : OBX-023 cash_session.closed. Son handler et sa logique de calcul existent, mais la clôture ne peut pas encore être déclarée complète pour tous les flux métier.

### 15.3 Call sites N2 nouvellement couverts dans la tranche finale

Les identifiants suivants ont été ajoutés au statut IMPLEMENTED_ATOMIC_SYNC_GATEWAY_CI_VERIFIED dans le registre JSON :

- **Ventes :** OBX-018 sale.created et OBX-019 sale.mobile_money_cancelled. Le runtime vérifie la vente cash, la sortie de stock et les écritures comptables, le maintien d'une vente Mobile Money en attente, puis son annulation avant confirmation opérateur.
- **Client et rendez-vous :** OBX-029 customer.updated avec contrôle de révision ; OBX-045 appointment.created_from_waitlist avec conversion transactionnelle de la liste d'attente.
- **RH :** OBX-047 staff_clock_in, pause début/fin et sortie avec séquencement serveur et refus d'une séquence invalide.
- **Dossiers de gestion :** OBX-048, création des devis, factures, avoirs, créances, achats, fournisseurs, ordres de service, dossiers RH et autres types autorisés.
- **Transferts multisites :** OBX-049 demande, OBX-053 réception destination, OBX-054 transitions de gestion et transfert. La réception crée la sortie source et l'entrée destination dans une même transaction ; un rejeu ne double pas le stock.

Le registre conserve OBX-023 sous IMPLEMENTED_PENDING_COMPLETE_CASH_SOURCE_COVERAGE.

### 15.4 Conditions de passage N2 effectivement testées

- Authentification membre, session et appareil actif/non révoqué ; scopes organisation, site et poste vérifiés côté serveur.
- Mutations et reçus persistés dans une seule transaction ; digest SHA-256 et sérialisation transactionnelle par event_id.
- Rejeu identique idempotent ; rejeu divergent rejeté ; action non reconnue refusée par défaut.
- Contrôle des versions sur client, catalogue, rendez-vous, pressing, dossiers de gestion et valorisation.
- Interdiction d'appeler directement les helpers métier depuis authenticated : le client doit passer par la passerelle atomique ; les helpers sont réservés au rôle serveur.
- Tests PostgreSQL 17 runtime/RLS couvrant ventes, Mobile Money, rendez-vous, pressing, caisse/dépenses, client/CRM, waitlist, RH et transferts multisites.
- Contrôle statique des grants, RLS, SECURITY DEFINER et dispatcher ; contrats Deno et contrôle de bijection N1.

**Preuve de la tranche finale :** run https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44983959405. Les jobs Cross-application offline synchronization contract, NAXA SERVICES PostgreSQL 17 schema and runtime RLS tests, NAXA SERVICES draft SQL security boundary checks, NAXA SERVICES supplier accounting and forecast contracts, NAXA SERVICES Web build, ainsi que les contrôles Auth, notifications, referrals, tarifs et paiements ont réussi.

**Limite de qualification :** le workflow global demeure in_progress au dernier relevé, car le job Assemble NAXA SERVICES Android debug APK est encore sur les tests Android accounting/performance. Les étapes Keystore/PIN, compilation APK et publication de l'artefact n'étaient pas terminées. Ne pas présenter le workflow total comme un PASS global ni comme 12/12.

### 15.5 Unique réserve restante — OBX-023 clôture complète de caisse

ns_close_cash_session calcule actuellement le solde serveur à partir du fond d'ouverture, des ventes cash confirmées, des dépenses et des paiements fournisseurs cash attachés à la session. La partie à fermer est le rattachement explicite des acomptes pressing à une session de caisse et à leur mode de paiement. Le modèle local pressing expose le montant de l'acompte, mais ne fournit pas encore le couple session/moyen de paiement nécessaire pour distinguer espèces, Mobile Money et autre mode.

Aucun mode cash ne doit être supposé à partir du seul montant d'acompte. La clôture complète N2 exige :
1. un cash_session_id explicite lorsque l'acompte pressing est encaissé en espèces ;
2. un moyen de paiement explicite et une confirmation serveur appropriée pour les autres moyens ;
3. la prise en compte des seuls encaissements pressing cash confirmés dans le calcul de la clôture ;
4. des tests de rapprochement et de non-double-comptabilisation du dépôt pressing.

Jusqu'à cette évolution, OBX-023 reste partiellement implémenté et N2 reste PARTIEL — 43/44. Ne pas engager la clôture finale N2 ni qualifier la caisse universelle de complète.

### 15.6 Frontières et état Git

- N1 est clos ; ne pas refaire le chantier.
- Le coordinateur Android universel, les reprises automatiques, l'ordre global multi-appareils et la consommation effective de la passerelle par les clients restent N3. Les opérations Web/PWA restent N4.
- Les drafts ont été exécutés uniquement sur PostgreSQL 17 jetable en CI. Aucun draft n'a été appliqué à un projet Supabase hébergé, en particulier pas au projet historique NAXA/pharmacie.
- Le travail est resté sur work/naxa-services-completion-20261120. La branche main n'a pas été modifiée.

### 15.7 Prochaine action N2

Compléter le contrat local et serveur des acomptes pressing (session + moyen de paiement + confirmation), relier les encaissements cash à OBX-023, ajouter les cas runtime de rapprochement, puis exécuter le contrôle de clôture 44/44. N3 ne commence qu'après ce vert complet.

---

## 16. Clôture N2 — rapprochement des acomptes pressing (22 novembre 2026)

**Cette section remplace le bilan 43/44 de la section 15 : N2 = VERT COMPLET, 44/44 mutations serveur vérifiées.**

### 16.1 Décision

- **N1 = VERT COMPLET, clôturé.** Les 55 call sites physiques sont toujours en bijection exacte avec les 55 lignes du registre ; les lignes sources ont été rafraîchies après les ajouts à LocalErpStore, sans ajout, suppression, doublon ni reclassification.
- **N2 = VERT COMPLET, 44/44 REMOTE_MUTATION.**
- Les 92 codes d'action portés par ces 44 call sites sont présents dans l'allowlist TypeScript et routés par le dispatcher SQL, sans doublon ni code oublié.
- Les 44 lignes REMOTE_MUTATION du registre JSON portent désormais n2_handler_status=IMPLEMENTED_ATOMIC_SYNC_GATEWAY_CI_VERIFIED. Le champ historique implementation_status de N1 a été préservé.

### 16.2 OBX-023 — clôture de caisse universelle finalisée

La création d'un ticket pressing exige maintenant un contrat explicite de paiement de l'acompte :

- Acompte nul : aucune méthode ni session de paiement ne sont autorisées.
- **Espèces :** méthode obligatoire cash, session de caisse ouverte du même site obligatoire, paiement créé confirmed et lié à cash_session_id.
- **Mobile Money / autre mode :** session de caisse interdite et paiement créé pending. Ces montants ne sont jamais comptés dans le tiroir-caisse tant qu'ils ne sont pas confirmés comme encaissements cash par le système.
- Espèces sans session, méthode absente ou session fermée : rejet serveur, pas de reçu applied.
- L'encaissement espèces crée une écriture comptable idempotente : débit CASH_REGISTER, crédit CUSTOMER_ADVANCES. L'acompte reste une avance client et n'est pas traité comme chiffre d'affaires.

ns_close_cash_session rapproche désormais, dans le même périmètre organisation/site/session :
- fond d'ouverture ;
- ventes cash confirmées ;
- acomptes pressing cash confirmés et rattachés à cette session ;
- dépenses et sorties fournisseurs cash.

Le test PostgreSQL 17 vérifie concrètement : fond d'ouverture 5 000 FCFA + acompte pressing cash 1 200 FCFA − dépense 1 000 FCFA = solde attendu 5 200 FCFA ; le décompte à 5 200 FCFA donne un écart nul. Un acompte Mobile Money de 800 FCFA reste pending, sans session caisse, et n'est pas inclus. Une tentative d'acompte espèces sans session est rejetée. L'écriture d'avance client de 1 200 FCFA est unique et correctement orientée.

### 16.3 Android local et migration

- Le modèle Room LocalPressingOrder conserve méthode, session et statut de paiement de l'acompte.
- Migration non destructive Room 12 vers 13, enregistrée dans le builder.
- Création de ticket : sélection explicite espèces / Mobile Money / autre ; sélection obligatoire d'une session ouverte pour les espèces ; pas de validation locale par défaut d'un acompte sans méthode.
- Les cartes de ticket affichent méthode et statut d'acompte ; l'écran caisse montre les acomptes espèces confirmés de la session.
- Le calcul de clôture locale ajoute uniquement les acomptes pressing cash confirmés.
- Des tests unitaires couvrent l'absence d'acompte, espèces avec session, espèces sans session, Mobile Money pending, autre mode pending et rejet des combinaisons incohérentes.

### 16.4 Preuves CI et statut de l'APK

**Run serveur et N1 :** https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44986404760

Au dernier relevé lors de la rédaction de cette section :
- Cross-application offline synchronization contract : SUCCESS, y compris la bijection exacte N1.
- NAXA SERVICES PostgreSQL 17 schema and runtime RLS tests : SUCCESS, incluant OBX-023 et l'écriture d'avance client.
- NAXA SERVICES draft SQL security boundary checks : SUCCESS.
- Contrats Web, Auth, notifications, referrals, paiements, tarifs et accounting/forecast : SUCCESS.
- Assemble NAXA SERVICES Android debug APK : le job restait in_progress, sur Run NAXA SERVICES accounting and performance unit tests. Les tests Keystore/PIN, l'assemblage APK et l'upload de l'artefact n'étaient donc pas encore déclarés terminés. Ne pas assimiler N2 serveur 44/44 à un APK livré.

### 16.5 Frontières Git et déploiement

- N1 ne doit pas être rouvert.
- N2 est clos. Le coordinateur Android universel, les reprises automatiques, l'ordre global multi-appareils et la consommation effective de la passerelle restent N3 ; les opérations Web/PWA restent N4.
- Les drafts SQL ont été exécutés uniquement sur PostgreSQL 17 jetable en CI. Aucun draft n'a été appliqué à un Supabase hébergé ; le Supabase historique NAXA/pharmacie reste hors périmètre.
- Tous les changements sont restés sur work/naxa-services-completion-20261120. La branche main est restée inchangée.

### 16.6 Prochaine étape

Aucune mutation N2 ne reste à implémenter. Terminer le job Android du run de référence, puis seulement communiquer l'état final de l'APK. Le chantier fonctionnel N2 est fermé à 44/44.

## 17. Clôture du gate Android et livraison Debug — 22 novembre 2026

### 17.1 Résultat CI vérifié

- Run GitHub Actions : [45012696504 — run #385](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45012696504).
- Workflow : `.github/workflows/naxa-services-technical-gate.yml`.
- Branche : `work/naxa-services-completion-20261120`.
- Commit applicatif : `c9883a31fbabe32a294eb42515841080847b3508`.
- Résultat GitHub vérifié : `status=completed`, `conclusion=success`, **12/12 jobs terminés avec succès**.
- Les 12 jobs couvrent notamment les tests unitaires Android, `:naxa-services:assembleDebug`, la recette instrumentée sur émulateur, PostgreSQL 17/RLS, sécurité SQL, contrats Auth, Web, notifications, referrals, tarifs, finance et le contrôle de registre N1.
- L’émulateur de la recette de connexion est Android 15 selon le compte rendu de recette. Les tests Keystore/PIN sont annoncés 7/7 réussis dans le résultat de livraison.

### 17.2 Artefact livré

- Artefact GitHub Actions : [naxa-services-debug-apk — ID 14750471915](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45012696504/artifacts/14750471915), présent et non expiré au contrôle.
- Taille APK annoncée dans le compte rendu de livraison : **14,65 Mo**. L’API GitHub expose une taille d’archive d’artefact de 13 617 362 octets ; il ne s’agit pas nécessairement de la taille exacte du binaire APK seul.
- SHA-256 APK communiqué avec la livraison : `9d16a9efab6ab886916bad68dcebda937030e459f44d41024f39553546da817b`. Cette empreinte est consignée comme valeur communiquée ; elle n’a pas été recalculée à partir du binaire pendant la présente vérification.
- Type : **APK Debug pour validation technique**, pas une Release signée ni une autorisation de distribution/production.

### 17.3 Périmètre Git et sécurité

- HEAD de la branche de travail vérifié : `c9883a31fbabe32a294eb42515841080847b3508`.
- Au premier contrôle de cette séquence, `main` pointait sur `0eb79951d2701264ebbb9ae81a01fb25ae7d3931`. Au contrôle final, son HEAD était `f602f03e0ce434c47f85a78d7032da4300b7d027` (deux commits plus loin), dont le dernier commit vérifié corrige le tableau de jalons CAMPUS237 dans `7 famille naxa/Cahiers de charge/Cahier_des_charges_08_Campus237_V3.0.md`. Ce déplacement de `main` est distinct de la présente mise à jour, qui a été commitée uniquement sur `work/naxa-services-completion-20261120` ; aucun merge, push sur `main` ou déploiement n’a été effectué par cette opération.
- La présente opération n’a exécuté aucune migration, aucun DDL/DML, aucune configuration ni aucun déploiement Supabase. Le projet NAXA pharmacie reste explicitement hors périmètre.
- **Limite de qualification :** le succès du run #385 clôt la recette technique Android ciblée ; il ne clôt pas N3 et ne démontre pas la réplication multi-appareils.

---

## 18. Ouverture N3 — synchronisation Android et réplication multi-appareils

Cette section prévaut sur les mentions antérieures du gate 3 dans la section 12.3. N1 et N2 sont clôturés ; N3 est ouvert sur la base du code existant. Il ne faut ni recommencer N1/N2 ni confondre le push des outbox avec une synchronisation bidirectionnelle.

### 18.1 Prérequis amont clos

- **N1 — VERT COMPLET : 55/55** points d’émission qualifiés, bijection contrôlée par `verify-outbox-registry.mjs`.
- **N2 — VERT COMPLET : 44/44** mutations indépendantes reliées à 92 codes d’action et à la passerelle serveur atomique, selon la clôture de la section 16.
- Run #385 : gate CI technique global **12/12 SUCCESS**. Ce résultat ne remplace pas les preuves N3 spécifiques.

### 18.2 État réel du code N3 au HEAD `c9883a3`

**Briques déjà présentes — ne pas les reconstruire sans nécessité :**

1. `SupplierSyncCoordinator` déclare **92 codes d’action distincts** et contrôle les snapshots, la cohérence organisation/site, les dépendances, l’appareil et les états de retry. Les actions dont le snapshot est incomplet ou dont le handler n’est pas autorisé restent bloquées.
2. Le coordinateur envoie `apply_sync_event` et n’acquitte une ligne locale qu’après validation du reçu : statut `applied`, même `event_id`, action, agrégat et empreinte SHA-256 au format attendu.
3. Le traitement est protégé par un verrou de synchronisation en processus ; les échecs transitoires sont conservés en `retry_wait` avec délai exponentiel/jitter ; les dépendances bloquées et rejets ne sont pas marqués synchronisés.
4. `NaxaServicesSyncWorker` utilise WorkManager, une contrainte réseau connecté, une planification périodique de 15 minutes, un rafraîchissement Auth et une session/appareil enregistré. Le worker traite la file sortante locale.
5. La RPC serveur `ns_apply_sync_event` vérifie la session et l’appareil actif, impose une séquence monotone par appareil et retourne un reçu idempotent ; le même événement rejoué à l’identique retourne le reçu existant et un contenu divergent est rejeté.
6. Les tests instrumentés vérifient la migration Room et la persistance/l’ordre de la file locale après réouverture ; les tests unitaires vérifient notamment les snapshots, les règles de retry et le verrou concurrent.

**Limites qui maintiennent N3 non vert :**

- `NS_ENABLE_SUPPLIER_SYNC` est défini à `false` par défaut dans Gradle.
- `isConfigured()` exige l’activation explicite, les paramètres Auth/Accounting, la concordance du projet configuré avec le projet Famille et l’exclusion du project ref NAXA historique.
- La planification périodique de l’application n’est déclenchée que si une session mémorisée (« Rester connecté ») et un appareil sont présents ; sinon le scheduler est annulé. La méthode one-shot `enqueueNow` existe dans le scheduler, mais aucun appel depuis l’interface de l’application n’a été trouvé au HEAD audité.
- Le flux client observé est **sortant** : Android transmet des mutations locales vers le serveur. L’Edge Function Accounting expose `apply_sync_event`, mais aucun endpoint de récupération incrémentale (pull/cursor) à destination des appareils n’a été trouvé dans ce périmètre.
- Aucune logique démontrée ne récupère les changements créés par un autre appareil puis ne les applique idempotemment aux tables/projections Room du présent appareil.
- Les tests PostgreSQL actuels valident le premier envoi, le rejeu identique, le rejeu divergent, les rejets de scope et une séquence inversée pour le même appareil. Ils ne démontrent pas l’échange bidirectionnel de mutations et d’états entre deux installations distinctes.
- Les tests UI de connexion, le build APK et le PASS 12/12 ne couvrent pas cette absence de pull/apply. Le projet Supabase NAXA Services dédié n’est pas attesté comme configuré : aucun test d’intégration réel multi-appareils n’est donc déclaré.

**Verdict d’entrée : PARTIEL / NON VERT MULTI-APPAREILS.** Le push sortant et ses contrôles sont avancés, mais ils ne constituent pas à eux seuls une réplication ERP.

### 18.3 Plan d’exécution N3

Conception dédiée N3-B : [NAXA_SERVICES_N3_BIDIRECTIONAL_SYNC_DESIGN_2026-11-22.md](NAXA_SERVICES_N3_BIDIRECTIONAL_SYNC_DESIGN_2026-11-22.md). Cette note est une proposition technique à valider ; elle n'ajoute aucun endpoint ni aucune migration.

| Sous-lot | Travail attendu | Preuve de sortie |
|---|---|---|
| N3-A — sécuriser le push | Fermer les écarts entre les 92 actions enregistrées et les snapshots effectivement produits ; vérifier la séquence par installation, les dépendances, l’activation, le lancement manuel et les reprises WorkManager. Conserver tout événement non acquitté. | Tests unitaires et Room : ordre, redémarrage, retry, événement bloqué en tête, reprise après changement de session/appareil, aucune transition `synced` sans reçu valide. |
| N3-B — flux de changements serveur | Concevoir un journal de changements serveur durable et un endpoint pull paginé avec curseur par appareil ; filtrer côté serveur par organisation, site, appareil/compte et permissions. Définir rétention, ordre, rejeu, révocation et comportement des curseurs expirés. Ne pas exposer les tables ni les reçus privés directement au client. | Tests PostgreSQL 17 jetables : isolation inter-organisation/site, deux appareils, pagination, curseur stable, doublons, reprise après timeout, révocation et aucune fuite de payload. |
| N3-C — application locale | Convertir les changements distants autorisés en mises à jour Room transactionnelles et idempotentes ; maintenir les mêmes invariants métier, versions et règles de conflit que N2. Éviter de réémettre vers le serveur un changement reçu d’un pair. | Tests Room : application une seule fois, rejeu sans doublon, ordre/dépendances, rollback, crash/restart, conservation des modifications locales non acquittées et résolution contrôlée des conflits. |
| N3-D — recette multi-appareils | Exécuter des scénarios appareil A ↔ appareil B, puis A/B ↔ serveur, avec connectivité variable et périmètres distincts. Ajouter le gate CI multi-appareils au workflow technique. | Deux installations distinctes : création/modification sur A visible sur B après pull ; mutation sur B visible sur A ; offline/reconnexion, double envoi, crash, version concurrente, changement de site, membre/appareil révoqué, absence de cross-tenant. Logs et reçus corrélés. |
| N3-E — activation contrôlée | Conserver le feature flag désactivé tant que la recette laboratoire et la configuration du projet dédié ne sont pas approuvées. Préparer observabilité, reprise et retour arrière avant toute activation réelle. | Test d’intégration sur environnement NAXA Services dédié et autorisé ; aucune activation ni migration vers le Supabase historique pharmacie. |

### 18.4 Ordre et règles de protection

1. Continuer depuis le HEAD existant de `work/naxa-services-completion-20261120` ; ne pas réouvrir N1 ou N2.
2. Cartographier les entités Room et leurs invariants avant d’écrire le pull/apply ; commencer par un vertical slice réversible, puis étendre domaine par domaine.
3. Tester les mécanismes serveur uniquement sur PostgreSQL 17 jetable tant qu’un environnement dédié n’est pas configuré et autorisé.
4. Garder `NS_ENABLE_SUPPLIER_SYNC=false` dans la configuration par défaut ; aucune activation réelle par défaut, aucun secret ajouté au dépôt.
5. Ne pas appliquer de draft au Supabase NAXA pharmacie, ne pas modifier `main`, ne pas déployer d’Edge Function et ne pas distribuer d’APK sans autorisation distincte.
6. N3 ne sera déclaré **VERT** qu’après les preuves N3-A à N3-D sur deux appareils distincts ; une compilation, un push vers serveur ou un run CI générique 12/12 ne suffisent pas.

**Prochaine action concrète :** instruire la matrice des droits de lecture et l’option projection/invalidation décrites dans la note N3-B, puis seulement écrire le draft du journal et du curseur de pull, son test d’isolation PostgreSQL et le premier vertical slice serveur + Room sur deux appareils. N4 (raccordement et parité Web/PWA) reste séparé et n’est pas inclus dans cette clôture N3.

