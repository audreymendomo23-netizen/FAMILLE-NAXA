# NAXA SERVICES — document de continuité dédié

**Version :** 1.4  
**Date de mise à jour :** 22 novembre 2026  
**Dépôt :** `audreymendomo23-netizen/FAMILLE-NAXA`  
**Branche de travail :** `work/naxa-services-completion-20261120`  
**HEAD applicatif validé par le gate N3 :** `b076898f568961a0c22bdd430d57db7a9e667b61`  
**Statut global :** **N1 VERT 55/55 ; N2 VERT 44/44 ; N3 VERT COMPLET — PUSH/PULL, ROOM ET RECETTE BIDIRECTIONNELLE VALIDÉS ; CI 12/12 SUCCESS ; ACTIVATION PRODUCTION NON DÉPLOYÉE**

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
| 3 | Synchronisation Android globale | **VERT COMPLET — N3-A à N3-D validés** | Push sortant idempotent et WorkManager ; journal serveur atomique ; pull incrémental paginé par curseur et filtrage Auth/organisation/site/appareil ; application transactionnelle dans Room avec reprise, rejeu idempotent et prévention d’écho ; recette bidirectionnelle A↔B avec deux bases Room indépendantes et tests PostgreSQL 17. 92 codes d’action sont alignés entre le coordinateur Android et l’allowlist Edge ; 55/55 points d’émission restent réconciliés. **Le gate N3 logiciel/CI est vert.** Le feature flag reste désactivé par défaut et aucune activation hébergée n’a été réalisée : aucun projet Supabase NAXA Services dédié n’est disponible dans les projets connectés ; le projet historique NAXA/pharmacie reste protégé. |
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
- `main` a avancé indépendamment pendant cette séquence : après `0eb7995` puis `f602f03`, son HEAD vérifié le 22 novembre est `a229f62b41ddffbf4dc923fe4a90d36edbcca927`. Cette évolution ne provient pas de la présente passe ; tous les commits N3 restent uniquement sur `work/naxa-services-completion-20261120`. Aucun merge, push sur `main` ni déploiement n’a été effectué.
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

## 19. Clôture N3 — synchronisation bidirectionnelle validée — 22 novembre 2026

Cette clôture remplace le verdict d'entrée PARTIEL de la section 18 et confirme les preuves N3-A à N3-D. Elle ne vaut pas autorisation de déployer en production.

### 19.1 Preuve CI de référence

- Workflow : [run #456 — 45030230301](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45030230301).
- Branche : `work/naxa-services-completion-20261120`.
- Commit validé : `b076898f568961a0c22bdd430d57db7a9e667b61`.
- Résultat GitHub : `completed / success`, **12/12 jobs PASS**, sans job échoué ni annulé.
- PostgreSQL 17 : schéma candidat, RLS, tests de pull A/B, appareil révoqué, filtrage et sécurité serveur PASS.
- Contrat inter-applications et registre N1 : PASS ; 55/55 callsites réconciliés et 92 codes d'action Android/Edge en parité.
- Android : tests unitaires PASS ; `:naxa-services:assembleDebug` PASS ; `:naxa-services:connectedDebugAndroidTest` PASS — **11 tests exécutés sur émulateur Android 15** ; publication de l'artefact PASS.

### 19.2 Preuves fonctionnelles N3

1. **N3-A — Push et reprise : VERT.** Le coordinateur conserve les identifiants d'événement et séquences, ne marque une mutation synchronisée qu'après reçu valide, gère les dépendances/rejets/retry ; WorkManager relance les opérations connectées. Les 92 actions déclarées restent alignées avec la passerelle Edge ; les 44 mutations distantes indépendantes restent rattachées au registre N2.
2. **N3-B — Journal et pull serveur : VERT.** Le journal `ns_sync_changes` est alimenté dans la transaction métier ; le pull `ns_pull_sync_changes` renvoie des pages ordonnées par curseur, filtrées par session/appareil et périmètre autorisé. Les tables de journal et de curseurs restent inaccessibles en SELECT direct aux rôles clients. Les tests PostgreSQL 17 couvrent deux appareils, pagination, rejouabilité, exclusion de l'événement propre, réception des événements pairs, scopes et révocation.
3. **N3-C — Application Room : VERT.** Les changements distants sont persistés et appliqués dans Room de manière transactionnelle/idempotente ; les pages rejouées ne créent pas de doublons ; les changements reçus ne sont pas réémis dans l'outbox sortante ; les changements en revue restent persistés plutôt que supprimés.
4. **N3-D — Recette bidirectionnelle : VERT.** Un test instrumenté utilise deux bases Room indépendantes représentant deux installations : A publie et B applique ; B publie une nouvelle version et A applique ; le rejeu est neutre ; aucune outbox parasite n'est créée. Le même protocole est corroboré par les tests serveur PostgreSQL 17. Les 11 tests instrumentés de la recette Android 15 sont verts.

**Verdict : N3 VERT COMPLET pour le périmètre logiciel Android, serveur candidat, persistance Room et recette CI bidirectionnelle.** Ce verdict ne prétend pas à une validation de charge en production ni à une synchronisation sur un service hébergé qui n'a pas été déployé.

### 19.3 APK de recette

- Artefact : [naxa-services-debug-apk — ID 14757537990](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45030230301/artifacts/14757537990).
- Taille de l'archive GitHub : 13 692 426 octets ; rétention annoncée jusqu'au 29 novembre 2026.
- SHA-256 de l'archive ZIP GitHub : `9e485d6c1abddacdf3b261fb0df90eb7561b09622a1a52d73d2d3ade4433dd66`. Cette empreinte porte sur l'archive de l'artefact, pas sur le binaire APK extrait.
- Il s'agit d'un APK Debug de recette, pas d'une Release signée pour distribution.

### 19.4 Limite de déploiement explicitement conservée

- La recherche des projets Supabase connectés a retourné un seul projet, nommé `NAXA` (`ykgjfindlgseegmznaog`). Aucun projet dédié `NAXA SERVICES` n'est disponible dans cette connexion.
- Le projet `NAXA` historique/pharmacie n'a reçu aucune migration, aucun DDL/DML, aucune Edge Function et aucune modification pendant cette passe.
- `NS_ENABLE_SUPPLIER_SYNC` reste à `false` par défaut ; aucune activation hébergée n'a été tentée et aucun secret n'a été ajouté au dépôt.
- `main` n'a pas été modifiée par cette passe. Son HEAD observé après les avancées indépendantes est `a229f62b41ddffbf4dc923fe4a90d36edbcca927`.
- Le passage de N3 logiciel/CI vert à l'activation d'un environnement NAXA Services dédié constitue une étape de déploiement séparée, pas un défaut du gate N3.



## 20. Lancement et audit N4 Web/PWA — 22 novembre 2026

Le gate N4 est ouvert en audit sur `work/naxa-services-completion-20261120`. Le rapport détaillé est `docs/naxa-services/NAXA_SERVICES_N4_WEB_PWA_AUDIT_2026-11-22.md`.

**Verdict : N4 PARTIEL — non fermé.** Le contrôle du code confirme l'authentification Web et un vertical slice de création d'article de stock avec IndexedDB, action serveur `save_inventory_item` et reçu vérifié. En revanche, agenda, pressing, caisse, services, CRM, équipe, organisation/sites/postes et une grande partie des rapports restent en aperçu local ou sans raccordement métier démontré. `addLocalEntry()` ne fait qu'ajouter à l'état React ; les transitions pressing et plusieurs réglages sont locaux.

L'Edge Accounting expose actuellement les actions `pull_sync_changes`, `apply_sync_event`, `save_inventory_item`, `record_inventory_movement`, `save_supplier`, `create_supplier_purchase`, `receive_supplier_purchase_line`, `record_supplier_payment`, `post_sale_inventory`, `create_performance_objective` et `performance`. Cette liste ne constitue pas une couverture des 44 mutations du registre N1. La définition de sortie du gate N2 reste PARTIEL tant que chaque handler transactionnel, reçu atomique, idempotence, scopes et tests négatifs n'est pas prouvé. La parité des 92 codes d'action Android/Edge ne doit pas être confondue avec 92 handlers métier.

Ordre de fermeture : N4-A handlers serveur réellement disponibles (dépendance N2), N4-B couche de données Web et pull entrant, N4-C raccordement écran par écran, N4-D recette navigateur/PostgreSQL et convergence Web↔Android. Les actions sans handler restent fail-closed ; aucun événement générique ne remplace un contrat métier absent.

Garde-fous inchangés : branche de travail uniquement, aucun changement de `main`, aucun déploiement, aucune migration sur le Supabase historique NAXA/pharmacie, aucun secret dans Git. Le rapport est un audit documentaire, pas une validation CI ni une clôture fonctionnelle N4.


## 21. N4 — raccordement du socle Web Sync — 22 novembre 2026

Le Web récupère maintenant le `device_id` de l'Edge Auth, crée des séquences outbox monotones persistées par appareil, pousse les événements via `apply_sync_event` avec contrôle du reçu SQL `event_id` et statut final, et consomme `pull_sync_changes` avec persistance atomique des pages et curseurs. Les changements serveur sont visibles sans echo dans l'outbox.

Les faux parcours locaux (formulaires génériques, transitions pressing, réglages organisation non connectés) sont bloqués en session réelle ; l'aperçu local reste identifié. N4-C et N4-D restent ouverts tant que les formulaires/projections métier par module et les tests navigateur bout en bout ne sont pas livrés. Aucun déploiement hébergé ; main et Supabase NAXA/pharmacie historique restent intacts.


## 22. N4-C — couverture multisecteur des parcours métiers — 23 novembre 2026

Cette section complète et prévaut sur toute lecture qui ferait du Pressing le parcours fonctionnel de référence de NAXA SERVICES. NAXA SERVICES est un ERP multisecteur : **les parcours métiers doivent avancer ensemble sur un socle partagé**. Le Pressing reste un parcours dédié parmi les 13 profils, pas le modèle à étendre aux autres activités.

### 22.1 Périmètre couvert

Les 13 profils présents dans le contrat Auth sont :
`pressing`, `coiffure`, `couture`, `beaute`, `parfumerie`, `reparation`, `menuiserie`, `garage`, `nettoyage`, `domicile`, `impression`, `photo_evenementiel`, `autre`.

Matrice détaillée : [NAXA_SERVICES_ACTIVITY_PARITY_MATRIX_2026-11-23.md](NAXA_SERVICES_ACTIVITY_PARITY_MATRIX_2026-11-23.md).

Le référentiel Web `apps/web/naxa-services/src/erp/activity-workflows.ts` décrit pour chaque profil son objet métier, son parcours, ses champs spécifiques requis, ses transitions et ses modules partagés. Le profil provenant d'Auth est conservé par la session Web. Un profil manquant ou inconnu retombe sur `autre`, jamais automatiquement sur Pressing.

### 22.2 Code ajouté / corrigé pendant cette passe

- Référentiel et fonctions de validation des 13 parcours Web ; tests Vitest couvrant l'exhaustivité, le fallback, les champs requis et les transitions sectorielles.
- Nouveau module Web « Dossiers métier » qui charge le profil d'activité de l'organisation, expose les champs propres à ce profil et crée les dossiers via l'outbox N3 et le contrat serveur.
- Types de registre : `work_order` (production/commandes), `repair_order` (garage/réparation), `service_order` (coiffure/beauté/interventions). Le Pressing conserve `pressing_order`.
- Transitions Web versionnées avec motif obligatoire, `expected_version` et exigence d'un reçu serveur avant l'étape suivante ; projection des dossiers reçus d'un autre appareil.
- La parfumerie utilise le catalogue/stock/fournisseurs/POS pour les ventes normales ; le nouveau dossier ne concerne que les commandes spéciales et réservations. Le dossier ne confirme aucun paiement.
- Android : routes de dossiers ouvertes pour coiffure, beauté et parfumerie ; profils coiffure/beauté raccordés à `service_order`, réparation/garage à `repair_order`, photo/événementiel à `work_order`. Champs principaux et spécifications obligatoires avant création ; prestataire indiqué comme souhaité et non comme affectation RH validée.
- Android : un acompte demandé n'est plus écrit dans `paid_xaf`. Seul un paiement métier confirmé pourra alimenter le montant réellement encaissé.
- SQL candidat v4 : matrice de transitions de `work_order`, `repair_order` et `service_order` alignée sur les étapes spécialisées ; tests de contrat Deno ajoutés pour création, transition, spoofing d'identifiant et écart de site.
- Aucun changement sur la matrice des 92 actions N1/N2 ni sur le verdict de clôture N3.

Commits de cette passe : `88fa2ff`, `120e54d`, `edd0f4a`, `c4f4170`, `7c170b8`, `25d7136`, `c0461ac`, `b59e62a`, `8b1e55c`, `3c842c3`, `b9057a5`, `dbae18c`, `f5e754b`, `347e38c`, `fef9974`, `74bcd43`, `35182f7`, `fcf8d9d` et la matrice documentaire `14c5e9d`, tous sur la branche de travail.

### 22.3 Qualification honnête — ce qui est fait et ce qui n'est pas encore vert

| Point | Qualification au moment de l'écriture |
|---|---|
| Inventaire des 13 profils | Code et matrice documentaire ajoutés |
| Champs et cycles spécialisés Web | Référentiel et écran ajoutés ; gate de build/tests encore en cours |
| Dossiers Web via outbox et journal N3 | Code raccordé au contrat candidat ; validation CI et serveur à prouver |
| Champs et cycles Android | Couverture locale enrichie et routes alignées ; recette Android de cette passe à exécuter |
| Matrice SQL v4 | Brouillon corrigé et non déployé |
| Tests de profil Vitest / contrat Deno | Écrits ; résultats d'exécution non encore confirmés au moment de cette note |
| E2E Web ↔ Android pour les 13 profils | Non démontré |
| Parité complète de tous les modules partagés | Partielle ; l'agenda, la caisse complète, ventes/paiements/reçus, CRM/fidélité, achats, RH/commissions, projections et rapports restent des chantiers séparés |

**Run CI observé pendant la passe :** run #511 `45154162146`, SHA `74bcd433ad41f2cb4682b109b503398b3130ee0d`, statut `pending` au dernier instantané lu ; run #510 `45154138961`, SHA `fef997446eab99db0303d4561bd53a7741b1c95c`, statut `in_progress`. Ces statuts ne sont pas des PASS. Le dernier SHA de code avant cette mise à jour documentaire est `fcf8d9d6099be65e5680942a5853a2c87d0ea5ce`; le commit de la matrice est `14c5e9dcc75e77f2dbbf8f630fc79ab7c9b4fab5`.

### 22.4 Reprise N4 à partir du point d'arrêt

Le socle N3 et ses preuves historiques ne sont pas à refaire. Le chantier reprend sur N4-C/N4-D :
1. finaliser le parcours métier générique Web et ses projections, puis faire fonctionner et tester les cycles spécialisés des 13 profils ;
2. compléter les modules partagés Web : agenda (disponibilités, modifications, annulations), caisse/ventes/paiements/reçus, catalogue/stock/achats/fournisseurs, CRM/fidélité, équipe/commissions, rapports et réseau ;
3. aligner ces opérations sur Android et vérifier les mêmes états métier, identifiants stables et règles de version ;
4. exécuter le build, Vitest, Deno, Kotlin/Room, PostgreSQL 17 jetable et Playwright ; puis démontrer la réplication A↔B et les tests négatifs de scopes ;
5. clôturer chaque lot avec une preuve CI et une matrice de résultats. Un code présent, un formulaire ou un run pending ne vaut jamais VERT.

**Points d'attention avant activation :** les valeurs métier qui n'ont pas été validées (tarification, fiscalité, garantie, conservation, annulation/remboursement, commissions, frais de déplacement et règles contractuelles) restent configurables et ne doivent pas être inventées. Les données sensibles ou confidentielles de dossiers doivent faire l'objet d'un contrôle d'accès et de conservation avant d'être exposées à d'autres rôles ou sites.

**Garde-fous inchangés :** branche `work/naxa-services-completion-20261120` uniquement ; aucun commit sur `main`, aucune fusion, aucun déploiement, aucune migration hébergée ; aucun accès ni changement au Supabase historique NAXA/pharmacie.


### 22.5. Corrections de gate après lecture des logs — 23 novembre 2026

Le premier gate qui a effectivement démarré a mis au jour quatre incohérences :
1. le test de parité demandait `measurement → quote_pending` pour la couture, alors que le registre Web n'avait pas encore l'étape `measurement` ; l'étape « Prise des mensurations » a été ajoutée, raccordée à `received`, avec les transitions prévues par Android et le SQL candidat ;
2. les deux nouvelles fixtures Deno utilisaient des UUID dont le dernier groupe était trop court ; les identifiants de test ont été corrigés ;
3. `OBX-050` du registre N1 pointait la ligne 4019, alors que l'ajout des contrôles métier avait déplacé l'appel source à la ligne 4053 ; le JSON de référence a été rafraîchi ;
4. les contrôles Android de dossier séparent désormais explicitement l'acompte demandé de `paid_xaf` : la demande est dans `metadata_json`, le payé reste nul tant qu'un événement de paiement confirmé n'existe pas. Le prestataire indiqué dans le formulaire n'est pas une affectation RH.

Commits de correction : `9106577` (étape couture), `a609a62` (fixtures Deno), `aba1fc4` (registre OBX-050). Code Android correspondant : `35182f7` et `fcf8d9d`.

**Résultat d'exécution constaté :** le run #511 (`45154162146`, SHA `74bcd43`) a terminé ses jobs avec trois échecs identifiés :
- Web build job : test Vitest de parité couture, corrigé ensuite ;
- contrat comptable fournisseur : deux fixtures Deno `INVALID_AGGREGATE_ID`, corrigées ensuite ;
- contrat de synchronisation hors ligne : vérification du registre N1 `OBX-050`, corrigée ensuite.

Le run #510 (`45154138961`) a été annulé par les commits suivants. Le run #512 (`45154704480`, SHA `a609a62`) était encore `in_progress` au dernier contrôle et le run #513 (`45154731735`, SHA `aba1fc4`) était `pending` sans jobs exposés. Leurs résultats ne sont donc pas considérés comme PASS.

**État de travail :** les causes précises identifiées ont des corrections commitées. Il reste à obtenir un run complet sur le dernier SHA de branche, vérifier le build Web/Android et corriger les erreurs qui resteraient. Ne pas reprendre un autre chantier N4 tant que les jobs métier n'ont pas fourni de preuve.

### 22.6 — Recette des dossiers entre installations et pointage Web, 25 novembre 2026

Le [run #586](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45581399138) a validé les 12 jobs du commit `1f972df`, après l’annulation du #585.

La nouvelle recette PostgreSQL 17 exerce les douze activités à dossier générique avec deux sessions et deux identifiants d’installation. Le premier appareil crée le dossier et le mène à la livraison. Le second lit sa révision par le journal et le clôture. Le premier reçoit la clôture avec la même révision que la ligne métier. La suite SQL locale a réussi sur une base jetable. Le Pressing conserve sa recette transactionnelle dédiée jusqu’au retrait.

Le Web conserve désormais le titre, le client et les champs sectoriels lors de la réception d’une transition et protège la révision affichée contre un reçu plus ancien. Le pointage personnel tient compte du membre connecté et de ses événements en attente. Les tests Chromium utilisent une API simulée. La recette PostgreSQL utilise les fonctions de synchronisation réelles. Une recette réunissant les deux applications sur le même backend reste à démontrer.

La qualification des paiements marchands, des notifications FCM et de la distribution Android signée reste distincte. Une validation sur service hébergé exige un environnement NAXA SERVICES identifié et une autorisation de déploiement séparée.

La vérification du client Android a révélé deux écarts supplémentaires. La transition Web d’un dossier arrive avec son type dans l’enveloppe, alors que le client Android exigeait aussi ce type dans le contenu. Ensuite, Android comptait uniquement ses propres écritures pour préparer la révision attendue. La correction applique la transition distante au dossier Room et reprend sa dernière version effectivement appliquée, y compris quand des étapes locales se succèdent. Le test instrumenté reproduit un dossier Garage passé au diagnostic côté Web et vérifie les révisions 2 puis 3 des deux commandes Android suivantes.


### 22.7 — Cloisonnement Web multisite, protection des sessions et suivi CRM — 25 novembre 2026

Branche inchangée : `work/naxa-services-completion-20261120`. Aucun déploiement, aucune fusion dans main, aucune migration sur NAXA pharmacie.

| Écart confirmé | Correction | Preuve observée |
|---|---|---|
| Dossiers métier/Pressing non filtrés par point de vente actif | Sélecteur de site et contrôle des transitions (`dcc64ea`) | Recette multisite réussie dans le run #592 après correction du sélecteur de test (`5fd789f`) |
| APK signé potentiellement sans configuration backend/Firebase | Validation de configuration dédiée, refus des clés privilégiées, activation du sync Release (`bfd8494`) | Contrat de configuration réussi dans le run #590 ; aucune signature réelle réalisée |
| Réponses asynchrones d'une ancienne connexion pouvant réinjecter des données | Garde par génération de session, nettoyage à la déconnexion (`b75bb4c`) | Test ajouté ; #592 a expiré car la seconde connexion naviguait et annulait la requête ; correction `7ebbeb7`, revalidation attendue |
| Auth et parrainage ne contrôlant pas la révocation dans toutes les actions authentifiées | Vérification de la liaison compte/session/appareil actif après validation Auth, liste des appareils propres au compte et révocation confirmée (`abcb8b3`) | Contrats Auth/parrainage réussis sur #594 ; recette Web en cours |
| Suivi CRM sans clôture/reprogrammation Web | Raccordement à `customer_followup.completed` et recette création → reprogrammation → clôture (`2927983`) | Test écrit, exécution non confirmée |

Dernier gate de code déclenché : [#595](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45663189559), SHA `2927983f8ec0581fb7fc98183c17758296ec8b8e`. Il n'est pas déclaré vert tant que les douze résultats n'ont pas été vérifiés. Les exécutions intermédiaires #590–594 ont été interrompues ou remplacées selon la concurrence du workflow ; elles ne constituent pas un PASS complet. Le dernier gate 12/12 intégralement terminé avant ces changements reste #588.

Restent à démontrer : recette des applications Web et Android sur un backend commun, parité exhaustive des opérations ERP partagées, intégrations marchandes et FCM réelles, conformité/recette physique, signature Release et environnement NAXA SERVICES dédié. Ne pas confondre les tests simulés et les transactions réelles ni inventer de nouveaux secrets ou de nouvelles règles financières.


### 22.8 — Correction de la dernière recette Web rouge, 25 novembre 2026

Le run #595 a terminé à 11/12 jobs verts : Android (APK et tests instrumentés), PostgreSQL 17/RLS, politique financière et tous les autres contrats ont réussi. L'unique job rouge était le Web, avec 11 scénarios Playwright réussis sur 12. Le scénario CRM échouait sur le sélecteur exact du champ client, avant la création du suivi.

Le correctif `192111fc21e2ed965c826011d4e64fd4657b0507` attribue au champ un nom accessible explicite, attend la présence de l'option client issue du reçu et vérifie le statut confirmé lors de la clôture. Le mock de recette incrémente les révisions des suivis CRM comme le contrat transactionnel. Aucune recette supprimée ou désactivée.

**Preuve :** [run #596](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45676579558), [job Web](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45676579558/job/139425616194), journal `12 passed (45.1s)`. Au moment de cette note, 11 jobs du run #596 ont réussi, Android est encore en cours ; aucun échec observé. La comparaison entre les SHA de #595 et #596 ne contient que deux fichiers Web et ce document, donc le code Android précédemment validé n'a pas changé. Le PASS du nouveau job Android et la conclusion globale du run restent à constater.

Aucun changement de main ni déploiement. Les gates de recette intégrée sur backend commun, parité exhaustive et activation réelle restent distincts de ce correctif CI.


### 22.9 — Clôture du gate technique #596, 25 novembre 2026

**VERT 12/12.** GitHub Actions confirme la conclusion `success` du [run #596](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45676579558) sur le commit de code `192111fc21e2ed965c826011d4e64fd4657b0507`. Les douze jobs sont terminés avec succès, y compris le dernier job Android : tests unitaires, compilation APK, tests instrumentés sur émulateur et upload APK Debug. Les douze scénarios Web E2E ont également réussi. Le précédent commit documentaire ne change aucun fichier de code. Aucun nouveau correctif nécessaire pour ce gate. Les validations intégrées sur backend commun, parité exhaustive et activation de production restent distinctes ; ce PASS ne constitue pas un déploiement ni une signature Release.


### 22.10 — Arbitrage propriétaire : paiement des abonnements exclusivement, 25 novembre 2026

**Décision validée :** les encaissements des entreprises clientes sont réalisés hors NAXA SERVICES et enregistrés manuellement dans l'ERP (espèces, MTN, Orange, virement, chèque, mixte selon les modes disponibles). NAXA ne collecte pas leurs fonds, n'initie pas leurs paiements, ne prélève pas de commission sur ces encaissements et n'exige pas de compte marchand pour chaque entreprise. Le paiement numérique intégré concerne uniquement la souscription, le renouvellement et les extensions d'abonnement NAXA SERVICES. Cette décision prévaut sur les anciennes mentions de paiement marchand pour les ventes et acomptes ERP.

**Référence NAXA pharmacie :** `src/lib/merchant-payment.ts`, `android/payment-companion/README.md`, migrations `20261117061242_partner_subscription_paired_sms_verification.sql` et `20261117061423_partner_subscription_sms_distinct_actor_guard.sql` du dépôt NAXA. Paiement chez l'opérateur via USSD, déclaration volontaire du débit, crédit reçu sur un appareil bénéficiaire NAXA enrôlé, rapprochement unique (canal, référence, montant, destination, numéro, horaire, empreintes et acteurs distincts), activation atomique et reçu seulement après double preuve. Pas de PIN collecté, pas de lecture SMS du téléphone payeur. Aucun besoin d'API marchande pour le modèle USSD de référence ; toute future API opérateur reste limitée aux abonnements.

**Implémentation de ce lot :** draft v8 isolé (destination centrale, intentions, preuves, abonnement et reçu), tarif calculé côté serveur sur le catalogue ACCESS/PREMIUM mensuel/annuel, RPC authentifiées côté payeur avec droit de gestion organisation, RPC de confirmation réservée au service serveur et à un appareil admin enrôlé, preuve simple non confirmante, verrou transactionnel et protection anti-rejeu, tests PostgreSQL jetables ajoutés au gate. Aucun numéro marchand réel inventé. Les destinations sont désactivées par défaut. Les anciennes tables de callbacks ERP v7 ne sont pas utilisées par ce flux.

**Restent ouverts :** intégration des écrans Web/Android et du compagnon admin NAXA (capture et parsing de vrais SMS, liaison sûre du backend), revue manuelle des preuves ambiguës, verrouillage des droits selon la période d'abonnement, extensions selon règles validées, séparation des références entre produits via destination distincte ou registre central, correction des parcours ERP encore marqués attente de prestataire, tests SIM réelles, déploiement dédié. Aucune preuve de paiement réelle ni configuration Supabase hébergée. Le gate précédent #596 reste la référence avant ce changement ; le nouveau résultat CI doit être constaté.

Complément 22.10 : écran Web abonnement dans PME & organisation, passerelle Auth et analyse côté SQL du SMS de débit volontaire (formats MTN/Orange issus de NAXA) ; le payeur ne peut plus soumettre une empreinte arbitraire. Aucun SMS brut conservé. Les formats inconnus restent bloqués pour revue. Le compagnon de capture bénéficiaire et le parcours Android natif restent à raccorder.

Complément ERP : les nouvelles ventes Mobile Money et acomptes non espèces sont des encaissements manuellement déclarés déjà reçus ; code Web/Android et SQL de vente/pressing adaptés. Les anciennes ventes pending restent annulables pour reprise historique, non proposées comme nouveau parcours. Le serveur journalise `manual_external`, hors caisse physique ; aucun appel opérateur. Les modes virement/chèque/mixte détaillé nécessitent encore une extension du formulaire et de la matrice de preuves, et la recette de ces modifications reste à constater.

Complément : parcours Android natif Abonnements raccordé au même endpoint Auth ; la demande locale n'est plus le nouveau parcours. Capture bénéficiaire serveur réservée à un appareil central enrôlé (identité Auth/session/destination/consentement SMS), analyse stricte des SMS crédit MTN/Orange, conservation structurée des candidats et rapprochement même lorsque le crédit arrive avant le débit. Le libellé expéditeur n'est jamais à lui seul une authentification financière. La capture physique doit encore être raccordée à un compagnon NAXA Services distinct (ou à un compagnon central configuré et autorisé), sans changer NAXA pharmacie. Les anciens brouillons locaux sont conservés, pas validés automatiquement. Les droits/essai initial, extensions/prorata, revue administrative, destinations distinctes ou registre global de références et recette opérateur réelle restent des gates séparées. Le code ne collecte jamais le PIN ; il n'active aucun abonnement à partir d'une preuve unique.


### 22.11 — Paiement abonnement : contrôle de reprise, 25 novembre 2026

Le [run #602](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45681228817) a confirmé les 12 jobs SUCCESS sur `7bc84fb`, avec le draft v8, les écrans Web/Android, la capture serveur et le rapprochement en PostgreSQL jetable. Nouvelle passe : le RPC de gestion d'abonnement applique lui-même le rôle Promoteur ; expiration des intentions non déclarées à la consultation ; abandon explicite et idempotent uniquement avant déclaration, avec attestation qu'aucun paiement n'a été effectué. L'interface Web et Android expose cette action. Une demande déclarée/confirmée ne peut jamais être annulée de cette manière. Le test crédit-premier vérifie désormais la clé réelle `status` avec comparaison non nullable, et les tests couvrent le refus d'annulation d'une déclaration, le consentement et la réouverture. Le nouveau gate doit être constaté avant de déclarer ce lot vert. Aucun numéro marchand réel, aucun déploiement, aucun changement du dépôt NAXA pharmacie. Restent la capture physique du téléphone bénéficiaire, la revue des anomalies, les droits d'abonnement et les recettes en environnement dédié.


### 22.12 — Revue administrative et état des droits payés

Le run #603 a validé les contrats Auth, PostgreSQL/RLS et les recettes Web ; le dernier job Android était encore en cours à la lecture. Ce lot ajoute une file de revue des crédits ambigus, limitée au canal et à la destination de l'appareil administrateur enrôlé et à sa session Auth. Le rejet motivé est idempotent et journalisé ; aucun administrateur ne peut transformer un rejet en confirmation ni modifier les preuves par ces RPC. La déclaration du payeur reste en attente. L'état serveur des droits payés est consultable par un membre actif de l'organisation : active, expired, cancelled, not_started ou unconfigured (calendrier Africa/Douala). Aucune règle d'essai ou de grâce inventée et aucun verrou ERP activé sans arbitrage de politique. Les tests couvrent l'isolation, le crédit incohérent, le refus d'action du payeur, le rejet et le maintien de la période payée. L'interface administrative de capture physique, la résolution des déclarations bloquées, la politique d'essai/expiration et la recette SIM restent à compléter. Aucun déploiement.


### 22.13 — Contrôle contradictoire du gate #604 et abandon Android

Le [run #604](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45713479110) a terminé avec 12/12 jobs réussis sur `0d77b19defac9992b33cefe8adabb3f8cd1f0b56`. Le run #603 a finalement été annulé par le suivant ; ses résultats intermédiaires ne valent pas gate complet.

Malgré ce PASS, l'audit source a établi un défaut d'exécution : ManagementModules appelle subscription_cancel, mais AuthApi.subscriptionRequest rejetait cette action avant tout appel réseau. La liste des quatre actions payeur est désormais commune à la validation de la requête et à un nouveau test unitaire positif/négatif. Les actions administratives restent exclues et le serveur conserve les contrôles d'abandon avant déclaration et d'attestation de non-paiement. Le nouveau gate reste à constater.

L'état des droits payés est calculé côté serveur mais aucun verrou métier n'est déclaré actif. Ne pas inventer une durée d'essai, de grâce ni une politique d'accès en cas d'expiration ; la capture bénéficiaire physique et les recettes dédiées restent ouvertes. Aucun déploiement ni modification de main ou du Supabase pharmacie.


### 22.14 — Droits payés : raccordement des clients — 26 novembre 2026

Le [gate #605](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45716787429) est SUCCESS 12/12 sur `c5a371e687a0b97251e94fb00e09978d229a33b9`. La correction de l'abandon Android est validée par les contrôles CI.

Le serveur exposait subscription_access sans client Web ni Android. Cette passe raccorde la consultation de l'état payé (active, expired, cancelled, not_started, unconfigured) aux deux interfaces, séparément des opérations de règlement réservées au Promoteur. L'interface ne déduit pas les droits de la date locale ni d'une déclaration SMS. La consultation est indépendante du paiement ; le rafraîchissement des demandes efface l'ancien état payé affiché. Une recette navigateur simulée couvre la lecture par un membre et le passage actif → expiré. Commits de code : `34f82ff`, `bb22eae`, `fe79a91`, `60d2277`, `c361d7c`, `cdec1d6`, `3eaf0ee`. Nouveau gate à constater. Le verrou ERP, les règles d'essai/de grâce et d'accès hors ligne, et la capture bénéficiaire physique ne sont pas déclarés livrés. Aucun déploiement ni modification de main ou du Supabase pharmacie.


### 22.15 — Passe groupée : compagnon bénéficiaire, revue, formules et preuve Orange — 26 novembre 2026

Le [run #612](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45744107134) est terminé SUCCESS 12/12 sur `3eaf0ee` : consultation des droits Web/Android et recette Web précédente validées.

La nouvelle passe réutilise les composants SecureVault, HttpClient, SupabaseSession et le principe de séparation des APK de NAXA pharmacie, sans modifier son dépôt. `22ac6b8` ajoute le module Android indépendant `naxa-services-beneficiary`, une vérification de l'appareil enrôlé côté Edge, le filtre local du canal et des messages de crédit, la permission et le consentement, la transmission et le panneau de revue/rejet motivé. L'identité du compte central et sa session doivent être enrôlées hors application par un administrateur autorisé ; l'APK n'attribue aucun rôle et ne fabrique aucune preuve. Le serveur conserve le rapprochement à deux acteurs. Le module n'enregistre pas de corps SMS brut ; une panne de transmission exige une procédure de rapprochement support, pas une fausse confirmation. La permission RECEIVE_SMS ne figure pas dans l'APK ERP payeur.

`de74b72` synchronise la restriction ACCESS au mode solo (PREMIUM pour plusieurs postes/sites) à la création des intentions dans SQL, Web et Android, sans changer les périodes déjà payées. La recette jetable ajoute un paiement Orange complet, le refus d'une session administrateur différente et d'un appareil du mauvais canal, puis vérifie l'émission du reçu. Le compagnon refuse les clés privilégiées et son APK debug est inclus dans les artefacts CI. Le gate #613 était en cours à la lecture ; le gate du dernier commit de code reste à constater.

**Dépendances externes constatées :** le connecteur Supabase ne liste que le projet historique NAXA ; aucun projet Famille dédié n'est accessible dans cette connexion. Aucun accès en écriture à ce projet, aucune migration ni déploiement. L'enrôlement réel, les comptes bénéficiaires distincts/registre central, les tests SIM, les tests Web/Android sur backend commun, le comportement en cas de panne réseau du compagnon, les workflows de résolution financière des déclarations bloquées, la signature Release et les services externes restent des gates à prouver. Les règles de durée d'essai, grâce, accès après expiration/hors ligne, et extensions spécifiques NAXA SERVICES ne sont pas arrêtées de manière suffisamment cohérente dans les sources pour être imposées ; le moteur existant et les décisions validées doivent être réconciliés. Aucun verrou ERP ni prélèvement automatique déclaré actif.


### 22.16 — Préparation avant Supabase : droits ERP, reprise offline et isolation du compagnon

Le run #614 a confirmé les onze jobs non Android, les tests unitaires Android (ERP et compagnon) et l'assemblage des deux APK. Sa recette instrumentée a été interrompue par le gate suivant ; ne pas le déclarer 12/12. La dernière preuve complète antérieure reste #612.

Sources retrouvées : cahier `7 famille naxa/01-cahiers-des-charges/04-naxa-services.md`, S9 et critères d'acceptation ; moteur `packages/billing-core/src/index.js` et son test de la durée NAXA SERVICES. Le draft v8 applique l'essai Famille de 72 heures à partir de la création administrative de l'organisation (choix technique explicité), une seule fenêtre provisoire de 24 h à partir d'une première déclaration non confirmée après le dernier paiement, et une période payée évaluée au calendrier Africa/Douala. L'état payé reste distinct de l'autorisation ERP. L'expiration bloque les helpers de site/poste et les RPC push/pull ; les politiques restrictives empêchent les lectures directes des catalogues/services et fidélité d'organisation. Authentification, statut et règlement restent accessibles ; les données ne sont pas effacées. L'accès provisoire n'est pas un reçu ni une activation payée. Les interfaces Web et Android exposent ces états.

`2eaa3d7` : implémentation initiale et test. #615 : échec PROVISIONAL_ACCESS_FAILED (fixture datant artificiellement une intention jamais déclarée) ; `1cb6b56` corrige la fixture, distingue le code SQL exact de suspension en HTTP 402, et préserve les files Web/Android avec reprise différée. Le test IndexedDB répète quinze suspensions sans consommer le quota de retries. #616 : PostgreSQL 17/RLS et dix jobs terminés avec succès au dernier relevé, Web/Android non conclus. `2cdac81` complète la protection des catalogues org-wide, exclut les déclarations déjà confirmées de la fenêtre suivante, teste la conservation et la restauration d'accès, filtre les OTP/PIN dans le compagnon et refuse toute configuration autre que le projet Famille dédié (ref concordante, URL canonique, JWT anon de ce ref). Le dernier gate de code doit être constaté.

Limites : tolérance offline locale 7/14 jours à mapper aux nouveaux paliers ACCESS/PREMIUM, parrainage avec crédit d'entitlement réel (mensuel et extension annuelle ACCESS distincte), prorata/extension, procédure financière des déclarations bloquées et test SIM restent ouverts. Le verrou ERP serveur décrit ci-dessus est candidat, non déployé ; ne pas confondre RLS jetable, preuve de contrat et recette hébergée. Les paramètres Firebase, la signature Release et les comptes bénéficiaires ne sont pas inventés ; le connecteur GitHub ne permet pas de lire l'inventaire des secrets dans cette passe. Aucune migration, création de projet ou écriture dans Supabase hébergé ; aucun changement de main ni déploiement.


### 22.17 — Contrôle du gate #617 et incident de capture bénéficiaire

[Run #617](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45746039381) : SUCCESS 12/12 sur `2cdac81a3f72a54e60b522f85f27394a18283092`. Les douze jobs (Web, Android, PostgreSQL/RLS et contrats) sont confirmés. Le commit documentaire suivant ne modifie pas le code.

Audit contradictoire : le compagnon écrasait last_status après chaque capture, ce qui masquait un échec antérieur. Correctif `411f1f0`, `265260d`, `10df501`, `518cc2d`, `1022e15`, `c5e9ef0` : compteur local durable par appareil enrôlé, enregistré avant envoi, décrémenté uniquement après réponse serveur avec état de candidat reconnu. Un succès ultérieur n'efface pas un incident antérieur. Le compteur n'enregistre ni contenu SMS, montant, numéro, identifiant de transaction ni secret. L'interface demande un rapprochement administratif et interdit d'en déduire un nouveau paiement. Tests unitaires des transitions et états d'accusé ajoutés. Ce compteur ne retransmet pas un SMS perdu et n'est pas un rapprochement financier : la procédure de récupération et la recette SIM restent ouvertes. Nouveau gate à constater.

Les autres gates de 22.16 restent ouverts : tolérance offline 7/14 jours (anciens paliers à réconcilier avec les nouveaux modes), récompenses parrainage et extensions/prorata appliquées à l'abonnement, procédures financières, backend Famille isolé, SIM, recette intégrée et signature Release. Aucun déploiement ni modification du projet pharmacie.


### 22.18 — Prévol Supabase et durcissement du compagnon (26 novembre 2026)

Vérification directe du run [#617](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45746039381) : 12/12 SUCCESS. Le run [#623](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45748023291), SHA c5e9ef0, a 11/12 SUCCESS au dernier relevé, y compris PostgreSQL 17/RLS, Web et contrats ; les tests unitaires des deux APK ont réussi, assemblage et recette instrumentée non conclus. Un nouveau gate peut annuler ce run en raison de la concurrence existante. Ne pas qualifier le nouveau commit de PASS sans contrôle des jobs.

Corrections de cette passe : deux drafts (v2 et referrals v1) terminaient par COMMIT malgré la règle rollback par défaut ; leurs terminaisons sont désormais ROLLBACK. Le gate exige ce garde-fou avant d'appliquer uniquement une copie transformée sur PostgreSQL jetable. Le compagnon efface les anciennes lignes de revue avant connexion, enrôlement ou actualisation, y compris si la requête échoue, et refuse une confirmation de rejet si l'appareil a changé. Aucune nouvelle politique tarifaire, aucun secret, aucune donnée réelle.

Prévol hébergé : organisation Supabase NAXA, plan Free, seul projet visible NAXA pharmacie (actif, eu-west-3). Aucun projet isolé Famille accessible ; création à confirmer dans l'organisation choisie, sans utiliser le projet pharmacie. Inventaire : neuf drafts spécifiques testés, dans l'ordre exact du gate : v1, v2, v3, v4, referrals v1, v5, v6, v7, v8. 76 instructions CREATE TABLE public et 76 instructions ENABLE ROW LEVEL SECURITY comptées dans les candidats (contrôle textuel, pas un inventaire de la base déployée). Les brouillons Famille génériques et 0002_famille_core_rls.sql ne doivent pas être appliqués automatiquement : dépendances et coexistence à examiner. La couche bootstrap Auth de CI est réservée au PostgreSQL jetable ; ne pas l'installer sur Supabase réel. Les six répertoires Edge hors _shared sont famille-account-lifecycle, naxa-services-accounting, naxa-services-auth, naxa-services-customer-promotions, naxa-services-notifications et naxa-services-referrals. Revoir leur portée, configuration JWT, secrets, RLS et grants avant déploiement. Préserver les drafts sources ; construire des migrations versionnées sur le backend isolé après audit, contrôler les droits et réaliser la recette intégrée Web/Android. Aucun accès SQL au projet historique, aucune migration ni déploiement.

Gates ouverts : mapping de tolérance hors ligne ACCESS/PREMIUM à réconcilier avec les anciennes offres (7/7/14 jours), récompenses parrainage et prorata/extensions réelles, procédure de résolution des preuves financières bloquées, recette SIM/FCM et signature Release. Ne pas décider les règles commerciales manquantes implicitement.

### 22.19 — Création du backend FAMILLE-NAXA et première installation hébergée (26 novembre 2026)

Autorisation propriétaire explicite : création du projet FAMILLE-NAXA dans l'organisation NAXA, sans frais supplémentaires non approuvés, et poursuite sécurisée de la configuration. Devis Supabase : 0 USD/mois supplémentaire. Projet **idupfjbkwjcavyisxteo**, région eu-west-3, PostgreSQL 17.12, ACTIVE_HEALTHY, URL https://idupfjbkwjcavyisxteo.supabase.co ; projet historique NAXA pharmacie ykgjfindlgseegmznaog exclu de toutes écritures SQL/déploiements. La liste Supabase confirme les deux projets actifs. Aucun secret commité.

Source figée : commit 24527f897be56b63240a4fc623e7dc4fc27f8c28, neuf drafts spécifiques NAXA SERVICES dans l'ordre du gate. Chaque migration hébergée reprend la source exacte avec terminaison ROLLBACK remplacée par COMMIT, sauf v5 où public.gen_random_bytes(4) devient extensions.gen_random_bytes(4) pour correspondre à pgcrypto hébergé. Conserver les drafts rollback ; ne pas les lancer directement sur la base. Aucune couche bootstrap Auth CI, ni migration Famille générique, ni modification du projet pharmacie.

| Version hébergée | Nom |
|---|---|
| 20261126032422 | naxa_services_v1 |
| 20261126032436 | naxa_services_v2_activity_onboarding_management |
| 20261126032438 | naxa_services_v3_operations_rewards_sync |
| 20261126032440 | naxa_services_v4_supplier_accounting_forecast |
| 20261126032442 | naxa_services_referrals_v1 |
| 20261126032444 | naxa_services_v5_customer_referrals_promotions |
| 20261126032446 | naxa_services_v6_notifications |
| 20261126032447 | naxa_services_v7_financial_controls |
| 20261126032449 | naxa_services_v8_subscription_payment |
| 20261126032512 | naxa_services_revoke_anonymous_access |

La dernière migration révoque les privilèges de PUBLIC et anon sur les tables, vues et séquences public.ns_* et l'exécution des fonctions public.ns_*, en conservant les droits explicites authenticated/service_role. Les définitions exactes sont enregistrées dans l'historique Supabase ; reconstituer les fichiers versionnés avant tout pipeline CLI global, en tenant compte du 0002 Famille préexistant. Ne pas rejouer ces migrations sur ce projet déjà installé. La correction de qualification pgcrypto v5 doit être réconciliée avec le draft source dans la prochaine passe CI.

**Preuves directes hébergées :** 76 tables ns_*, 76 RLS activées, 0 droit de lecture/écriture anon, 87 fonctions ns_* dont 0 exécutable par anon, accès SELECT service_role sur les 76. Le test supabase/tests/drafts/naxa_services_subscription_payment.sql (transaction unique BEGIN/ROLLBACK, sans COMMIT, fixtures synthétiques) a réussi sur la base dédiée encore vide ; requête post-test : 0 auth.users, 0 organisations, 0 destinations bénéficiaires, 0 intentions. Aucun flux monétaire réel. Les 32 tables RLS sans policy signalées par advisor n'accordent aucun droit DML/SELECT à authenticated (contrôle pg_catalog) : accès serveur seulement. Les 22 SECURITY DEFINER exécutables par authenticated restent à auditer en profondeur ; search_path vide confirmé. Ne pas les révoquer aveuglément car plusieurs sont des helpers RLS et RPC métier nécessaires. Pas de qualification production.

**Edge Functions v1 ACTIVE** vérifiées par list_edge_functions, source même SHA : naxa-services-auth, naxa-services-accounting, naxa-services-referrals, naxa-services-customer-promotions, naxa-services-notifications. Déployées avec leurs imports locaux et verify_jwt=false car contrôles Auth internes (login/refresh/recovery, JWT vérifié via Auth, signatures webhooks, worker secret). Les webhooks et worker sans secret restent bloqués ; aucun secret externe inventé. L'Edge famille-account-lifecycle n'est pas déployée (socle famille_private pas installé). Les contrôles HTTP/recette intégrée restent à effectuer ; statut ACTIVE ne prouve pas l'exécution métier. NS_ALLOWED_ORIGINS et NS_AUTH_ALIAS_DOMAIN à définir avec les domaines réellement validés ; secrets webhook/FCM et compte de service à configurer après audit. Destinations et enrôlement bénéficiaire réels non configurés. APK Release, recette physique SIM, politiques offline, récompenses/prorata et sauvegarde hébergée restent ouverts.

Gate #624 : 11 jobs SUCCESS, Android en cours au dernier relevé. Le présent commit est documentaire, ne doit pas relancer ce gate. Aucun changement à main, aucun déploiement Netlify, aucune diffusion publique ou activation de clients. La base isolée constitue un environnement d'intégration, non une production validée.


### 22.20 — Arbitrage propriétaire hébergement Web : Cloudflare Free (26 novembre 2026)

Netlify est exclu du périmètre par décision propriétaire. Cible retenue : Cloudflare Pages Free pour le frontend React/Vite NAXA SERVICES, Supabase FAMILLE-NAXA pour le backend, Android natif inchangé. Pas de changement de forfait ni d'achat de domaine sans autorisation. Les paiements d'abonnement restent Mobile Money hors collecte de données de carte ; les conditions Cloudflare Free interdisent la collecte/le traitement de données de carte bancaire sur les propriétés Web qui bénéficient des Free Services. Vérifier les conditions d'usage applicables (https://www.cloudflare.com/terms/) et les quotas (https://developers.cloudflare.com/pages/platform/limits/). Offre Free : 500 builds mensuels, assets statiques gratuits et illimités (https://developers.cloudflare.com/pages/functions/pricing/), pas de garantie de continuité de l'offre gratuite. Supabase Free peut suspendre les projets inactifs ; ne pas promettre de SLA de production.

Configuration Pages à utiliser après autorisation de l'intégration GitHub et confirmation de l'origine HTTPS effective : dépôt FAMILLE-NAXA, racine du monorepo (dépendances packages/contracts, packages/design-system, packages/offline-web), Node 22, commande npm run build --workspace @famille/naxa-services-web, sortie apps/web/naxa-services/dist (sortie Vite par défaut, à vérifier au premier build). Variables de build VITE_NAXA_SERVICES_AUTH_URL=https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/naxa-services-auth ; VITE_NAXA_SERVICES_ACCOUNTING_URL=https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/naxa-services-accounting ; VITE_SUPABASE_ANON_KEY=clé publique anon du projet dédié uniquement. Interdiction des clés service_role/secret dans le bundle. Déploiement initial réservé à la recette (pas d'ouverture commerciale avant validation) ; limiter les branches de preview et ne pas modifier main. Configurer NS_ALLOWED_ORIGINS côté Supabase sur l'origine Pages réellement attribuée, jamais un wildcard de convenance. Le domaine d'alias, secrets serveur et configuration FCM restent distincts.

Aucun accès Cloudflare connecté ni projet Pages créé dans cette passe. Aucun déploiement Netlify. L'autorisation GitHub sur Cloudflare et le choix du projet Pages doivent précéder la recette HTTP réelle. Le plan gratuit est un objectif de coût initial et non une garantie de disponibilité, de capacité ou de qualification production.


### 22.21 — Validation du budget Free et préparation Cloudflare Pages

Décision du propriétaire : rester sur les offres gratuites au démarrage ; prévoir une enveloppe mensuelle de 25 000 FCFA pour le futur passage Supabase Pro lorsque les moyens le permettront, sans déclencher de changement de forfait automatiquement. Netlify exclu.

Gate #624 vérifié : **12/12 jobs SUCCESS**, y compris Android et Web/PWA, pour le commit 24527f897be56b63240a4fc623e7dc4fc27f8c28. Run https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45748435178.

Le script scripts/naxa-services/cloudflare-pages-build.mjs (commit 9eb3121afdc044405b7256d90e158cf745dc9e01) prépare le build Cloudflare : vérification stricte des deux URL d'Edge Functions, clé JWT anon publique avec claim ref FAMILLE-NAXA et rôle anon, expiration et absence de variables VITE_* portant des noms de secrets ; puis build du workspace Web. Le contrôle local des claims n'est pas une validation cryptographique de la clé ; la recette HTTP doit vérifier la clé réelle auprès de Supabase. Aucune clé privée ni publique ajoutée au dépôt. Aucun lockfile npm racine constaté ; conserver la commande d'installation actuelle (npm install) et traiter le verrouillage des dépendances séparément avant qualification production.

Paramètres Pages : projet de recette proposé naxa-services, racine du dépôt, branche work/naxa-services-completion-20261120, preset None, commande node scripts/naxa-services/cloudflare-pages-build.mjs, dossier de sortie apps/web/naxa-services/dist, NODE_VERSION=22. Les trois variables VITE_ sont celles de la section 22.20. Pour la clé, utiliser la clé publique legacy anon du projet idupfjbkwjcavyisxteo uniquement (compatibilité client actuelle). Restreindre les previews et désactiver le déploiement automatique après la recette initiale jusqu'à autorisation commerciale. Ne créer aucun compte client réel avant qualification. Ne pas ajouter de domaine wildcard dans NS_ALLOWED_ORIGINS ; attendre l'origine HTTPS attribuée par Pages.

Limite : aucune session Cloudflare accessible depuis ce chat et pas de connecteur Cloudflare identifié. Le navigateur connecté n'est pas disponible dans le contexte actuel. Le propriétaire doit autoriser l'intégration GitHub depuis Cloudflare Pages, exclusivement pour FAMILLE-NAXA. Le script est commité mais son exécution sur Cloudflare n'a pas encore été vérifiée ; aucun projet Pages créé ni déployé. Pas de modification Supabase, main, NAXA Pharmacie ou Netlify dans cette passe.


### 22.22 — Portail officiel naxa.cm, distribution des solutions et transition DNS (26 novembre 2026)

**Décisions et orientations du propriétaire.** Achat envisagé le 27 novembre 2026 du domaine naxa.cm, destiné au site officiel de l'entreprise. Disponibilité, prix et achat non encore confirmés. Le portail présentera les services et les 11 solutions, chacune avec accès à sa version Web et téléchargement de son APK Android lorsqu'elle sera qualifiée. Ne pas attendre le domaine pour développer et effectuer les recettes. Conserver Cloudflare Pages Free, Supabase Free, GitHub et Android natif Kotlin/Compose ; passage futur Supabase Pro avec enveloppe cible 25 000 FCFA/mois lorsque les moyens le permettront, sur accord explicite. Aucun achat, changement de forfait, pack d'hébergement, certificat payant ou dépassement facturable non approuvé. Netlify exclu. Coût du domaine et renouvellement annuel distincts de l'hébergement. Les sous-domaines DNS ne nécessitent pas d'achat séparé.

**Plan d'adressage cible (proposé et retenu pour préparer l'architecture ; disponibilité et affectation effectives à vérifier).** Une application Web indépendante par solution, une origine HTTPS distincte, une configuration de liens centralisée et modifiable par environnement. Pas de dépendance de compilation au domaine définitif. Les adresses pages.dev ci-dessous sont des noms souhaités, et non des URL déjà attribuées ou des preuves de disponibilité.

| Périmètre | Projet / adresse temporaire souhaitée | Adresse définitive cible |
|---|---|---|
| Portail officiel | naxa-cm.pages.dev | naxa.cm (www.naxa.cm en redirection canonique) |
| NAXA Pharmacie | naxa-pharma.pages.dev | pharma.naxa.cm |
| NAXA SERVICES | naxa-services.pages.dev | services.naxa.cm |
| NAXA HOTEL | naxa-hotel.pages.dev | hotel.naxa.cm |
| NAXA SECURITY | naxa-security.pages.dev | security.naxa.cm |
| JOBLY | naxa-jobly.pages.dev | jobly.naxa.cm |
| KIOSKO | naxa-kiosko.pages.dev | kiosko.naxa.cm |
| COTIZ | naxa-cotiz.pages.dev | cotiz.naxa.cm |
| BOOTIK | naxa-bootik.pages.dev | bootik.naxa.cm |
| ZIPPLE | naxa-zipple.pages.dev | zipple.naxa.cm |
| LOYABLE | naxa-loyable.pages.dev | loyable.naxa.cm |
| CAMPUS237 | naxa-campus237.pages.dev | campus237.naxa.cm |
| Administration centrale | naxa-admin.pages.dev | admin.naxa.cm |
| Centre de téléchargement | à attribuer si projet distinct | download.naxa.cm |
| Support | à attribuer si projet distinct | support.naxa.cm |

Portefeuille officiel : FINTECH (COTIZ, KIOSKO), ERP (BOOTIK, ZIPPLE, LOYABLE), BUSINESS (NAXA, NAXA SECURITY, NAXA HOTEL, NAXA SERVICES), EDTECH (JOBLY, CAMPUS237). Ne pas annoncer une douzième solution ni de disponibilité non attestée. Le portail comprend accueil, catalogue, pages commerciales par solution (fonctionnalités, tarifs validés, accès Web, téléchargement Android), services (développement Web, applications, API de paiement), tarifs, téléchargements, partenariats, recrutement, assistance/FAQ/Livechat, à propos, contact/WhatsApp et documents légaux (CGU, confidentialité, mentions légales). Afficher clairement les états en développement, en recette et disponible ; liens d'accès et de téléchargement actifs uniquement après autorisation de mise en service. Administration centrale séparée, réservée aux habilitations autorisées ; pas de partage automatique des sessions ou des données entre sous-domaines. NAXA Pharmacie conserve son backend historique ykgjfindlgseegmznaog, FAMILLE-NAXA idupfjbkwjcavyisxteo accueille progressivement les autres applications, sous réserve d'audit des frontières de données. Ne pas modifier le projet pharmacie dans ce chantier.

**Distribution Android.** Centre de téléchargement officiel : APK Release signés, jamais Debug ; afficher application, version, versionCode, taille, compatibilité, date, nouveautés, empreinte SHA-256 et lien HTTPS. Vérifier signature apksigner, checksum, compatibilité des mises à jour et conservation sécurisée des clés de signature ; pas de clés privées dans le dépôt, le frontend ou les fichiers publics. Fichiers versionnés immuables, manifeste de versions, procédure de retrait/rollback, anciennes versions contrôlées. Pages pour les APK de taille <= 25 Mio selon limites du service ; R2 uniquement si besoin après validation de l'activation, des quotas et de tout risque de facturation. Aucun R2 activé dans cette passe. Prévoir vérification d'intégrité, procédure d'installation Android et mises à jour ; aucun APK non qualifié rendu public. Ne pas confondre disponibilité Web et qualification APK.

**Continuité avant achat.** Six axes parallèles : A — finalisation NAXA SERVICES et recette réelle ; B — portail institutionnel ; C — configuration Pages indépendante des onze solutions ; D — centre de distribution APK et mise à jour ; E — administration centrale et contrôle d'accès ; F — sécurité Supabase, sauvegarde/restauration testée, surveillance et continuité offline. Préparer les paramètres d'environnement, l'annuaire de liens et le catalogue de versions ; ne pas supposer que l'ensemble des apps existe ou est prêt. L'achat du domaine n'est pas un prérequis de développement. Aucune extension du chantier NAXA SERVICES ne doit retarder ses gates existants.

**Premier projet Pages NAXA SERVICES.** Le propriétaire a reçu la configuration exacte et décidé de la conserver pour Save and Deploy : dépôt FAMILLE-NAXA ; projet naxa-services ; branche work/naxa-services-completion-20261120 ; preset None ; root / (racine du monorepo) ; build node scripts/naxa-services/cloudflare-pages-build.mjs ; sortie apps/web/naxa-services/dist ; NODE_VERSION=22 ; VITE_NAXA_SERVICES_AUTH_URL=https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/naxa-services-auth ; VITE_NAXA_SERVICES_ACCOUNTING_URL=https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/naxa-services-accounting ; VITE_SUPABASE_ANON_KEY=clé publique legacy anon FAMILLE-NAXA transmise au propriétaire, non recopiée dans ce document. Ne jamais utiliser de service_role ni de clé secrète dans VITE_. Le clic et le résultat du build ne sont pas encore attestés ; attendre l'URL réelle et les logs pour contrôler le SHA, les assets et les appels HTTP. Première publication = recette technique, pas ouverture commerciale. Vérifier restriction des previews et absence de données réelles ; le terme « production branch » dans Pages n'est pas une homologation commerciale.

**Transition après achat du domaine.** Vérifier propriété, registrar, possibilités de changement des nameservers, inventaire DNS existant (préserver MX, TXT, SPF, DKIM, DMARC et autres enregistrements nécessaires), DNSSEC/DS selon procédure Cloudflare. Ajouter la zone naxa.cm au compte Cloudflare Free, changer les nameservers chez le registrar, vérifier activation de la zone, associer chaque custom domain depuis le projet Pages correspondant, vérifier DNS/TLS et redirections. Ne pas créer de CNAME Pages isolé sans rattachement préalable du domaine personnalisé dans Pages. Pour NAXA SERVICES : ajouter l'origine réelle pages.dev puis https://services.naxa.cm à la liste explicite NS_ALLOWED_ORIGINS pendant la transition, vérifier CORS/OPTIONS/POST, Auth et récupération, URL de redirection si requises, sessions et service worker ; retirer l'origine temporaire quand la bascule et les recettes sont terminées, sauf environnement de test distinct autorisé. Aucun wildcard CORS de convenance, aucun partage de cookies sur .naxa.cm sans justification. Les alias Auth internes ne sont pas des boîtes mail professionnelles et leur domaine doit être validé séparément. Les adresses email professionnelles nécessitent un service de messagerie distinct ; aucune gratuité ou création implicite.

**Gates et état réel au terme de cette mise à jour.** Gate #624 12/12 SUCCESS, code source validé sur 24527f8 ; 10 migrations, 76 tables RLS, 87 fonctions SQL et cinq Edge Functions actives sur FAMILLE-NAXA, selon preuves sections 22.19–22.21. Le script Cloudflare ajouté depuis ce gate n'a pas encore de preuve d'exécution Pages. Restent ouverts : premier build Pages, origine effective et CORS, recette HTTP et comptes de test, raccordement Android configuré, audit des 22 fonctions privilégiées, Storage/Realtime selon besoin et contrats, réconciliation des migrations, secrets serveur/FCM et appareil bénéficiaire opérateurs, règles offline et récompenses/prorata, sauvegarde/restauration, signature Release et recette physique. Aucun vrai client avant levée des blockers et validation de mise en production. L'offre Free n'est pas un SLA : surveiller quotas et risque d'inactivité, prévoir restauration et migration Pro en fonction des revenus. Aucun domaine acheté, DNS modifié, site officiel créé, déploiement Pages vérifié, APK publié ou dépense engagée dans cette mise à jour documentaire. Aucun changement à main, NAXA Pharmacie, Supabase ou Netlify.


### 22.23 — Premier hébergement Web Cloudflare vérifié (26 novembre 2026)

Les journaux fournis par le propriétaire montrent deux échecs initiaux : commit a229f62 sans script Cloudflare (mauvaise branche), puis commit e8a2705 avec variable VITE_NAXA_SERVICES_ACCOUNTING_URL invalide/manquante ; le garde-fou a bloqué le build. Après correction, le propriétaire a fourni https://0a1111aa.famille-naxa.pages.dev/. Contrôle HTTP avec rendu HTML : cette adresse et https://famille-naxa.pages.dev/ sont accessibles et affichent « NAXA Services — Gestion de votre établissement », l'espace de connexion sécurisé et l'identifiant fourni par le responsable. Le projet Pages réel utilise donc famille-naxa.pages.dev, non naxa-services.pages.dev (nom initial proposé). Le futur domaine cible reste services.naxa.cm. Le journal final de compilation, le SHA du déploiement réussi et les réglages de previews ne sont pas encore vérifiés. Ne pas recréer le projet Pages.

Supabase FAMILLE-NAXA ACTIVE_HEALTHY et cinq fonctions Edge ACTIVE vérifiés directement ; requête GET sur Auth renvoie 405, cohérent avec son contrat POST/OPTIONS, sans preuve d'authentification réussie. Le code Auth impose NS_ALLOWED_ORIGINS ; configuration serveur réelle et prévol CORS depuis https://famille-naxa.pages.dev à vérifier avant recette de connexion. Autoriser seulement cette origine stable (et, si nécessaire, l'origine de recette exacte, jamais wildcard). Aucune création de compte, modification de secret, paiement, migration, mise en production commerciale ou modification main/NAXA Pharmacie dans ce contrôle. Le vert porte sur l'accessibilité Web, non sur la qualification fonctionnelle intégrale. Toutes les autres gates de 22.22 restent ouvertes jusqu'à preuve contraire.


### 22.24 — Recette Web négative sur hébergement réel (26 novembre 2026)

Test navigateur TinyFish 108902ef-8290-4562-8e07-05c6d52daf37 sur https://famille-naxa.pages.dev/ : formulaire rendu, saisie fictive, une seule soumission, erreur visible `Failed to fetch`. Pas de statut HTTP ni d'en-têtes accessibles ; CORS probable mais non prouvé. Le bouton était signalé actif même avant saisie : contrôle UI à reproduire séparément. Aucun compte créé, aucun paiement ni reset. Curl depuis l'environnement local bloqué par DNS ; accès aux logs Supabase non concluant (requête de schéma non supportée). Le code Auth lit NS_ALLOWED_ORIGINS et ne retourne l'origine que si explicitement autorisée. Le connecteur ne dispose pas de gestion des secrets Edge. Action minimale : configurer NS_ALLOWED_ORIGINS=https://famille-naxa.pages.dev dans les secrets Edge du projet idupfjbkwjcavyisxteo, sans écraser d'autres origines légitimes éventuelles ; ne jamais utiliser wildcard. Puis rejouer prévol et test négatif, vérifier rejet métier, avant recette avec compte de test autorisé. Aucun changement de code, secret, base, main ou projet pharmacie. Le gate intégration demeure rouge.


### 22.25 — Recette Web après correction CORS (26 novembre 2026)

Recette navigateur réelle sur https://famille-naxa.pages.dev/ : rapport https://agent.tinyfish.ai/runs/ac2e20a8-12f9-4be4-bd8f-0df1e48f2d17. Une soumission avec identifiants fictifs a affiché « Identifiant ou mot de passe incorrect. » ; l'erreur `Failed to fetch` observée en 22.24 ne se reproduit plus. Le parcours Web d'authentification négative est validé côté interface, ce qui constitue une preuve fonctionnelle du rétablissement de la communication pour ce parcours. Aucun statut HTTP ni en-tête CORS n'a été directement observé ; ne pas extrapoler à toutes les origines, fonctions ou opérations métier. Authentification positive avec compte de recette autorisé, sessions, récupération, contrôle des habilitations et des refus inter-organisations, API comptabilité et autres modules restent à qualifier. Aucun compte créé, paiement, modification de secret, base, code, main ou projet pharmacie dans cette passe. Pas d'ouverture commerciale.


### 22.26 — Recette hébergée des habilitations et révocation (26 novembre 2026)

Audit direct du schéma des comptes, membres, organisations, sites et périmètres ; base initialement vide (0 Auth users, comptes, organisations, membres, appareils). Test SQL transactionnel BEGIN/ROLLBACK sur FAMILLE-NAXA uniquement : deux utilisateurs synthétiques (sans mots de passe ni sessions Auth réelles), deux organisations, trois sites, membre caissier limité à un site et membre promoteur d'une autre organisation ; appareil de test lié au claim session_id. SET LOCAL ROLE authenticated et claims synthétiques : six assertions PASS (ns_current_account_id pour session active, visibilité d'une seule organisation, visibilité d'un seul site autorisé, absence de droits de gestion du caissier, absence de fuite du membre tiers, révocation de l'appareil bloquant compte et visibilité organisations/sites). Résultat SQL explicite PASS ; rollback effectué. Il s'agit d'une recette SQL/RLS réelle, non d'une connexion Auth/JWT émise par GoTrue. Les comptes fictifs ne sont pas des comptes persistants. Aucun appel Mobile Money ni activation d'abonnement.

Connexion positive Web : nécessite création d'un utilisateur via l'API Auth Admin ou le dashboard autorisé et liaison ns_accounts/ns_members/ns_member_scopes ; le connecteur Supabase n'offre pas d'action Auth Admin et aucune session dashboard Supabase n'est disponible. Ne pas contourner en insérant un vrai compte à mot de passe directement dans auth.users, ni publier une passerelle de bootstrap privilégiée. Préparer un compte de recette isolé avec alias interne, aucun privilège transversal et mot de passe temporaire géré hors GitHub ; révocation et nettoyage après tests. Aucun changement main, NAXA Pharmacie, schéma, secret, code applicatif ou configuration Cloudflare dans cette passe. Les recettes HTTP positives et modules métier restent ouvertes.


### 22.27 — Qualification SQL des paiements et garde des RPC privilégiées (26 novembre 2026)

Sur idupfjbkwjcavyisxteo exclusivement : nouvelle exécution du fichier supabase/tests/drafts/naxa_services_subscription_payment.sql, transaction BEGIN/ROLLBACK, résultat PASS explicite. Les preuves synthétiques MTN/Orange, refus, rapprochement, idempotence, activation et séparation caisse/abonnement passent. Contrôle post-recette : 0 utilisateurs Auth, 0 organisations, 0 destinations, 0 intentions, 0 abonnements. Aucun opérateur réel ni SMS physique testé.

Inventaire direct : 76/76 tables ns_* avec RLS, 0 table avec privilège SELECT/INSERT/UPDATE/DELETE anon, 87 fonctions ns_*, 0 exécutable par anon, 22 SECURITY DEFINER exécutables par authenticated (search_path vide). Le test ajouté supabase/tests/drafts/naxa_services_unbound_session_guards.sql (commit f993cd30ac59d2397ec0a6a8e7c6412778ce49fd) a passé deux exécutions sur le backend hébergé : les 22 fonctions renvoient un refus, false, null ou blocked pour une identité synthétique sans session d'appareil liée. Le test est versionné mais pas encore intégré à un workflow CI. Les claims sont simulés au niveau SQL, aucun JWT authentique émis. Ne pas assimiler ce contrôle à une preuve exhaustive de toutes les branches d'autorisation. Revue des gardes : ns_erp_access_reason contrôle l'identité et le membre ; apply/pull sync contrôlent identité, organisation, appareil et abonnement ; les fonctions d'abonnement contrôlent le membre ou le payeur. Un écart de défense en profondeur à investiguer : ns_can_manage_site accepte s.site_id sans vérifier scope_type='site', contrairement à actorCanManageSite Edge ; le provisionnement normal ne donne can_manage au périmètre workstation qu'au rôle workstation_manager (non autorisé par cette RPC de gestion de site). Tester le cas d'une affectation incohérente et harmoniser après validation ; ne pas le déclarer exploitable en l'état ni vert exhaustif.

Le provisionnement initial reste à réaliser par une voie Auth Admin officielle ; aucune API de création d'utilisateurs disponible dans le connecteur. Ne pas créer de compte en modifiant directement auth.users, ne pas exposer de secret ou publier de route bootstrap. Le domaine NS_AUTH_ALIAS_DOMAIN reste à confirmer avant qualification du provisionnement délégué. Auth positive Web, recette intégrée, audit exhaustif des 22 fonctions, SIM/FCM et APK Release restent ouverts. Aucune modification de schéma, de secret, de main, du projet NAXA Pharmacie ou de déploiement volontaire.


### 22.28 — Passe parallèle : périmètres, dérive SQL, CI et prévol intégration (26 novembre 2026)

Correction effective sur le seul backend FAMILLE-NAXA idupfjbkwjcavyisxteo : migration 20261126080317 naxa_services_strict_site_management_scope. ns_can_manage_site exige désormais le type site explicite (ou organisation) et l'appartenance du site à l'organisation ; prévol de la correction en transaction rollback PASS, migration appliquée, définition et droits vérifiés (anon=false, authenticated=true). Recette après migration 5/5 PASS : périmètre poste non élargi, exploitation du poste conservée, autorisation site légitime, autorisation organisation légitime et refus d'un site tiers. Fixtures annulées, 0 utilisateurs Auth, organisations, sites et postes après test. Archive SQL exacte sous docs/naxa-services/hosted-migrations/20261126080317_naxa_services_strict_site_management_scope.sql, commit dd75b96 ; test supabase/tests/drafts/naxa_services_strict_site_management_scope.sql, b351b06. Rejeu des 22 gardes de session non liée PASS.

Réconciliation source : draft v8 mis à jour a12ec61 (périmètre site strict) ; draft v5 44222ce (extensions.gen_random_bytes au lieu de public, conforme au pgcrypto hébergé et au bootstrap CI) ; workflow 9358679 exécute les deux nouvelles recettes SQL. Les drafts conservent rollback par défaut. Le résultat du nouveau gate complet n'est pas encore disponible par le contrôle de statut combiné (aucun statut remonté), ne pas déclarer le nouveau SHA intégralement vert. La CI précédente #624 ne couvre pas ces modifications. Onze migrations sont présentes dans l'historique hébergé ; l'archive des dix migrations antérieures reste à constituer intégralement avant un pipeline global.

Prévol Web/API simultané : https://famille-naxa.pages.dev/ répond et affiche l'écran de connexion ; les quatre Edge accounting, referrals, customer-promotions et notifications répondent HTTP 405 à GET (attendu, POST/OPTIONS requis). Cela ne valide ni CORS de chacune ni leurs appels authentifiés. Sept RPC comptabilité historiques appelées par des branches directes du gateway sont réservées service_role par conception (v4) ; ne pas rétablir de grant authenticated et ne pas utiliser service_role pour contourner les gardes. Le frontend main.tsx actuel utilise apply_sync_event : vérifier la couverture de l'ensemble des émetteurs Web/Android et le retrait ou rejet clair des branches legacy avant qualification. Advisor actuel : 32 INFO RLS sans policy (tables serveur), 22 WARN SECURITY DEFINER authentifié ; pas d'effacement artificiel des warnings. Les tests négatifs ne couvrent pas encore chaque combinaison de droits. Storage : 0 bucket ; Realtime : 0 table ns_* publiée. N'activer que les buckets privés et publications nécessaires après audit des contrats et policies.

Blocages regroupés : Auth Admin officiel (pas d'API Admin dans le connecteur ; dashboard à autoriser pour création d'un compte synthétique, sans mot de passe dans la conversation), domaine d'alias Auth, secrets FCM/webhooks et worker, destinations opérateurs et SIM bénéficiaire, recette réelle Web/Android, signature Release (quatre secrets keystore/mots de passe/alias, configuration dédiée Supabase/Firebase), règles offline/parrainage/prorata, sauvegarde restaurable hébergée (workflow de restauration isolée présent mais pas une preuve de sauvegarde réelle). Le portail Cloudflare reste accessible ; aucun déploiement volontaire, aucune modification main/Pharmacie, aucun frais, aucun paiement réel. Les commits de la branche peuvent déclencher la CI et éventuellement le build automatique Pages si l'intégration reste activée ; ne pas les confondre avec une autorisation commerciale.


### 22.29 — Firebase : réutilisation du modèle NAXA Pharmacie et séparation stricte (26 novembre 2026)

Orientation propriétaire : s'inspirer du Firebase réellement utilisé par NAXA Pharmacie. Audit en lecture seule du dépôt NAXA main : android/app/google-services.json indique projet naxatechnologie, package cm.naxa.app ; NaxaFirebaseMessagingService.kt reçoit les notifications et renouvelle les jetons ; src/lib/firebase/fcm.ts utilise compte de service serveur, JWT RS256, OAuth 2.0, FCM HTTP v1, contrôle du projet, envoi aux jetons du destinataire et traitement des jetons invalides. Aucune clé privée lue ou transférée, aucune modification pharmacie. NAXA SERVICES a déjà son propre package cm.naxa.naxaservices, Firebase Messaging SDK, paramètres BuildConfig NS_FIREBASE_API_KEY/APP_ID/PROJECT_ID/SENDER_ID et Edge notifications avec stockage des jetons chiffrés. Conserver cette architecture native et le backend Supabase FAMILLE-NAXA.

Code branché : dacff5d (validateFcmServiceAccount), 5883965 (utilisation dans la gateway notifications), 0edfd7e (test de contrat). Le worker exige désormais NS_FIREBASE_PROJECT_ID dédié, refuse explicitement naxatechnologie, vérifie la concordance project_id et client_email du compte de service, présence PEM et adresse OAuth Google fixe https://oauth2.googleapis.com/token. Les tests de contrat couvrent configuration valide synthétique, absence de projet, projet pharmacie, mismatch, endpoint non autorisé, compte de service hors projet et clé absente. Nouveau résultat CI non encore constaté ; code source seulement, Edge hébergée non redéployée dans cette passe.

Configuration cible : nouveau projet Firebase isolé sur offre gratuite si disponible, nom proposé NAXA SERVICES (ID définitif attribué par Firebase, ne pas supposer sa disponibilité), application Android cm.naxa.naxaservices. Activer FCM HTTP v1, service account dédié avec droits d'envoi minimaux, sans réutiliser le compte de service pharmacie. Lire les valeurs publiques de la configuration Android : project_info.project_id -> NAXA_SERVICES_FIREBASE_PROJECT_ID (GitHub vars) et NS_FIREBASE_PROJECT_ID (secret/config Edge), project_info.project_number -> NAXA_SERVICES_FIREBASE_SENDER_ID, client_info.mobilesdk_app_id -> NAXA_SERVICES_FIREBASE_APP_ID et api_key.current_key du client au package exact -> NAXA_SERVICES_FIREBASE_API_KEY. Secrets Edge séparés : FCM_SERVICE_ACCOUNT_JSON, NS_PUSH_TOKEN_ENCRYPTION_KEY et NS_NOTIFICATION_WORKER_SECRET ; ne pas commiter ces valeurs, ne pas les communiquer dans le chat. FCM Web éventuel : app Web dédiée, VAPID, service worker et recette distincte, non couvert par le test Android. Le connecteur officiel Firebase pour Codex a été identifié et proposé mais son installation/autorisation n'est pas confirmée ; aucun accès console Firebase ni création de projet vérifiés. Reste à configurer le projet et les secrets, vérifier la CI, déployer la version Edge autorisée puis tester inscription du jeton, renouvellement, réception premier/arrière-plan, ouverture d'une route et révocation après logout sur appareil réel. Pas de frais engagés, pas de main ou de modification NAXA Pharmacie.


### 22.30 — Firebase sans connecteur, validation de configuration Android (26 novembre 2026)

Décision : poursuivre sans connecteur Firebase. Création/inscription du projet dédié via console Firebase officielle, plan Spark, sans liaison Cloud Billing. FCM HTTP v1 reste la cible. Projet NAXA SERVICES (ID attribué réellement par Firebase), package cm.naxa.naxaservices. Pas de partage du projet pharmacie naxatechnologie, ni de secret.

Validateur public scripts/naxa-services/firebase-android-config.mjs, commit 149182d, contrôle package unique, ID projet dédié, numéro projet, app ID cohérent et clé publique Android. Six cas synthétiques testés directement (1 valide et 5 refus) : PASS. Test Node versionné 4c6cb39 ; garde de release 7202b4a et test d3d8808 refusant le projet Firebase pharmacie ; workflow d03852e inclut les tests du validateur. Résultat du gate complet non confirmé. Configuration Android publique à récupérer du vrai google-services.json (pas du JSON privé du compte de service). Le validateur ne crée pas de projet ni n'enregistre de variables ; le connecteur GitHub actuel ne fournit pas d'actions d'écriture des variables ou secrets Actions. Le secret Edge FCM_SERVICE_ACCOUNT_JSON doit être renseigné directement dans le dashboard Supabase dédié, jamais dans Git ou dans le chat, en parallèle de NS_FIREBASE_PROJECT_ID, NS_PUSH_TOKEN_ENCRYPTION_KEY et NS_NOTIFICATION_WORKER_SECRET. Les quatre variables GitHub Firebase sont documentées en 22.29. Aucune modification de configuration distante Firebase/Supabase, aucune activation de facturation, aucun redéploiement Edge volontaire. La recette physique et la signature Release restent ouvertes.


### 22.31 — Identité Firebase Android fournie par le propriétaire (26 novembre 2026)

Configuration google-services.json fournie par le propriétaire : project_id naxa-services, project_number 203144467053, package cm.naxa.naxaservices, mobilesdk_app_id 1:203144467053:android:35b6db66aa6a85bce1e564, clé API cliente présente et syntaxiquement cohérente. Le projet réellement fourni est indépendant de naxatechnologie, donc conservation des gardes de séparation ; ne pas supposer qu'un projet commun a été configuré. Vérification statique des identifiants uniquement, pas d'accès console ni d'envoi FCM vérifié. Le workflow release a été mis à jour et relu (commit 60250a3ec1fe8010c6426747e7464f240ab71765) avec les trois identifiants publics du projet, de l'application et du sender fixés ; la clé API cliente n'a pas été recopiée dans le dépôt et reste injectée via NAXA_SERVICES_FIREBASE_API_KEY dans GitHub Actions Variables. Le workflow release n'a pas été lancé. Prochaines configurations console : FCM HTTP v1 activé, compte de service dédié autorisé à envoyer les notifications, clé JSON privée renseignée directement dans le secret Supabase FCM_SERVICE_ACCOUNT_JSON (jamais GitHub public ou chat), NS_FIREBASE_PROJECT_ID=naxa-services, NS_PUSH_TOKEN_ENCRYPTION_KEY et NS_NOTIFICATION_WORKER_SECRET à configurer en sécurité si absents. Recette effective Android et redéploiement contrôlé Edge toujours ouverts. Aucun changement de NAXA Pharmacie, main ou facturation.


### 22.32 — Reprise après configuration Firebase et déploiement contrôlé (26 novembre 2026)

Propriétaire indique avoir remplacé la clé privée Firebase précédemment exposée et configuré Supabase. Ne jamais utiliser ni reproduire la clé exposée. Révocation et valeurs des secrets non vérifiables avec les capacités actuelles ; déclaration du propriétaire, pas preuve de fonctionnement FCM. Variable GitHub NAXA_SERVICES_FIREBASE_API_KEY également non vérifiable via le connecteur Actions actuel.

Gate technique #639 run 45817223378, SHA 60250a3ec1fe8010c6426747e7464f240ab71765 : 12/12 jobs success, vérifiés individuellement (Android Debug, Web, notifications FCM contract, SQL security/RLS runtime, auth, referrals, promotions, sync, tariffs, payments, suppliers). https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45817223378 . Ce gate ne prouve pas la compilation Release avec secrets réels.

Autorisation de correction donnée dans cette passe : déploiement limité à naxa-services-notifications sur FAMILLE-NAXA ref idupfjbkwjcavyisxteo. Version 4 -> 5 ACTIVE, puis correction du défaut CORS réponse 204 avec corps JSON (commit ae2156c0e8c606d99fffae5826ff262e5bc0d0eb), test local Node Response(null,{status:204}) PASS, déploiement v6 ACTIVE sha bundle 9c1cf77bfea55068b7af0ceb547fbd46aa4ef4123bfb96f70c687c2437998a30. Lecture du code hébergé v6 confirme garde projet Firebase, validateur et correction 204. GET endpoint avant v6 retourne 405 attendu ; pas de preuve HTTP OPTIONS réelle v6 ni d'OAuth/FCM réelle. CI du dernier correctif non confirmée.

Contrôle SQL hébergé : 76 tables ns_, 0 sans RLS, 0 accessible à anon selon droits SELECT/INSERT/UPDATE/DELETE ; 0 comptes ns_accounts, 0 jetons ns_push_tokens, 0 bucket ns-. Web Cloudflare accessible, page de connexion présente. Aucun compte de test réel ni appareil enregistré ; recette positive et envoi push ne peuvent être déclarés verts. Les sept branches legacy comptables identifiées en 22.28 restent dans le code ; audit de tous les appelants incomplet (récupération arbre Git impossible dans cette passe), ne pas élargir leurs droits. Reste : vérifier secrets worker et chiffrement, authentification OAuth du compte de service, droits FCM, authentification utilisateur réelle, enregistrement/réception/révocation de jeton, planification dispatch, provisionnement initial sécurisé, configuration paiements abonnement, stockage/realtime selon besoin, APK signé, recette physique et sauvegarde/restauration hébergée. Aucun changement main, pharmacie ni autres fonctions (ZIPPLE compris), aucun frais engagé. Statut : gate technique vert sur #639, qualification production ouverte.


### 22.33 — Qualification opérationnelle groupée et diagnostic des vrais secrets (26 novembre 2026)

Contrôle serveur temporaire à accès par nonce non publié dans le dépôt, réponse booléenne sans valeurs de clés, sans mutation de données : v7 puis retrait v8. Résultat project_matches=true, credentials_valid=false, worker_configured=false, encryption_configured=false, oauth_ok=false (OAuth non atteint). Second diagnostic temporaire v9 pour distinguer absence de valeur et format invalide : credential_status=FCM_CREDENTIALS_NOT_CONFIGURED, credential_present=false, worker_present=false, encryption_present=false. Retrait immédiat, version normale v10 ACTIVE, code hébergé vérifié sans nonce de diagnostic, bundle 752caef57796de8e4fc5f0a7f82548ad6aab15eae1fbe0d7015e81678b88b082. Aucun secret imprimé, aucune notification réelle envoyée, aucune manipulation de la clé privée exposée antérieurement. NS_FIREBASE_PROJECT_ID est effectivement visible côté runtime et correspond à naxa-services. Les trois secrets suivants sont absents du runtime observé : FCM_SERVICE_ACCOUNT_JSON (nouveau JSON privé intégral, jamais celui exposé), NS_PUSH_TOKEN_ENCRYPTION_KEY (64 caractères hexadécimaux aléatoires), NS_NOTIFICATION_WORKER_SECRET (secret aléatoire long et indépendant). Configurer dans les Edge Function Secrets du projet FAMILLE-NAXA ; ne jamais les commiter ni les transmettre dans le chat. Le connecteur Supabase ne permet pas de les écrire, et aucune session navigateur Supabase/GitHub enregistrée n'a été confirmée. L'absence ne démontre pas que le propriétaire n'a pas saisi les valeurs : vérifier projet, nom exact et sauvegarde.

Premier promoteur : script opérateur docs/naxa-services/operations/bootstrap-first-promoter.sql commit 4a36c821dd2a8b15ee81a1b8b4a051072731529b. Requiert utilisateur Auth dédié déjà créé et confirmé via API/dashboard officiel, aucun mot de passe dans SQL, vérifie alias et UUID, interdit seconde initialisation et verrouille les tables, crée organisation/site/compte/membre/périmètre/audit dans une transaction. Premier essai de recette a révélé object_id UUID (corrigé avant commit), recette hébergée corrigée 5 assertions PASS sur fixtures synthétiques, rollback confirmé : comptes=0, organisations=0, fixture Auth=0. Aucun compte réel créé. Aucune contournement Auth ; l'inscription positive reste à exécuter avec un utilisateur légitime et un appareil.

Droits comptables : les 7 anciens RPC de stock/fournisseurs restent service_role-only, ns_apply_sync_event autorisé à authenticated et service_role. Pas de réouverture des droits ; audit exhaustif des appelants des routes héritées non achevé. Stockage ns- : 0 bucket ; Realtime : 0 table ns_ publiée ; aucun jeton ni compte NS. Ne pas créer de bucket public ni publication large sans contrat et policies. Run #640 45825922172 : 11 jobs success, Android assembleDebug in_progress au contrôle. #639 reste dernier gate intégralement confirmé 12/12. Release signée non exécutée, variable GitHub et secrets de signature non vérifiables. Aucun main/pharmacie/ZIPPLE touché, aucun coût. Qualification réelle demeure bloquée par configuration secrète, compte Auth, téléphone, paiements réels et recette de restauration hébergée.


### Contrôle complémentaire 22.33 — variable ajoutée

Run #640 (45825922172) : 12/12 jobs success, compilation Android comprise. Contrôle runtime post-ajout : project_matches=true, worker_configured=true, credential_present=false, credential_valid=false, encryption_configured=false, oauth_ok=false. Worker désormais conforme au contrôle de longueur (>=32), sans validation de dispatch authentifié. FCM_SERVICE_ACCOUNT_JSON absent du runtime ; NS_PUSH_TOKEN_ENCRYPTION_KEY absent ou format non conforme. OAuth et push réel restent non validés. Sonde temporaire v13 retirée, code normal v14 ACTIVE, garde FCM présente et nonce absent, bundle 976c7f98fd9a007d1b5e8d93bbac02153eba6861531c32c2854fee8139a4cdcc. Aucun secret retourné, aucune notification envoyée, aucun changement main/pharmacie/ZIPPLE.


### Contrôle complémentaire 22.33 — nouvelle relance

Contrôle runtime : project_matches=true, worker_configured=true, encryption_present=true, encryption_configured=true (64 caractères hexadécimaux), credential_present=false, credential_valid=false, oauth_ok=false. Trois des quatre paramètres Firebase/worker validés en présence/format ; FCM_SERVICE_ACCOUNT_JSON toujours absent du runtime et OAuth non validé. Sonde v17 retirée, version normale v18 ACTIVE, garde FCM conservée et nonce absent, bundle 9fd1f448bc394804871aef04115c3d8473c59458da51c67d107d3b342554352c. Aucun secret affiché, aucun envoi push réel. CI #640 déjà vérifiée 12/12 ; qualification production toujours ouverte.


### Contrôle complémentaire 22.33 — nouvelle confirmation de saisie

Après confirmation propriétaire, contrôle runtime : project_matches=true, worker_configured=true, encryption_configured=true, credential_present=false, credential_valid=false, oauth_ok=false. Le dernier secret FCM_SERVICE_ACCOUNT_JSON demeure non visible dans le runtime ; ceci ne prouve pas l'absence dans le tableau de bord. Vérifier la liste des noms uniquement, le projet et l'enregistrement effectif, plutôt que répéter les sondes. Sonde v20 retirée, code normal v21 ACTIVE, garde FCM conservée et nonce absent, bundle c5d34d4fc894f0111c4bdf4cc823d6a672ae51cda440ba7af74b1f357e6dc4a3. Aucun secret affiché, aucun envoi push réel.


### Contrôle complémentaire 22.33 — validation finale des secrets et OAuth Firebase

Après confirmation du propriétaire, contrôle réel dans le runtime de la fonction notifications : project_matches=true, credential_present=true, credential_valid=true, worker_configured=true, encryption_configured=true, oauth_ok=true. Les quatre paramètres Firebase/worker sont désormais présents et conformes au contrôle de configuration. Échange JWT contre jeton OAuth Google réussi via le compte de service dédié naxa-services. Sonde temporaire v24 retirée, version normale v25 ACTIVE, garde FCM conservée et nonce absent, bundle e1a0a6c0dc629b5a113523e834cc455beec66453df0c95931770b690c7786f00. Aucun secret ou jeton OAuth affiché. Aucun message FCM envoyé à un appareil : droits d'envoi FCM, enregistrement du jeton appareil, réception et révocation restent à qualifier en recette réelle. Gate #640 déjà confirmé 12/12. Aucun changement main/pharmacie/ZIPPLE, aucun frais supplémentaire engagé par cette intervention.


### 22.34 — Qualification FCM HTTP v1 et séparation des canaux (26 novembre 2026)

Recette distante FCM : OAuth Google réussi, appel POST messages:send du projet naxa-services avec validate_only=true, sujet QA et payload synthétique. HTTP 200, preuve de l'autorisation d'envoi du compte de service et de la validation FCM sans livraison réelle. Chiffrement AES-GCM et déchiffrement aller-retour d'un jeton synthétique réussis avec la configuration serveur réelle, sans persistance ni affichage du jeton. Sonde temporaire v26 retirée, fonction normale v27 ACTIVE, nonce absent, garde projet conservée, bundle bdf70834a0fb9481f4bf17086cabb3907178f0e1de541375885e8159609807d4. Champ database_claim_rpc de la sonde non testé (valeur initiale false), ne pas interpréter comme échec SQL ; testé séparément ci-dessous.

Défaut confirmé : ns_claim_notification_batch récupérait indifféremment push/SMS/WhatsApp/email/in_app alors que le worker FCM ne traite que les notifications push membres. Prédicat corrigé : channel='push' et recipient_member_id non nul, conditions de disponibilité et de reprise conservées. Test transactionnel avant migration puis après migration PASS : un seul canal push revendiqué, autres canaux intacts, claim périmé/incorrect refusé, retry pending, nouvelle claim/attempt, création inbox unique, finalisation dupliquée refusée. Migration hébergée appliquée 20261126133458 naxa_services_push_only_notification_claim. Source draft réconciliée commit d077f09f75ca174ca356f68a95ec577b7e72a375 ; test supabase/tests/drafts/naxa_services_push_only_notifications.sql commit ff8c27b55ec2c4dc8e7b1c477aeb24ecb239b875 ; intégration CI e7d8a107b2de14252ac7514611f16cae4f87ca12 ; archive SQL exact fb017c3f6e026080e928f451b42641192f7f2a69. Vérification après rollback : zéro org/compte Auth/notifications QA persistés ; anon et authenticated ne peuvent exécuter le claim, service_role seul autorisé. 0 ns_accounts, 0 ns_push_tokens à l'instant du contrôle.

Ne pas confondre validation d'envoi HTTP v1 et livraison Android réelle. Restent : planificateur worker sécurisé, gestion des autres canaux, audit révocation/session et distribution multi-appareils, compte Auth réel et enregistrement jeton Android, recette réelle, signature release, configuration abonnement, autres points opérationnels déjà répertoriés. Nouveau gate déclenchable par les commits mais résultat non encore confirmé, dernier gate intégralement vérifié #640 12/12. Aucun changement main/pharmacie/ZIPPLE, aucune notification réelle, aucun coût supplémentaire engagé.


### 22.35 — Qualification des appareils et automatisation sécurisée des notifications (26 novembre 2026)

**Appareils et jetons** : une inscription push était auparavant attachée au couple org/fingerprint, sans preuve SQL de session Auth active lors de la livraison. Correction hébergée 20261126133841 naxa_services_bound_push_tokens : index unique global fingerprint, inscription atomique RPC service-only ns_register_bound_push_token (organisation/membre/compte/appareil/plateforme/session Auth cohérents et actifs), rotation révoque les anciens jetons du même appareil, transfert de token retire l'ancien rattachement, ns_live_push_tokens filtre révocation et expiration réelle Auth. Test transactionnel avant/après migration PASS : transfert, isolation inter-établissements, rotation, révocation, expiration, rejet d'inscription sur session expirée. Fixtures rollback confirmé (0 comptes, 0 tokens, 0 users QA), anon/authenticated sans EXECUTE sur les deux RPC, service_role seul. Source draft ca5474b160952659bce67a0810f1fe9ab8520ed6 ; test f494883a1bce474ab18e8e6cef1814ce3303782c ; Edge 91974425c90eb92bdf8f3a7ae9862c8b4a9841ce v28 ; bootstrap CI auth.sessions e2340e2bf7059fbf372bc4154cb333de638b815c et gate 3adb3ea4f651979f5398df4b69e63ceb06e30979 ; archive d1a85908772e608a87826a276d48098102ec123e.

**Planification** : cron et pg_net installés initialement, ticket à usage unique testé (migration 20261126134022, archive 510eb67b9ed7ad16846ce706285b8a3f9e67ca8d), Edge v29 commit 37e746a15a21c624baf091a24bf8986be47a45dc, appel forcé HTTP 200 (0 claimed/sent/retried/failed), ticket consommé. Cron job id 1 naxa-services-push-dispatch toutes les 5 min (migration 20261126134103, archive f0623a435218161a56855ca055875a3cd54d6274). Contrôle contradictoire : pg_net accorde aux rôles clients un accès à sa file par défaut ; tentative REVOKE 20261126134152 non effective (contrainte Supabase documentée), cron désactivé le temps de corriger. Aucun secret durable n'a été mis en file ; ancien ticket consommé. Transport remplacé par extension http synchrone, signature HMAC courte durée (clé créée directement dans Vault, non retournée, 90 sec max + tolérance future 10 sec), nonce aléatoire, hash du ticket consommé enregistré dans ns_private, rejet replay/forgery/expiration testé PASS. Migration 20261126134253 naxa_services_sync_signed_scheduler_transport archive 4411a65ccdfb1df7b02e0336a537127cf02a683d ; Edge signature regex commit 7421b6f5d123ba08603869f3e37da5d5e58b5296, v30 ACTIVE, bundle 4f12057b2ee70636fe4ca1559fe1e2a09eb47e203fcd94969f1969f5fa19a7d6. Appel forcé via nouveau transport HTTP 200. Cron réactivé et vérifié actif ; file net vide, aucun appel réseau automatique si file métier vide, maximum 10 notifications par appel, aucun client réel. À l'instant du contrôle aucun cycle cron réussi enregistré encore : ne pas confondre appel forcé réussi et cadence observée. Extension pg_net reste installée mais n'est plus utilisée par NAXA SERVICES ; ne pas l'utiliser pour des secrets. Vault et ns_private inaccessibles aux rôles clients selon vérification ACL. Scheduler HMAC ne requiert aucune nouvelle saisie manuelle de secret.

**CI** : #643 (45830595612) 11 jobs success, Android annulé par nouveaux commits ; dernière CI complète confirmée #640 (12/12). #650 (45831881109) SHA 7421b6f5d123ba08603869f3e37da5d5e58b5296 en cours au dernier contrôle, ne pas annoncer vert complet avant vérification. Restent : recette réelle avec premier compte Auth et token physique (0 ns_accounts et 0 tokens actuellement), distribution multi-appareils fiable (actuellement arrêt au premier token accepté, pas de reçus par appareil), audit des anciennes branches comptables, abonnements réels, stockage, signature Release et sauvegarde/restauration réelle. Aucun main/pharmacie/ZIPPLE modifié ; extensions nouvelles au niveau projet partagé, job dédié NAXA SERVICES. Aucun frais payant engagé explicitement ; cron/HTTP consomment les ressources du plan existant. 


### 22.36 — Qualification groupée : CI, distribution multi-appareils, Auth, comptabilité, stockage, Release (26 novembre 2026)

**CI / cron** : run #650 45831881109 12/12 success, y compris Android, confirmé. Cron signé : 5 cycles réussis, 0 échec au dernier contrôle. Le worker skippe les files vides. 

**Multi-appareils** : défaut ancien arrêt au premier token accepté. Migration hébergée 20261126140054 naxa_services_notification_device_deliveries : table RLS server-only ns_notification_device_deliveries et RPC ns_pending_push_targets, ns_record_push_device_outcome, ns_push_delivery_summary ; lease et destinataire contrôlés, reçu terminal par notification/token, reprise exclut les appareils déjà acceptés/rejetés, inbox unique. Recette SQL avant/après migration PASS (deux appareils, claim incorrect refusé, premier succès conservé, retry second appareil, rejet définitif, summary et inbox). Aucune fixture persistante, table privée anon/authenticated sans lecture. Draft 1a2f6f922c38b9d32d01d8fa440b96530cd700bf ; test 5e563c4c431999a2591a35be53191eda6d08a799 ; Edge 9e1cbcc13d356e232c71ea5f92e835ac814ea4de v31 ACTIVE, transport planifié forcé HTTP 200 sur file vide ; classification static 5c923617d0139a0818296f9644690e16e05c27b3, CI c0781b062583410db716bd03830fd8c31cdfd14e, archive d0182485d224d1735bdb831a2c842b6b74db4fca. Distribution réelle sur plusieurs appareils non testée ; traitement au moins une fois, une panne entre acceptation FCM et persistance du reçu peut entraîner un doublon (ne pas promettre exactly-once). Aucun token réel enregistré.

**Auth / premier promoteur** : correction de l'audit object_id UUID pour logout (id réel appareil), révocation (id réel appareil plutôt qu'account), acceptation légale (lecture id du reçu après upsert au lieu de chaîne type:version), commit daaaba93f254b9adcbabd38ba215e41abf7c23d8. Edge Auth v12 puis sondes temporaires v13/v15/v17/v19 retirées, code normal v20 ACTIVE bundle 4bb302faae10359321d2d3359c43ce930f5f2235256ff40cd4aa9e5ca4914cc8. Deux tentatives de recette Auth positive se sont arrêtées à préflight sans création d'utilisateur (deuxième retour QA_COLLISION alors que contrôle SQL des fixtures confirme zéro compte/organisation/auth QA ; cause exacte non résolue). Diagnostic séparé : lectures REST ns_organizations et ns_accounts HTTP 200, Auth Admin list HTTP 200 ; aucune valeur/identité/tokens retournés. Ne pas contourner le contrôle de préflight. Script de bootstrap testé antérieurement ; provisionnement et acceptation/déconnexion réelles restent ouverts. 

**Comptabilité** : Web main.tsx et Android SupplierSyncCoordinator.kt utilisent apply_sync_event. Sept anciennes routes directes appelaient les RPC service-role-only avec JWT utilisateur ; désormais HTTP 409 ATOMIC_SYNC_REQUIRED / required_action apply_sync_event, sans accorder de nouveau droit. Commit c04f6410aa7f49bc1e374fccd038c98711319c20, Edge accounting v12 ACTIVE, source distante vérifiée. Audit exhaustif des autres appelants Android non terminé (limite d'appels de l'outil), aucune recette HTTP authentifiée ni paiement réel effectués. Tests contrats comptables et SQL du run #658 réussis.

**Storage** : décision de commencer par les photos de profil (pas de stockage public générique). Bucket ns-profile-photos créé via Storage API privée, limite 2 Mio par fichier, MIME JPEG/PNG/WebP ; chemin <org UUID>/<member UUID>/avatar.jpg|png|webp. Migration 20261126140440 naxa_services_private_profile_photo_access, six policies (4 opérations et 2 gardes restrictives), session Auth active, appareil non révoqué, accès propre membre et org. Recette SQL avant/après migration PASS (propriétaire, mauvais org/membre, format interdit, appareil révoqué). Archive 15f457edcf16c2f1e6e63afd3ff7853b680356dc, test hébergé 895cc5908dc8efc2acf0588239a06dbb7d347b05. Sonde Storage API : bucket privé, upload PNG synthétique HTTP 200, lecture serveur taille correcte, accès public rejeté HTTP 400, suppression OK ; contrôle final 0 objets, bucket privé et six policies. Client Android/Web non encore raccordé aux photos ni upload utilisateur JWT testé ; stockage des autres pièces métier reste à cadrer. Aucune donnée réelle.

**Release Android** : workflow fixe le ref public vérifié idupfjbkwjcavyisxteo (9f525e56729f95fdf458ab160c1074f3f1e1791a) ; workflow de readiness distinct ab791b977e4f20094725163b2970fd22946625bd, run 45835222161 job 139962187963 : Firebase API key PRESENT, cinq paramètres MISSING confirmés sans impression de valeurs : NAXA_SERVICES_SUPABASE_ANON_KEY (env NS_ANON_KEY), NAXA_SERVICES_RELEASE_KEYSTORE_BASE64, NAXA_SERVICES_RELEASE_STORE_PASSWORD, NAXA_SERVICES_RELEASE_KEY_ALIAS, NAXA_SERVICES_RELEASE_KEY_PASSWORD. Aucune signature réelle générée ; conserver keystore et mots de passe en lieu sûr, ne jamais utiliser debug pour distribution. Run technique #658 45835218039 : 11/12 success, Android failure Maven Central HTTP 429 sur plugin KSP 2.0.20-1.0.25 (pas de défaut de compilation démontré), rerun_failed_workflow_run_jobs accepté, résultat à vérifier. Ne pas modifier versions Gradle sans preuve de nécessité.

**Reste opérationnel** : vrai premier compte Auth, recettes utilisateur et appareil physique, UI stockage, autres documents privés, destination et téléphone bénéficiaire OM/MoMo, signature Release, sauvegarde/restauration réelle. Aucun paiement réel, aucun frais payant souscrit, aucun changement main/pharmacie/ZIPPLE. Les corrections de cette passe sont réelles mais ne constituent pas une qualification production complète.


### 22.37 — Qualification Release et restauration chiffrée avec contrôle des ACL (26 novembre 2026)

**CI** : #658 45835218039, après relance Android, 12/12 success vérifiés. Readiness 45835222161 job 140013595435 success, six paramètres présents (anon, Firebase, quatre secrets de signature), configuration publique validée ; aucune valeur de secret reproduite. Workflow Release renforcé commit 5845ad7f4f2ae9c364db69dd09166685e5a48546 : déclenchement sur modification du workflow dans la branche de travail uniquement (en plus des déclencheurs manuels/tags déjà présents), extraction certificat keystore, comparaison exacte SHA-256 avec certificat de l'APK via apksigner, nettoyage des fichiers temporaires même en cas d'échec. Run 45852244952 job 140021325480 : étapes configuration, décodage base64, extraction certificat et SDK 35 réussies ; assembleRelease en cours au dernier contrôle ; signature finale et artefact non encore prouvés. La clé de recette et ses mots de passe ayant été communiqués en clair précédemment, ne pas distribuer publiquement d'APK signé avec cette clé ; prévoir rotation confidentielle sous contrôle du propriétaire avant première diffusion. Aucune publication ni modification main.

**Sauvegarde/restore** : défaut constaté, --no-acl supprimait les autorisations sauvegardées/restaurées ; corrigé dans backup-postgres.sh (5b25c3fa20d9f92427f6106b566d891bd38a64b8) et restore-postgres.sh (37c66c34b9a768510578aa54247871f3feab1583), restauration transactionnelle (--single-transaction), SHA256 portable basé sur nom relatif (1d6a03d22a4d792b0ef9478490343840afc58daa). Recette étendue (95c78c13d958663c24ddf205882b4e08a2539d7b) : bases jetables naxa_backup_source/target, bootstrap Auth CI, neuf drafts ROLLBACK-by-default appliqués en copie, GPG AES256, restore, comparaison RLS/grants SELECT et EXECUTE pour tables/fonctions ns_, régression RLS/paiements/scope/unbound/push/tokens/multi-device après restauration. Run #6 45852524957 job 140022310440 success, journal final « NAXA SERVICES schema, restored permissions and runtime regression drill passed. ». Ne pas confondre cette recette locale avec backup hébergé externalisé : le plan Free n'inclut pas les backups quotidiens gérés, objets Storage non inclus dans dump PostgreSQL, propriétaires de fonctions et rôles à qualifier sur une cible isolée avant tout restore réel ; ne jamais restaurer sur le projet partagé en production. Aucun restore hébergé exécuté.

**Contrôle hébergé lecture seule** : 77 tables ns_ et 0 sans RLS, 25 cycles cron réussis / 0 échoué, bucket photo privé présent, 0 comptes et 0 jetons push. Les parcours réels Auth, upload utilisateur, appareil, abonnement et sauvegarde distante ne sont donc pas validés ; les tests synthétiques ne les remplacent pas. UI de stockage reste non raccordée selon dernière qualification. CI #663 45852525003 en cours ; ne pas assimiler à #658. Aucun changement main/pharmacie/ZIPPLE, aucun achat ni paiement réel. 


### 22.38 — APK Release de recette validé et raccordement photo privée Android/Web (26 novembre 2026)

**Qualification précédente clôturée** : CI #663 45852525003 12/12 success. Release run 45852244952 job 140021325480 success à toutes les étapes : configuration dédiée, extraction certificat, assembleRelease BUILD SUCCESSFUL, apksigner v2 true, empreinte certificat SHA-256 concordante 5bf74d33cb29f20540c5424b59698d02b9375f6497f7514dd01eb294f072df61, somme SHA256 de l'APK produite, nettoyage temporaires réussi. Artefact 15133623747 naxa-services-signed-release 10 201 128 octets, expiration 2026-12-10T15:49:11Z. Il est antérieur aux changements photo de cette passe. Ne pas distribuer publiquement : clé de recette précédemment exposée, rotation confidentielle nécessaire avant production.

**Photo privée** : constat Web avatar statique et Android photo locale URI persistée sans partage inter-appareils. Ajouts Web src/auth/profile-photo.tsx e207c9a2efd58359ff3851b40d9db41af8aaf082 et raccordement main.tsx 8a392599ec55edc43b0b7fc15234b06a8d501d5e ; tests navigateur avec Storage simulé 9b6d0ca4e9303bc3b77b34e95cf1a3ec15075f2f (upload, lecture, suppression, changement d'organisation/compte). Android PrivateProfilePhoto.kt 84ad1f7b0544014119fa4bfa70a0bfaedecee8bc, raccordement ManagementModules.kt e67b3d72bd8c34be12b5f03f9ede0c998e52b7f0, tests unitaires 4f97ea9213145b1dcfd874e76f1d1c9057b55134 (chemin, limite). Même chemin canonique org/member/avatar.jpg, Auth bearer utilisateur, API Storage privée, MIME JPEG/PNG/WebP et 2 Mio, dimensions bornées et JPEG 768 px pour avatar, aucun cache navigateur persistant ni URL publique ; opérations confirmées par relecture, suppression sur confirmation explicite ; aucune remontée automatique des anciennes URI locales. Aucun nouvel accès SQL, aucune donnée réelle, aucune publication. CI #669 45855315868 : 10 contrats success, Web E2E en cours au dernier contrôle, Android failure HTTP429 Maven Central résolution marker KSP avant compilation ; relance API refusée temporairement 403 workflow still running, attendre résultat Web avant relance ciblée. Ne pas qualifier photo verte avant test CI ; la recette API hébergée avec JWT utilisateur et appareil réel reste nécessaire. Le build Release précédent est vert sur son SHA, pas sur les nouveaux commits.

**Autres points opérationnels** : restent premier compte Auth confirmé, recette positive hébergée, notification physique, destinataire abonnement OM/MoMo et rapprochement réel, sauvegarde distante et restauration isolée, remplacement clé de recette et sauvegarde propriétaire. Ne pas créer un promoteur permanent arbitraire ou restaurer la base partagée. Aucun main/pharmacie/ZIPPLE modifié, aucun coût payant engagé.

Contrôle complémentaire 22.38 : #669 Web E2E échoue uniquement sur la nouvelle recette photo (13 autres réussies), fixture PNG initiale IDAT CRC incorrect, vérifié indépendamment par zlib. Fixture remplacée par un PNG RGB généré valide 16×16 dans commit 2283eb39e677d286328f11ce5ef20b357c5e343d. Relance du run #669 acceptée mais annulée par nouveau commit ; run #670 45855794285 déclenché, 10/12 jobs success au dernier contrôle, Web et Android en cours. Ne pas annoncer les clients photo validés avant leur résultat. Aucune modification hébergée.


### 22.39 — Passe commerciale, médias, responsive, animation et inventaire UI (26 novembre 2026)

**Médias** : 16 originaux examinés dans images-a-integrer ; 8 JPEG retenus (office, workspace, printing, stationery, wood-stock, furniture, painting, teamwork), copies sans altération des originaux sous assets/naxa-services/media et apps/web/naxa-services/public/media, commit a2c6514d570707b10d68b41d9b63d96f857265e6. Exclusion des visuels filigranés et inadéquats. Droits commerciaux à confirmer avant diffusion. Web BusinessBackdrop/NightTorch, Android BusinessPhotoBackdrop/LoginBusinessBanner : cadence 4 s, fondu 650 ms, flou 1,5 px/dp, contraste, aucune interception des interactions. Android blur selon capacité OS ; Web réduction des animations selon préférence système. PWA cache uniquement médias publics sélectionnés, version shell v3.

**Commercial et responsive** : réécriture des libellés techniques visibles (connexion, accès, synchronisation, opérations, gestion, erreurs), suppression journal global brut et identifiants/révisions techniques des dossiers. Maintien des statuts métier, avertissements financiers et contrôles d'accès. Menu mobile accessible à tous les modules, fermeture Escape/overlay, grilles flexibles, safe areas, formulaires Android défilables et IME. Torche animée à la transition claire→nuit sur Android et Web/PWA, préférence mémorisée ; animation décorative, pas d'accès matériel à la lampe. Correction Android du bloc photo local orphelin dans ManagementModules.kt après échec compilation #670 : d748334aa32f75779a7d88329ae1f2e70ff6f181. #670 Web réussi dont photo privée avec stockage simulé.

**Qualification** : nouveaux tests navigateur rotation images, absence des phrases techniques ciblées, changement thème/torche, reduced motion, navigation mobile 320 px et reflow 390/768/1024/1440, chaîne fournisseur/stock/commande/réception/règlement et récupération accès ; adaptation des anciennes recettes aux libellés commerciaux, nouveaux tests Android défilement, photo et torche. Inventaire statique scripts/naxa-services/audit-commercial-interactions.mjs, 32 sources UI, 482 sites d'interaction (non uniques), 9 lignes candidates à revue de terminologie, 77 marqueurs de tests (non équivalents à des recettes réussies). Artefact vérifié 15139132001, run #705 45862856493, SHA 69ebc9ef3208269e255bf4aea07d475edf2f1651. Dernier contrôle : 10/12 jobs success (contrats Auth, FCM, paiement, parrainage, tarif, fournisseurs, SQL sécurité, sync, promotions, RLS runtime), Web E2E et Android en cours. Aucun statut vert global avant résultats finaux. Les recettes navigateur utilisent des services simulés ; aucune preuve E2E de tous les 482 sites, d'appareil physique, de paiement réel ni de parcours complet Auth hébergé. APK signé antérieur aux changements, clé de recette à remplacer confidentiellement avant production. Pas de déploiement production déclenché manuellement, ni de changement main/pharmacie/ZIPPLE, ni d'achat.


### 22.40 — Reprise ciblée après « Reprise et Supabase » (26 novembre 2026)

**Référentiels relus** : cahier des charges source Markdown `7 famille naxa/01-cahiers-des-charges/04-naxa-services.md` (v1.0 du 31 octobre, sections S1–S11, V1–V6, §12 points ouverts, §14 critères de recette), `docs/architecture-360/NAXA_SERVICES_ARCHITECTURE_MULTI_ENTITES.md`, historique de ce document jusqu'au §22.39, rapport de construction et extraits disponibles de la conversation. Les arbitrages ultérieurs priment sur les anciens paliers, l'identité commune et les anciennes modalités de récupération : identité distincte sans OTP/mail, Access/Premium, 3 000/10 000 FCFA lancement et 5 000/15 000 à maturité le 1er mai 2027, annuel dix mensualités. Les paiements API concernent les abonnements ; encaissements métier saisis/rapprochés hors application, sans faux paiement. Conserver les 13 activités, les trois modes d'exploitation, Android natif et Web/PWA séparés. Ne pas rouvrir N1–N3 et les parcours déjà qualifiés.

**CI précédente** : #705 (45862856493, SHA 69ebc9ef3208269e255bf4aea07d475edf2f1651) 11/12 jobs success, Android vert ; Chromium 16/19, trois échecs : fiche distante ciblant une option masquée, statut CRM attendu completed au lieu de Terminé, getByLabel exact Article non résolu dans le formulaire stock. Les autres scénarios, dont photos, rotation 4 s, responsive 320 px, reduced motion, accès, 13 parcours métier et photo privée simulée, ont réussi selon le journal du job 140058138742.

**Corrections ciblées** : commit eea8411a15ccbc620df9f1b5deef314b6a3b23b1, noms accessibles explicites des cinq sélecteurs stock/achats ; commit 5f7ced897716dfa49b708aac485c41b484f0533f, ciblage de la vraie fiche visible, statut commercial Terminé, sélecteurs de rôle combobox précis. Aucun retrait de scénario, aucun assouplissement des assertions sur les écritures, reçus, montants, isolation ou ordre des actions. #706 annulé par le nouveau commit. Gate [#707](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45864855921) sur 5f7ced8 : 10/12 jobs success au contrôle documentaire ; NAXA SERVICES Web build: in_progress; Assemble NAXA SERVICES Android debug APK: in_progress. Ne pas déclarer la recette entièrement verte sans résultats terminaux sur ce SHA.

**Contrôle hébergé lecture seule** : FAMILLE-NAXA idupfjbkwjcavyisxteo ACTIVE_HEALTHY, 77 tables publiques ns_ et 0 sans RLS, 41 cycles cron réussis/0 échec, bucket ns-profile-photos privé présent, 0 objets, 0 ns_accounts et 0 ns_push_tokens. Cinq Edge Functions NS ACTIVE (Auth v21, accounting v13, notifications v32, referrals v12, customer-promotions v12). Le statut ACTIVE et RLS activé ne sont pas des recettes utilisateur. Aucun SQL de mutation, déploiement, transaction, création de compte, publication, changement de main ou intervention pharmacie/ZIPPLE dans cette passe.

**Matrice des seules réserves** : (1) terminer gate #707 et analyser tout nouvel échec Chromium/Android ; (2) confirmer Auth hébergée positive avec compte légitime, photo JWT, accès/scopes et récupération, push physique multi-appareils, SIM/SMS et impression ; (3) configurer destinataire OM/MoMo abonnement, rapprochement réel et preuve d'entitlement, sans paiement inventé ; (4) préparer nouveau certificat de production sous contrôle propriétaire (clé de recette antérieure exposée), signer le dernier candidat et qualifier version minimale/signature ; (5) sauvegarde externalisée chiffrée et restauration sur cible isolée, y compris Storage ; (6) vérifier le reste du cahier sans déduire une livraison des tests isolés : Fulfulde réellement rendu, exports PDF/Excel, commission automatique avec barème approuvé, fidélité automatique, briefing et notifications métier, tolérance offline, entitlements, intégrations NAXA SECURITY/livechat et IA selon spécifications ; (7) visas juridiques/comptables/fiscaux/paie, roue désactivée jusqu'à décision, droits commerciaux des médias, OAPI ; (8) couverture exhaustive des interactions et vraie recette terrain. Les points 6–8 sont des réserves de preuve ou d'arbitrage, pas une liste de modules déclarés absents. Voir §22.37–22.39 pour les preuves historiques. Le cahier original n'est pas réécrit. Aucun compte de recette permanent arbitraire, aucune clé dans Git, aucune dépense ou déploiement production autorisé implicitement.

**Statut courant** : corrections commitées ; gate du nouveau SHA à qualifier selon le résultat indiqué ci-dessus ; production non qualifiée. Les anciennes mentions de projet Supabase non créé, Firebase absent ou Release Debug seule dans le début du document sont historiques, et ne décrivent plus le point de reprise.


### 22.41 — Clôture du gate 707, correction commerciale résiduelle et préflight Cloudflare (26 novembre 2026)

**Qualification démontrée** : [gate #707](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45864855921), SHA 5f7ced897716dfa49b708aac485c41b484f0533f, conclusion success, 12/12 jobs. Web 140065030992 : 4 fichiers de tests, 25 tests unitaires réussis, build Vite réussi, Chromium 19/19 (57,8 s), les trois échecs §22.40 résolus. Android 140065031033 : build et tests unitaires réussis, recette instrumentée 13 tests Android 15, BUILD SUCCESSFUL. Artefacts debug APK 15141200476, beneficiary debug APK 15141255376, inventaire commercial 15139742151 ; aucun APK debug n'est une livraison Release. Dix autres jobs (SQL/RLS, Auth, sync, tarifs, finance, fournisseurs, parrainage, promotions, notifications) verts.

**Correction résiduelle** : source main.tsx, libellés techniques encore affichés (scopes, entitlements, liste locale, etc.) corrigés par commit 611e9def15df04c854784274aa1d03f9b10a9d3b ; assertion de non-régression sur le parcours mobile des modules commit f138ea77a8a59e37c2f5e84c9620924b972c1463. Le gate #707 ne couvre pas ces commits. #708 (45866081227, SHA 611e9de) en cours au premier contrôle ; confirmer le gate sur f138ea7 ou descendant avant qualification du nouveau candidat.

**Cible imposée : Cloudflare Pages** pour Web/PWA ; Supabase demeure backend, APK Release séparé après rotation confidentielle de clé. Pas de Netlify ni de modification main. Workflow dédié read-only .github/workflows/naxa-services-cloudflare-preflight.yml, commit 48c09cb0aebe5001d39d53fd05419cf345ac6e9a, [run #1](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45866183128). Jobs au contrôle : production-web-build: success; cloudflare-project-access: failure. Validation clé publique (jamais service_role), build racine workspace @famille/naxa-services-web, sortie apps/web/naxa-services/dist, Auth/Accounting ref idupfjbkwjcavyisxteo, vérification des fichiers PWA et URL intégrée, artefact ; GET projet Pages dédié via vars NAXA_SERVICES_CLOUDFLARE_ACCOUNT_ID, NAXA_SERVICES_CLOUDFLARE_PAGES_PROJECT (nom naxa-services ou naxa-services-...), secret NAXA_SERVICES_CLOUDFLARE_API_TOKEN. Ne pas communiquer les secrets en clair. Le contrôle ne publie rien et n'atteste pas seul du droit d'écriture. Aucun connecteur Cloudflare direct découvert ni projet/domaine confirmé. Références : https://developers.cloudflare.com/api/resources/pages/subresources/projects/methods/get/ et https://developers.cloudflare.com/pages/configuration/build-configuration/.

**Supabase lecture seule** : 77 tables ns_, 0 sans RLS, cron 43 success / 0 failed, 0 comptes et 0 push tokens. Aucune mutation ni paiement.

**Comparatif** : implémentations et preuves techniques pour 13 profils et trois modes, catalogue, agendas, dossiers, stock/achats, caisse, CRM, accès, sync, tarifs, parrainage, contrats notifications. Responsive, médias, nuit, photo privée automatisés, pas de validation physique. Exports PDF/Excel, commissions, fidélité, briefing, IA, Fulfulde, NAXA SECURITY et livechat : conformité exhaustive encore à démontrer, sans présumer l'absence des modules. Réserves §22.40 : Auth positive hébergée, photo JWT, paiement abonnement OM/MoMo et droits, push physique, signature Release récente/confidentielle, backup hébergé et Storage, conformité et droits médias.

**NO-GO commercial** : autorisation conditionnée à toutes les preuves vertes ; nouveau candidat et recette commerciale non intégralement qualifiés. Aucun déploiement effectué, aucun statut Ready inventé. Après clôture, vérifier projet dédié et droits de publication, publier uniquement dist qualifié, contrôler ID de déploiement/stage success, HTTPS, index/JS/manifest/service worker, Auth et scopes avec compte autorisé, possibilité de rollback. Ne pas déployer les autres produits. 

**Résultat terminal préflight Cloudflare #1 (45866183128, SHA 48c09cb)** : production-web-build 140069469559 SUCCESS, artefact 15140262512 naxa-services-cloudflare-candidate (483144 octets) contenant le build Web/PWA avec URL Auth de production et clé publique validée. cloudflare-project-access 140069469965 FAILURE, journal exact « Missing or invalid NAXA SERVICES Cloudflare account ID ». Le contrôle s'est arrêté avant vérification du nom de projet et token ; leur présence/validité n'est pas démontrée. Aucun appel API Cloudflare effectué, aucun déploiement ni URL Ready. Corriger la variable GitHub dédiée dans le dépôt avec le véritable Account ID ; vérifier ensuite le nom de projet dédié et le token via les paramètres privés GitHub, sans les divulguer. Ne pas déployer en contournant la condition de qualification. 

**Rectification Cloudflare — réutilisation de l'intégration existante** : historique retrouvé (projet Pages rapporté naxa-services, GitHub → Pages Free, branche de travail, racine /, build node scripts/naxa-services/cloudflare-pages-build.mjs, sortie apps/web/naxa-services/dist). Script existant vérifié dans GitHub. Lecture distante actuelle réussie via TinyFish : https://famille-naxa.pages.dev affiche NAXA Services et « Accédez à votre espace professionnel. » ; https://0a1111aa.famille-naxa.pages.dev affiche encore l'ancien texte « Pas d'inscription libre, pas d'OTP et pas de boîte mail. » Ce sont des preuves de disponibilité du site existant, pas du SHA courant. Aucun statut GitHub externe renvoyé sur les SHA consultés, aucun accès dashboard Cloudflare disponible. Le blocage du premier préflight concernait seulement la voie API directe et ne justifie pas de demander un nouveau token pour l'intégration Git déjà existante. Correction workflow 8bc151f93e0a00469c2ce2d94c4aa37c6a47c779 : réutilise le guard Pages existant et compare HTML, manifest, SW et assets compilés du candidat avec les fichiers servis par famille-naxa.pages.dev, en lecture seule, sans token. Résultat à qualifier : NAXA SERVICES — Cloudflare Pages preflight (read only) #2 45866459475 in_progress SHA 8bc151f; NAXA SERVICES — Android + Auth contract gate #709 45866325538 in_progress SHA f138ea7; NAXA SERVICES — Cloudflare Pages preflight (read only) #1 45866183128 failure SHA 48c09cb; NAXA SERVICES — Android + Auth contract gate #708 45866081227 cancelled SHA 611e9de. Aucune publication manuelle déclenchée ; les pushes peuvent déclencher l'intégration Cloudflare déjà existante si elle est activée, état exact et deployment ID non confirmés. NO-GO commercial maintenu pour les réserves §22.40. Aucun secret ni paiement réel.


### 22.42 — Levée des échecs Cloudflare et CORS réel (26 novembre 2026)

**Cloudflare** : le contrôle combiné des statuts ne renvoyait pas les checks de l'application Cloudflare. La lecture GET /commits/{sha}/check-runs identifie désormais le check officiel « Cloudflare Pages: famille-naxa » (app id 85455, slug cloudflare-workers-and-pages). SHA f138ea77a8a59e37c2f5e84c9620924b972c1463 : completed/success, titre « Deployed successfully », deployment ID 393a31f1-7846-4c62-8dd4-7ec4090b3889, preview https://393a31f1.famille-naxa.pages.dev ; https://dash.cloudflare.com/?to=/d36bf94078c26b43b0a70df395b601b6/pages/view/famille-naxa/393a31f1-7846-4c62-8dd4-7ec4090b3889. Ce déploiement automatique est attesté ; pas d'action manuelle sur le compte Cloudflare. Ne pas confondre le check ZIPPLE du même monorepo avec NAXA SERVICES. Préflight #2 échec index, exécuté avant fin de publication. Commit bdfc4c2032220b2a5856df0ff92d8f6141fdb60e : attente bornée du check Cloudflare du SHA exact, extraction contrôlée de l'URL immuable, comparaison de tous les fichiers et alias stable, recette OPTIONS de cinq Edge sans mutation. #3 a vérifié le déploiement exact de bdfc4c2 sur https://d443cf28.famille-naxa.pages.dev ; seule différence constatée = index.html distant vide (SHA256 e3b0c442... ; probable redirection /index.html vers / non suivie). Correction 84d7d72e224bac2e9629ffe6dedb6eac929c03af : GET canonique / pour index et suivi HTTPS borné, sans assouplir les comparaisons. [Préflight #4](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45867140706) : build de production et hosted-edge-preflight success ; cloudflare-live-match en cours au contrôle. Le succès du check Pages confirme un déploiement, pas l'acceptation métier complète.

**Défauts réels CORS** : [#3 job initial](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45866858407/job/140071799769) : Auth, referrals, notifications 6/6 OK ; accounting HTTP 200 ACAO=* pour les deux origines ; promotions HTTP 500 sur les deux OPTIONS (Response 204 avec corps JSON interdit). Commit atomique 6b001325b0ae60dc2f73b980398eb07cc4e6d1a8 : promotionHttpResponse corps null pour 204, allowlist exacte ; accountingCorsHeaders et traitement OPTIONS 204, origin autorisée exacte, Cache-Control no-store/Vary Origin, aucune modification des droits métier ni des tokens/RPC. Tests Deno : promotions 6/6 dont nouvelle régression, accounting/sync 41/41 dont nouvelle régression, type-check réussis (gate #710 jobs 140072174671 et 140072174681). Sources hébergées antérieures comparées à Git : match exact de tous les fichiers des deux fonctions avant remplacement. Déploiements correctifs limités à Supabase FAMILLE-NAXA idupfjbkwjcavyisxteo : accounting v14 ACTIVE bundle 7397198e03c55ed138980c5b4161112197d3ae1d863b25f373695770f2bf1b3f ; customer-promotions v13 ACTIVE bundle e7cae63e46d873d47db27abb112eaf2538c9e2f3727493714ce5a2f4605f48f8. Conservation verify_jwt=false et authentification applicative existante, aucune mutation SQL ni autre Edge modifiée. Relance [job réel](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45866858407/job/140072659115) : 10/10 PASS, chacun des cinq services HTTP 204, ACAO origine exacte famille-naxa.pages.dev et null pour origine étrangère. Préflight #4 hosted-edge-preflight également vert. Ces preuves ferment le défaut CORS, pas les parcours positifs utilisateurs.

**CI** : #709 11 jobs success, Android annulé par nouveau commit (ne pas qualifier échec de code). [#710](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45866954256) sur 6b00132 : 11/12 success au dernier contrôle, Web E2E terminé, Android en cours. Dernier complet #707 12/12. Ne pas annuler à nouveau avec des modifications applicatives non nécessaires avant résultat terminal.

**Réserves opérationnelles restantes** : Auth hébergée positive avec identité de recette officielle et photo JWT (aucun compte permanent arbitraire, pas de route bootstrap publique), paiement OM/MoMo réel et activation, réception push appareil physique/SIM, rotation clé release exposée et signature du dernier candidat, backup hébergé restaurable, conformité exhaustive des fonctions et des langues. Examen ciblé Web confirme que PerformancePage charge et affiche les données agrégées, mais n'a pas de commande PDF/Excel ; la langue d'organisation ff-CM est enregistrable, ce qui ne prouve pas une traduction de l'ensemble des écrans. Garder ces deux points ouverts, pas de déclaration de conformité intégrale. Aucun achat, modification main/pharmacie/ZIPPLE, paiement ni utilisateur réel créé. Pas de qualification commerciale GO tant que ces preuves manquent.

**Résultat terminal Cloudflare #4** : [45867140706](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45867140706) 3/3 success. Build de production, CORS hébergé 10/10, cloudflare-live-match 140073028817 SUCCESS. Journal : « Verified Cloudflare deploy for 84d7d72e224bac2e9629ffe6dedb6eac929c03af: https://b4a9deab.famille-naxa.pages.dev », « All files in the exact candidate match the immutable deployment URL. », « Stable Pages alias matches candidate shell. ». Check officiel Cloudflare completed/success, preuve https://dash.cloudflare.com/?to=/d36bf94078c26b43b0a70df395b601b6/pages/view/famille-naxa/b4a9deab-2bd0-43b9-b433-8fa2fc7f4458. Correction canonique index confirmée. Les artefacts de la version en ligne correspondent au candidat ; la qualification de publication Web/PWA est verte. Ne pas déduire la qualification métier ou Android Release du vert Cloudflare. Gate #710 au contrôle : 11/12 success ; Android in_progress. Réserves fonctionnelles et opérationnelles ci-dessus non effacées.


### 22.43 — Réutilisation de la méthode NAXA Replay sans accès aux données pharmacie (26 novembre 2026)

**Clôture technique** : [gate #710](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45866954256), SHA 6b001325b0ae60dc2f73b980398eb07cc4e6d1a8, 12/12 jobs success, y compris Android. Cloudflare #4 3/3 success (§22.42), preuve de publication et concordance des fichiers. Ne pas rouvrir ces gates sans changement pertinent.

**Audit du Replay NAXA** : workflows du dépôt NAXA main .github/workflows/naxa-replay-promoteur-secret-safe-v2.yml, naxa-storage-backup-replay.yml, naxa-support-livechat-e2e.yml relus. Ils utilisent le projet de recette distinct pwfftcsjyeibxxqhwysw, des secrets propres au dépôt NAXA, des fixtures et un navigateur Chromium avec nettoyage. Le projet Replay n'est pas dans la liste des projets du connecteur Supabase ; GET project(id) a explicitement renvoyé « You do not have permission to perform this action ». Ne pas transférer les secrets inter-dépôts, toucher NAXA main ou installer les tables NAXA SERVICES sur le Replay pharmacie sans accès et audit. FAMILLE-NAXA et NAXA production sont exclus des tests de mutation.

**Adaptation exécutée** : workflow .github/workflows/naxa-services-replay-isolated.yml sur branche de travail seulement, commits 44fc2d17287e9d1c9bae4f57c1ad4d752e35c06a et 4062ece18b6de4242dcbaaa844cc44bc284f6c64. Supabase CLI épinglé 2.122.1, stack locale jetable séparée dans RUNNER_TEMP, garde exacte API 127.0.0.1:54321 et DB 127.0.0.1:54322, installation des neuf drafts rollback-by-default dans une copie locale et de cinq archives pertinentes ; aucun secret hébergé. Auth Admin officiel génère deux comptes synthétiques et deux organisations ; Deno exécute le vrai code Auth/Notifications ; JWT réels, connexion négative/positive, refresh, langue membre, accès privé Storage upload/read/upsert, rejet anonyme/inter-tenant, intention abonnement synthétique et annulation, enregistrement/encryption/révocation d'un token push synthétique, déconnexion et refus de l'ancien JWT. Le correctif 4062ece aligne la clé AES-256 en hex 64 caractères et ajoute le garde rollback. Pas de paiement réel, pas de FCM réel ; aucun utilisateur permanent ni données NAXA production. Destruction always de la stack. [Run initial #1](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45868163233) lancé, [run corrigé #2](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45868204788) déclenché. Au contrôle #1 in_progress, #2 en attente de runner. Ne pas annoncer les assertions vertes avant les logs terminaux du #2.

**Limites** : la recette locale réelle n'est pas le projet Replay hébergé historique ni une recette positive de production. Elle ne valide pas le SIM/OM/MoMo réel, le push sur appareil physique, le renouvellement de la clé de signature propriétaire, le stockage externe des backups, la traduction exhaustive ni les exports PDF/Excel manquants. Le dépôt NAXA dispose d'une implémentation exports XLSX/PDF (src/app/api/pharmacie/comptable/exports/route.ts), à adapter au contrat NS et sans réutiliser les données pharmacie. Aucune modification de main ou de NAXA/ZIPPLE. Les commits de la branche peuvent déclencher le build automatique Pages existant ; aucun nouveau déploiement manuel ni homologation commerciale.


### 22.44 — Recettes commerciales et langues FR / EN / Fulfulde (26 novembre 2026)
- Gate #711 [12/12](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45871004570) après 37 corrections de libellés. Replay #2 [SUCCESS](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45868204788/job/140077474164), sept groupes Auth réel, isolation, Storage privé, abonnement synthétique, jetons push et déconnexion. Aucun paiement opérateur ni push réel.
- Commit 1942b59d3d983cab11a09fd7ffd692213793fee6 : 137 entrées de catalogue Web FR/EN/ff-CM, sélection de langue avant/après connexion, préférence membre via set_member_locale, document.lang, ressources Android BCP47 values-b+ff+CM (72 ressources), configuration Locale.forLanguageTag et contexte localisé, tests de bascule. [Gate #712](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45872529189) 12/12, navigateur 20/20, Android instrumenté 14/14. Inventaire : 32 fichiers UI, 483 sites d'interaction, 79 marqueurs de tests, 8 candidats de copie. Ces quantités ne prouvent pas une couverture E2E exhaustive.
- Commit 2c836edb77dba779724f5209ad2a80187854caf7 : Replay #3 [journal](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45872670675/job/140091797053). Les trois préférences membre persistent sur vrais JWT et refresh GoTrue ; échec du navigateur à l'attente du premier dashboard. Aucun PASS de création client réelle. Diagnostic source : parseWebSession exigeait refresh_token >=20 caractères alors que le token est opaque et son format n'est pas contractuel ; hypothèse à confirmer par la recette instrumentée. Ne pas diminuer les protections de scope, JWT et RLS.
- Commit 2dffd5871e5b77239342625a6a62208ada9dc59f : validation token opaque non vide, <=4096 sans espaces, test spécifique ; logs Replay limités au statut HTTP, longueur du token et présence du compte (aucun token affiché) ; 283 entrées Web trilingues avec contexte React et labels statiques des modules agenda, caisse, stock/achats, pointage, suivi client et abonnement. [Gate #713](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45873736792) : 6/12 success au contrôle. [Replay #4](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45873736894) : in_progress. Ne pas qualifier vert avant résultat.
- Réserves langue : FR/EN Android 315 ressources chacun, FF 72/315, donc 243 ressources FF non traduites ; autres chaînes Kotlin et JSX codées en dur, contenus légaux/messages serveur et données métiers restent à auditer. Traductions Fulfulde proposées sans validation linguistique professionnelle locale ; aucune homologation complète. Le contexte React localise les chaînes ajoutées, pas l'intégralité de tous les formulaires/messages. Les tests 20/20 Web et 14/14 Android couvrent le périmètre de bascule et navigation spécifié, non chaque texte.
- Poursuivre sans reprendre les gates acquis : vérifier #713 et #4, corriger sur preuve ; compléter les ressources et chaînes en dur, recettes de chaque écran en 3 langues et matrice interactions/preuves ; maintenir réserves paiement réel, push physique, signature, backup externe et exports, légalité et intégrations externes. Aucune modification de NAXA Pharmacie ni main ; Pages peut déclencher automatiquement des builds de branche. Pas de nouveau déploiement commercial manuel.


### 22.45 — Replay réel : connexion réparée et qualification métier / parité des langues (26 novembre 2026)
- Replay #4 [journal](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45873736894/job/140095440353) confirme HTTP 200, refresh_token réel de 12 caractères, navigation Chromium FR/EN/ff-CM avec préférence conservée après déconnexion/reconnexion. La création client échoue ensuite HTTP 503 : le gateway accounting impose HTTPS alors que la pile locale Supabase fournit HTTP. Ce défaut de montage de recette ne démontre pas une défaillance de production.
- Commit c78bb08de763b04e4ff2a189aec030fd011bc8ea : le gateway comptable isolé pointe vers le proxy HTTPS loopback déjà utilisé par Chromium, avec certificat éphémère explicitement approuvé via deno --cert et routes /auth/v1/user et /rest/v1/ relayées au Supabase local. Aucune relaxation HTTPS de production ni changement du gateway hébergé. [Replay #5](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45874160785) : in_progress au contrôle ; vérifier le code d'erreur de création client et la ligne PostgreSQL effective. Aucune preuve positive de cette écriture à ce stade.
- Commit 6dba5e22612e65e2d91cc57560263a9f652a3daf : 243 ressources FF supplémentaires, parité exacte des 315 clés FR/EN/ff-CM, paramètres de formatage et valeurs vides vérifiés sur les fichiers Git. Traductions provisoires, validation linguistique camerounaise nécessaire ; les chaînes Kotlin/JSX codées en dur ne sont pas couvertes par cette parité.
- Commits f23d3c1278ff75b1b9dd80884aa7b952ac9ccb50 et 323849577e22afa32327873fdec25c635e856baf : contrôle permanent de parité des ressources Android dans l'audit commercial, recette Web de 5 modules × 3 langues (agenda, caisse, stock, équipe, CRM), correction échappement regex vérifiée sur les fichiers. [Gate #716](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45874403549) : 2/12 success au contrôle. Gates #713 (11 jobs verts), #714, #715 annulés par concurrence des nouvelles révisions ; non assimilables à un échec métier ni au vert complet. Ne pas relancer ces anciennes révisions sans raison.
- Les 483 points d'interaction inventoriés restent à rattacher à des preuves de recette, sans présenter les tests de navigation, tests unitaires, contrats ou marqueurs de tests comme des E2E exhaustifs. Priorités : Replay #5 puis recettes métier réelles, validation des écrans complets FR/EN/FF, cohérence responsive et inventaire de textes restants. Aucun changement main, NAXA Pharmacie, secrets ni base hébergée.


### 22.46 — Replay réel vert, extension des traductions et recettes métier (26 novembre 2026)
- Gate #716 : 28/28 unitaires Web, 21/21 Chromium (dont 5 modules × 3 langues), audit parité Android 315/315/315 sans incohérence de format. Annulation du dernier job Android par révision suivante ; ne pas le qualifier 12/12. Gates #717 à #720 également remplacés par concurrence.
- Replay #5 : auth et trois langues réelles passent, écriture client HTTP 400. Commit 951ed2b6860fb561bcb621ad36490bf81ba1098b : CA éphémère distincte du certificat serveur, contrôle de confiance Deno, HTTPS obligatoire en production conservé. Replay #6 [SUCCESS](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45874820456/job/140099119044) : authentification GoTrue et isolation, FR/EN/FF navigateur et préférence après reconnexion, création client HTTP 200 / reçu applied / ligne PostgreSQL persistée, Storage upload/read/upsert et refus tiers/anon, abonnement intention/annulation, enregistrement notifications/chiffrement/révocation et invalidation de session. Aucun transfert réel de fonds ni réception FCM physique. Pile jetable isolée, pas de base hébergée.
- Commit 004cbae38c2124322683045a46a9fd3513ec4851 : catalogue Web 608 libellés, descriptions et fonctionnalités des modules, formulaires, rapports, organisation, sécurité et profil ; correction des compteurs de ventes qui ne sont pas des montants FCFA.
- Commits 5977657c8776b88e1683010a189134d0b4a80880, e45c12f3646bc6023b7b922ef998be2d57775cca, 20488fdec531bb5ddecd93e31a1ee31e3745ddb8, f9a16b914cde56794215697c4a27e1854f863bb3 : 215 branches de texte FR/EN/FF pour découverte, paramètres, parrainage, promotions et notifications ; autres branches pour pressing, agenda, achats, abonnements, dossiers métier et personnel ; localizedLabel au point d'affichage et traitement des appels Text directs en gestion, ERP, stock, CRM, ventes et réseau. Pas de traduction automatique des données utilisateur. Les clés de ressources restent en parité. Les libellés dynamiques par activité, chaînes indirectes, PDF/exports, messages distants, textes légaux et validation linguistique ne sont pas réputés complets.
- [Gate #721](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45875928405) : 11/12 jobs verts au contrôle ; Assemble NAXA SERVICES Android debug APK=in_progress. Web qualifié sur le SHA f9a16b9.
- Contradiction détectée sur le légal : l'interface accepte une préférence ff-CM, mais les actifs juridiques existent uniquement FR/EN et le gateway accept_legal_document refuse ff-CM. Ne pas créer une preuve FF en affichant un document FR. Traduction intégrale des CGU et PC, adaptation des contrats d'acceptation côté serveur et contrôle juridique doivent être traités ensemble avant qualification.

### 22.47 — Extension du Replay E2E des interactions (26 novembre 2026)
- Commit e3311fe6799adaa378cfa5af80d4d6f399c8ea77 : [Replay #7](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45876409704), in_progress au contrôle. Caisse : registre, ouverture, blocage de double ouverture, espèces, Mobile Money externe, clôture, contrôle des lignes persistées. Pointage : arrivée, pause, reprise, départ. Offline : créer client en coupure réseau, vérifier absence côté serveur, reconnexion et exactement une ligne. Photo : téléchargement et suppression Chromium réels. Aucun mock de réponses.
- Commit b7d6b3c295e7738809efb0f47f012c7995ccbfe6 : [Replay #8](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45876496630), en attente au contrôle. Ajoute article, fournisseur, mouvement, commande, deux réceptions partielles, refus du paiement avant réception, règlement bancaire déclaré et contrôle PostgreSQL ; agrège les scénarios indépendants sans masquer les échecs, préserve les vérifications API après les scénarios navigateur. Les tests ne déplacent aucun fonds. Le groupe Replay utilise une concurrence non-annulante pour ne pas perdre une exécution déjà lancée.
- Qualification E2E : ne pas assimiler les 483 sites d'interaction à des recettes passées. Les recettes navigateur avec contrats simulés couvrent déjà 13 activités, pressing, offline, IndexedDB, PWA, caisse, équipe, sécurité, CRM, abonnement, photo, animations, responsive, stock, accès et trois langues ; Replay #6 démontre seulement les parcours effectivement exécutés. #7/#8 restent à lire/corriger selon journaux. Périmètre encore à renforcer en réel : agendas et conflits, transitions des 13 activités, permissions multi-sites/postes, facturation/avoirs/remboursements, inventaires/transferts, commissions, fiscalité, rapports et exports, parrainage, fidélité, roue (aucun tirage sans validation), support, intégrations externes, reprise après crash et réinstallation, notifications FCM physiques et Android UI métier complet. Tester autorisation et refus, valeurs invalides/limites, répétition/idempotence, coupures, concurrence, changement de compte, langue, thème et tailles d'écran. Ne pas déclarer une recette réussie avant preuve.
- Aucune mutation de main, NAXA Pharmacie, base hébergée ou secrets. Les pushes peuvent déclencher automatiquement les builds Pages de branche.


### 22.48 — 26 novembre 2026 — Pointage probant configurable par manager (candidat, NON qualifié E2E)

- Reprise: gate #721 confirmé 12/12 jobs successful (https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45875928405); Replays isolés #7 et #8 success (https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45876409704 et https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/45876496630). Ces preuves antérieures ne qualifient pas les nouveaux changements. Le Replay historique NAXA Pharmacie n'est pas accessible dans ce contexte; conserver la méthode GoTrue/PostgreSQL/Storage jetable et ne pas utiliser les données Pharmacie.
- Décision métier: pour chaque acteur subordonné et chaque événement prise de service, début/fin de pause, fin de service, le manager autorisé choisit indépendamment GPS et selfie obligatoires. L'acteur pointe lui-même; pas de galerie/import, ni suivi GPS continu, ni reconnaissance faciale imposée. Respecter le site/poste et la hiérarchie. Le client doit signaler l'absence de preuve, le serveur refuser la validation. Conserver la chronologie, l'idempotence, l'horodatage de capture et réception, et la version de politique. Le manager consulte uniquement les preuves dans son périmètre.
- Audit: ancien ns_record_staff_time_event permettait au membre opérateur de désigner un autre membre dans certains cas; RLS lecture site large; Android acceptait un nom saisi. Pas de preuve GPS/selfie obligatoire en base. Outbox Web/Android persistante; les données sensibles ne doivent pas transiter en clair durablement dans cette file.
- Candidats SQL rollback-only: supabase/drafts/naxa_services_v9_attendance_evidence.sql (ae6d56ebd7a94e4e3dad76307f6afc9cba9a6fbc), supabase/tests/drafts/naxa_services_attendance_evidence.sql (20abd3261656e34fce305a18309ad5ce309687eb), supabase/drafts/naxa_services_v9_attendance_sync.sql (c31e22c9fe112f38c9851cf48f4162f8d6c4554e), supabase/tests/drafts/naxa_services_attendance_sync.sql (664e84ed4a49d8e75ca149ddf6e9f843867a9972). Tables de politiques et de preuves, version, gardes d'écriture, accès limité, stockage privé, contrôle d'objet et coordonnées, raccordement aux quatre actions de sync avec projection privée expurgée.
- Recettes exécutées sur PostgreSQL Supabase FAMILLE-NAXA en transaction intégralement annulée, fixtures synthétiques et rôles simulés: PASS: 11 attendance assertions and rollback; PASS: 11 candidate assertions plus atomic sync, private projection and receipt. Deux corrections de montage: récupérer l'identifiant de l'appareil avant de prendre le rôle authenticated; restaurer la contrainte différée avant les écritures suivantes. Contrôle indépendant: candidate_policy_rolled_back, candidate_evidence_rolled_back, candidate_bucket_rolled_back, qa_org_removed, qa_users_removed et qa_events_removed = true. Aucun schéma v9 persistant.
- Choix techniques provisoires et non arbitrés: règle absente = preuve non obligatoire pour compatibilité; capture à 120 secondes maximum, occurrence dans une fenêtre de 5 minutes, précision GPS au plus 500 m, JPEG au plus 2 Mo. Revoir seuils et mode offline avant activation. Aucun test de position physique ni de selfie réel accepté; métadonnées Storage et absence d'objet ne prouvent ni capture caméra ni vivacité.
- RESTE A FAIRE: UI manager et résolution de la politique par site/poste/rôle avec héritage et audit des modifications; caméra native frontale et Web getUserMedia (aucun import), GPS permission/précision/refus; preuve positive upload privé, accès de lecture et rejet inter-tenant; staging de preuve privée ou outbox chiffrée, mode hors ligne et politique changée pendant la coupure; scénarios concurrence, retry, crash, double pointage et appareils multiples; vérifier autres chemins d'écriture génériques et rôles à portée poste; cycle de vie/rétention/suppression des preuves; FR/EN/Fulfulde; builds et recettes Android/Web/PWA sur nouveau SHA; vrai Replay puis validation physique et contrôles de non-régression. Ne pas activer le SQL v9 avant raccordement complet et recette de ces parcours.
- Statut: candidat serveur testé partiellement, intégration applicative non réalisée, aucun vert global. Pas de mutation main ni NAXA Pharmacie, aucun déploiement manuel. Le dépôt peut automatiquement lancer des builds de branche; ne pas les assimiler à une recette validée. Les réserves antérieures restent ouvertes. 


### 22.49 — 26 novembre 2026 — Planning hiérarchique et service-écart (candidat v10)

- Arbitrage utilisateur : planning de service modifiable par promoteur et responsables habilités, réception personnelle et notification à chaque changement; exclusion stricte du mode autonome. Voir architecture et cahier de charges mis à jour. L'agenda commercial n'est pas supprimé.
- Backend: commits 3a7b325 (planning/versionnement/notification), 2c4d080 (recette), b470dfa (comparaison avec pointages), e62b71c (recette), e405171 (annuaire autorisé), 586355a (recette combinée). Résultats réels PostgreSQL transactionnels: PASS: roster manager scope, revisions, overlap, personal access, acknowledgement, inbox, push queue, solo exclusion; PASS: roster and service comparison, original baseline preserved; PASS: roster, scoped directory, service comparison and frozen baseline. Test retard 20 min, départ anticipé 15 min, pause 30 min et modification post-pointage préservant la version 2. Contrôle rollback: shifts_rolled_back, revisions_rolled_back, links_rolled_back, notifications_rolled_back, fixtures_removed tous true. Notifications in-app/outbox vérifiées en SQL, aucune livraison FCM réelle.
- UI candidates: Web de734be/d76e07e/98a151f (Équipe, consultation, création/modification/annulation, accusé et comparaison); Android b6b0660/0fcc21f/0715143/12f6662 (carte du dashboard, manager et personnel, scopes serveur, même contrat). Les deux flags sont désactivés par défaut; pas de migration persistante ni de déploiement manuel. CI 089da77 ajoute le test v10 à Replay isolé; vérifier résultat terminal du nouveau SHA. Replay v9 #9 (45879096737) est success, mais ne vaut pas recette caméra/GPS E2E.
- Limites: contrôles SQL encore à étendre à tous les rôles et combinaisons sites/postes, annulation, services de nuit, conflits simultanés, notifications sur appareils et historique UI. Comparaison sur événements existants, v9 preuves réelles pas encore raccordées. Appariement ambigu ou manquant à examiner, pas de sanction. Options de récurrence, rotations, congés, remplacement, rappels, justification et traitement d'écart, exports et hors connexion restent ouvertes. Aucun test UI nouvellement passé attesté; vérifier build, traductions, responsive, accessibilité et E2E. Aucun changement main, données NAXA Pharmacie ou secrets. Aucun vert global.


### 22.50 — Décisions réunions et bilans audio, 26/11/2026

## Décision validée — 26 novembre 2026 : réunions internes, traduction vocale et bilan intelligent

### Réunions (architectures B/C uniquement)
Module interne Android natif, Web et PWA de type Meet, réutilisant la famille NAXA (identité, scopes, notifications, support et transport temps réel lorsqu'il existe). Le promoteur et les responsables habilités seuls programment, lancent, modèrent et terminent la réunion pour leur périmètre. Chaque invitation est individuelle, les collaborateurs invités peuvent rejoindre après ouverture, caméra/micro désactivables, partage écran, main levée, chat de réunion, liste de participants et reconnexion. Les invitations et modifications alimentent la boîte interne et le push existants. Aucun espace de réunion hiérarchique en mode A solo; le support client demeure indépendant.
Langues de réunion et audio : français, anglais, fulfulde, espagnol, italien, chinois mandarin. Sélection personnelle à tout moment, sans changer la langue d'interface ni celle des autres; reconnaissance de la langue de l'orateur et traduction/synthèse streaming, avec choix de la piste originale, sous-titres et état explicite si langue/connexion indisponible. Pas de promesse de traduction instantanée parfaite : latence, exactitude, terminologie, accents et fulfulde à mesurer sur corpus camerounais, sans voix de substitution trompeuse. Évaluation SFU/WebRTC, TURN et fournisseur speech/translation/TTS; clés et jetons courts uniquement côté serveur, autorisations par réunion, pas de lien public permanent.
Enregistrement **audio** déclenché/arrêté par responsable habilité; annonce visible/sonore à tous, information préalable et règles de consentement/conservation à valider; refus traité sans enregistrement clandestin. Piste originale conservée, horodatages et attribution si disponible, transcription et traductions optionnelles séparées. Archivage privé par organisation/réunion et accès par participants habilités; nom affiché automatiquement « Intitulé de la réunion — AAAA-MM-JJ HH-mm » (Africa/Douala), identifiant interne opaque, aucun chemin issu directement du titre. Journal d'accès, suppression/expiration selon politique, aucune clé publique ni audio sensible dans les notifications. Résumé IA, décisions et actions attribuées avec validation humaine, historique et notification ciblée; pas de décisions inventées.
### Bilan intelligent (tous les modes, selon rôle)
Bouton « Écouter mon bilan » sur l'accueil, texte et audio, choix des six langues ci-dessus, vitesse, pause/arrêt, résumé/détaillé; briefing du matin, point intermédiaire, clôture du soir et bilans jour/semaine/mois/année, archivage daté privé, notification à disponibilité, interrogation vocale d'un élément et réponse audio sous les mêmes droits. Rôle A: activité propre, sans supervision hiérarchique. Promoteur: consolidation des sites autorisés; responsable réseau/site/poste: périmètre délégué exact; employé: activité/consignes/présence/objectifs/commissions propres seulement. Jamais de montant global du site à un employé sans habilitation.
Rubriques conditionnelles par activité et droits : CA, ventes, prestations et objectifs/écarts; encaissements, dépenses, créances, résultat estimé, caisse/clôture/écarts; clientèle/fidélité/réclamations/relances; stocks/ruptures, commandes, livraisons, fournisseurs/dettes/échéances; travaux terminés/en cours/en retard; présence, service-écart, incidents NAXA SECURITY, décisions de réunion et tâches; tendances, projections et recommandations clairement séparées des faits; demain : planning, rendez-vous, priorités. Données confirmées, en attente et indisponibles distinguées; aucun zéro fictif, aucune fausse conclusion d'absence ni sanction. Source canonique serveur filtrée par RLS, snapshots versionnés et horodatés, pas de lecture de tables non autorisées depuis le moteur audio. Cache privé et révocation, traitement local quand possible, synthèse distante uniquement après contrôle du périmètre et sécurité. Langues de lecture distinctes de FR/EN/FF UI, qualité fulfulde à qualifier.
### Recettes de sortie
Aucun accès réunion en solo; interdiction de démarrer par employé ou manager hors scope; invitations et changements, non-invité/cross-tenant refusé; appel réel multi-appareils Android/Web/PWA et reconnexion; traduction six langues et changement en cours de parole, original disponible; consentement/enregistrement réel, fichier privé et nom correct, lecture/expiration et révocation; bilans exacts par rôle, période et activité, aucune fuite de données, données manquantes explicites; audio réel six langues, archivage, notifications et question/réponse; builds, responsive, accessibilité, offline et tests négatifs. Ces nouvelles exigences ne sont pas déclarées vertes avant preuve.

État initial de reprise : Replay #10 (45880505423) vert; gate #733 (45880477262) 11/12, Android APK et Web verts, PostgreSQL non exécuté à cause de Microsoft apt 403; correction CI fe5c560. Les fonctionnalités v9 preuves GPS/selfie et v10 planning ne sont pas intégralement activées. Les nouvelles exigences sont ajoutées sans déclarer l'intégration audio/vidéo complète.


### 22.51 — Exécution v11, 26 novembre 2026
- CI v10: Replay #10 (45880505423) terminé success; gate #733 (45880477262) 11/12, builds Web et Android réussis. Échec unique apt Microsoft 403 avant exécution SQL; correction fe5c560 (client préinstallé ou dépôts Ubuntu uniquement); job PostgreSQL gate #737 (45882152972) success, autres 9 contrôles success, builds interrompus par nouveau SHA (annulation de concurrence), pas de vert global.
- v11 candidat: c9a6519 schéma SQL réunions/briefing, 1125087 recette combinée. Test transactionnel réellement exécuté sur FAMILLE-NAXA: PASS: roster, meetings control plane and scoped daily briefing. Contrôles de programmation par manager, ouverture/clôture, refus de clôture employé, choix individuel italien/fulfulde, consentement modifiable, rapport personnel sans finance du site. Contrôle indépendant après rollback: meetings_rolled_back=true, briefing_rolled_back=true, fixture_notifications_removed=true. Pas de déploiement persistant ni accès media.
- Bilan partiel confirmé: RPC ns_daily_briefing, périmètre site réservé au manager autorisé, sinon rendez-vous attribués et pointages propres. Données absentes non inventées; les autres indicateurs explicitement indisponibles. Web f85def8/568d5b5, Android natif et Replay 152acd6. Six langues proposées, narration locale et vitesse; aucune voix distante substituée en cas d'indisponibilité. Flags VITE_NAXA_SERVICES_BRIEFING_ENABLED=true et NS_ENABLE_BRIEFING=true réservés à la qualification, désactivés par défaut. Relecture du fulfulde et test TTS réel indispensables. Pas encore de synthèse exhaustive ni d'archivage audio, de périodes multiples, de recommandations IA ou de question/réponse vocale.
- Qualification en cours sur le SHA 152acd6: gate #738 (45882267362), Replay #11 (45882267443), aucun résultat terminal constaté au moment de cette entrée. Recette v11 SQL sur environnement isolé ajoutée au workflow.
- Restant : v9 GPS/selfie caméra réelle, liaison v9/v10, politique manager, offline et notifications réelles, v10 rotations/congés/remplacements/justification; v11 interface réunions, invitations modifiées, scope négatif étendu, WebRTC/SFU/TURN, audio multi-appareils, traduction streaming six langues, consentement effectif, enregistrement et archivage privé, résumé/validation humaine, contrôle révoqué, toutes rubriques et périodicités bilan, audio réel, archivage et interrogation. Ni main, ni données réelles ni secrets modifiés; statut global partiel. Aucun fournisseur media ou TTS distant sélectionné/configuré.


### 22.52 — 26 novembre 2026 — Réunions v12 et autorisation média candidate
- Reprise : Replay #11 (45882267443) success; gate #738 (45882267362) 11 jobs success, Android interrompu par le gate concurrent (run annulé), pas de vert global.
- Backend v12 c9d9fd4/02b5322 : révision du titre/date/agenda/durée, historique append-only, RSVP accepté/refusé/provisoire, invalidation des confirmations lors d'une modification, notification ciblée aux invités, refus de modification par employé, révocation immédiate du droit de lecture au niveau SQL, annulation par hôte même si un invité a perdu son scope. Test réel PostgreSQL transactionnel: PASS: meeting revision, RSVP, notification, revocation, solo exclusion, roster and briefing.
- Android natif et Web/PWA 1912dca : carte Mes réunions sur accueil, sélection du site via contexte, groupe de poste/individus, programmation, invitation, modification, annulation, ouverture/clôture administratives, réponses et consentement, langue souhaitée individuelle. Mode solo masqué. Activations NS_ENABLE_MEETINGS=true / VITE_NAXA_SERVICES_MEETINGS_ENABLED=true désactivées par défaut, aucune promesse d'appel réel; pas de join media UI. La création initiale conserve une durée de 30 min, l'agenda et la durée sont éditables ensuite; édition de liste des invités, récurrence, rappels, consolidation et historique UI restent à faire.
- c29537f/4ba1781 : RPC de droit d'entrée média, identité opaque tirée de la session, room unique, refus avant ouverture et après fermeture, refus non-invité, droits hôte vs employé. Test réel PASS: meeting lifecycle and media grant before/open/after with scoped identity. Rollback vérifié (tables, RPC, notifications et utilisateurs QA absents).
- cab0066 : candidat Edge naxa-services-meeting-media, jeton LiveKit compatible HS256 90 secondes, salle et identité issues exclusivement de RPC autorisé avec JWT de l'utilisateur; ni secret, ni droits admin/création/enregistrement dans le client; partage écran hôte uniquement par défaut. Choix technique provisoire SFU LiveKit, documentation https://docs.livekit.io/frontends/reference/tokens-grants/; aucun fournisseur provisionné, aucun coût engagé, aucune clé ou configuration réelle ajoutée. NS_MEDIA_LIFECYCLE_QUALIFIED désactivé jusqu'à preuve de déconnexion effective des participants révoqués ou clôturés (l'expiration du jeton seule ne suffit pas), validation de l'instance SFU et des recettes médias. Test Deno et SQL Replay ajoutés; gate #742 (45883248987) et Replay #13 (45883249072) lancés, résultats terminaux non constatés lors de cette entrée.
- Reste non vert : appel audio/vidéo effectif multi-appareils, SDK Android/Web et TURN, contrôle micro/caméra/partage écran, chat/main levée/réactions, modération serveur, déconnexion réelle à la clôture/révocation, enregistrement effectif uniquement avec consentement et signalisation, dossier audio privé et nom automatique, traduction streaming six langues dont fulfulde, résumé IA et tâches, récurrences et modifications des invités; anciennes réserves v9/v10 et bilan v11 exhaustif maintenues. Pas de migration persistante, pas de main ni de déploiement manuel. Ne pas activer en production avant qualification.


### 22.53 — 26 novembre 2026 — v13 collaboration et v14 demandes audio
- Reprise : Replay #12 (45883112746) et #13 (45883249072) success. Gate #742 : 12/13 jobs réussis au dernier contrôle avant annulation par concurrence, Android interrompu. Pas de vert global.
- v13 : 08de7a7, 08e3e53, d338bef. Chat texte privé pendant ouverture, main levée/baissée, six réactions, annuaire des invités habilités (pas une présence média), modération réservée à l'hôte, restrictions chat/micro/partage écran, exclusion et journal des commandes. Chat non visible après fermeture, retrait d'accès SQL immédiat à l'exclusion, déduplication par UUID, limitation 5 messages ou réactions par 10 secondes et validation des réactions. Interfaces Android/Web/PWA en polling 3 secondes, toujours derrière flags v12. Recette hébergée transactionnelle PASS: collaboration, rate boundaries, moderation, exclusion and media permission intent; seuil et réaction invalide ajoutés et effectivement testés dans recette combinée 4932ae7. Contrat média exige désormais screen_allowed et microphone_allowed du serveur, jamais du client; test CI job 140130089634 success au gate #746. Les permissions sont souhaitées, pas une preuve de commande sur un flux SFU.
- v14 : c8f77fb / 6995cd5 / 4932ae7 / 0506bbe. Demande d'enregistrement audio par l'hôte seulement, consentement positif de l'hôte et des invités habilités non refusés/non exclus exigé (choix strict provisoire), état requested distinct de recording/ready, nom calculé titre + date/heure programmées Africa/Douala, idempotence, retrait du consentement et clôture annulent demande en attente. Aucun client ne peut forger ready. Test réel PostgreSQL PASS: recording request consent, host-only, idempotence, naming, withdrawal and close cancellation. Interfaces affichent explicitement moteur indisponible et demande sans capture. Aucun audio n'a été produit; pas de fichier, pas d'archive, pas de worker Egress. Le futur worker doit gérer les changements d'affectation et consentement, les présences médias, arrêt immédiat, signalisation, stockage privé, reçu et règles de rétention. Rollback vérifié : recording_rolled_back, chat_rolled_back, grant_rolled_back, fixtures_removed tous true.
- Gate #746 et Replay #14/#15 ont été déclenchés, non terminaux au dernier contrôle; commits ultérieurs peuvent annuler les gates mais pas les Replays en cours. Garder la qualification Android, Web, RLS et E2E ouverte jusqu'au résultat du dernier SHA applicatif. Pas de main, pas de migration persistante, pas de provisioning média, pas de dépenses.
- Reste : SFU réel + SDK Android/Web, caméra/micro/partage écran, commandes de modération effectives et révocation média, présence et rejoindre/quitter, capture audio réelle et archives privées, traduction temps réel six langues, récurrence/rappels/édition invités, résumé et tâches IA, anciens points v9/v10/v11. Aucun point média de bout en bout annoncé vert.


### 22.54 — Audit consolidé et pointage probant v15 (26 novembre 2026)
Voir docs/naxa-services/NAXA_SERVICES_AUDIT_FERMETURE_2026-11-26.md. Répartition B1–B6, correction de la lecture des anciens gates (FAMILLE-NAXA existe, Web ERP partiellement connecté), Replay #12–15 success ; gate #747 12/13 success puis Android cancelled. Le candidat v15 bd322cd / 53763d0 a réellement passé PostgreSQL avec staging privé et politique versionnée : PASS: private attendance staging, atomic reference, replay and policy history. Rollback indépendant : staging_rolled_back, history_rolled_back, evidence_rolled_back, bucket_rolled_back, fixtures_removed = true. Web/PWA caméra avant/GPS et référence seule 37ddd3f ; Android Camera2/GPS + identité stable et référence 4a3f21c ; recette browser capteurs simulés sur vrai Auth/Storage local fd7c506. Les flags restent désactivés en production. Gate #750 (45884788338) et Replay #18 (45884912512) non terminaux. Annulation CI des runs en cours réduite par cancel-in-progress=false, les runs pending peuvent toujours être remplacés. Pas de preuve physique, pas de mode offline probant, scope poste/rôle, nettoyage, lecture manager et réessai expiré non verts. Aucune mutation persistante, main, secret, dépense ni déploiement manuel. Toutes les réserves v10–v14 et ERP/externe/légal restent ouvertes selon audit.


### 22.55 — Correction des gates et consultation probante v16 (26 novembre 2026)
- Reprise : gate #748 (45884402730) success et Replay #17 (45884589103) success sur les révisions antérieures ; ne pas transférer ce vert aux interfaces v15/v16 non activées. Replay #18 (45884912512) failure, uniquement le scénario GPS/caméra, diagnostics initiaux limités au type Error. Gate #750 (45884788338) : Web success, sync-contract failure sur le registre OBX-001 (ligne source 1752 vs 1749), Android non terminal.
- 3ff3837 : registre JSON et Markdown recalculés à partir des 55 callsites exacts, correspondance méthode/agrégat/action préservée, OBX-047 référence de preuve documentée ; garde-fou non affaibli. Scénario Replay corrigé pour attendre la confirmation asynchrone des cases manager et tracer des étapes non sensibles. Cause exacte du Replay #18 non démontrée ; Replay #19 (45885529916) en cours lors du relevé.
- 19c03a1 : v16 candidat SQL, consultation des preuves par soi ou supérieur strict dans son périmètre, règle RLS utilisée aussi pour le selfie privé ; RPC paginé borné, refus d'une preuve expirée et purge des métadonnées temporaires expirées exclusivement service_role. Test réellement exécuté sur PostgreSQL FAMILLE-NAXA, transaction annulée : PASS: superior-only proof review, own review, expired denial and restricted purge. Contrôle indépendant review_rolled_back, purge_rolled_back, staging_rolled_back = true. Test pair de même rang avec can_manage, accès manager, accès propre, refus de purge client, conservation des preuves définitives et staging frais. La purge ne supprime pas les fichiers Storage ni ne programme un worker.
- de76f40 : consultation des preuves Android natif et Web/PWA, dates Douala, coordonnées/precision, selfie téléchargé à la demande par accès authentifié, affichage mémoire, pas d'URL publique. Replay v16 ajouté, activation uniquement dans base de recette jetable. Dernier Replay #21 (45885736533) non terminal. Aucun vert UI ni physique attribué.
- Toujours à fermer : héritage politique poste/rôle et gestion des postes, récupération/recapture après expiration et rejet, preuve selfie réelle, révocation d'accès pendant affichage, conservation/effacement fichier Storage via API, worker purge planifié, qualification native physique, autres réserves des B1–B6. Aucun changement main, migration persistante, déploiement manuel ni secret.


### 22.56 — 26 novembre 2026 — Correction caméra de recette et inventaire des orphelins v17
- Gate #748 (45884402730) et Replay #17 (45884589103) success. Gate #750 (45884788338) terminé 12/13 : Android APK et tests instrumentés Keystore/PIN success, Web success, seul registre N1 failure. Correction 3ff3837 désormais prouvée par gate #753 job 140136523661 success : source_call_sites=55, registry_rows=55, android_edge_action_parity=true, exact_callsite_bijection=true. Le gate #753 complet reste non terminal au dernier relevé.
- Replay #19 (45885529916) failure : anciens parcours et 4 pointages sans preuve réussis, TimeoutError précisément au checkpoint front camera capture. 02c8fb9 adapte exclusivement le périphérique synthétique de Chromium (requête frontale exacte et audio=false vérifiées, contrainte facingMode retirée pour le fake device seulement, vraie capture vidéo synthétique/canvas conservée). Cause technique exacte non prouvée par les logs antérieurs ; hypothèse périphérique sans facingMode physique à vérifier avec la nouvelle recette. Aucune modification du code commercial caméra. Ajout de recette de consultation UI, chargement privé du JPEG et fermeture. Replay #22 annulé avant exécution par concurrence ; Replay #24 (45886122794) candidat consolidé.
- dacaf1b : v17 inventaire SQL service_role uniquement, lot max 100, délai de grâce provisoire 24h après création ET mise à jour, chemin UUID strict dans bucket ns-attendance-selfies, exclusion des fichiers rattachés à preuve définitive, staging même expiré ou événement enregistré. Recette transactionnelle FAMILLE-NAXA réellement réussie : PASS: orphan inventory excludes active staging, recorded events and recent files. Fixtures de métadonnées synthétiques sans octets réels. Rollback indépendant inventory_rolled_back, bucket_rolled_back, fixture_metadata_removed = true.
- c4002dd : candidat worker Edge naxa-services-attendance-cleanup, secret dédié, désactivé par défaut NS_ATTENDANCE_CLEANUP_QUALIFIED=false, aucun chemin/bucket issu du demandeur, purge staging puis inventaire puis DELETE Storage API (pas de DELETE SQL des fichiers), compte des noms retournés et échec explicite si suppression partielle, tests Deno ajoutés au gate #755 (45886123170), SQL au Replay #24. Pas de worker déployé, planificateur ni suppression binaire réellement exécutée. Les tests physiques, la réconciliation en cas d'échec, le nettoyage périodique et les règles de rétention doivent être qualifiés avant activation.
- Dernier état : gate #753 et Replay #21 en cours, gate #755 et Replay #24 pending. B1 reste ouvert pour capture réelle et reprise après expiration, preuves hors ligne, règles au poste/rôle, revue après révocation et liaison planning ; B2–B6 inchangés. Aucune mutation persistante, modification main ou dépense.


### 22.57 — Correction ciblée de la consultation des preuves (26 novembre 2026)
- Gates #753 (45885736502) et #755 (45886123170) terminés success 13/13, Android APK + tests instrumentés existants, Web, RLS, synchro, contrats. Tests Deno nettoyage v17 : 3 passed / 0 failed, contrat jetons média : 2 passed / 0 failed.
- Replay #21 failure caméra. Replay #24 (45886122794) : toutes les recettes SQL v9–v17 success ; Auth/clients/caisse/stock/pointage classique/offline/photo/protection Storage/abonnement sans argent/notification sans FCM success. Scénario probant a franchi GPS et capture JPEG synthétiques, pointage HTTP 200 applied, ligne preuve persistée, lecture privée autorisée, refus étranger/anon, projection sans coordonnées. Seul échec checkpoint review evidence through commercial interface (Error).
- Audit du DOM source : section parente de contenu englobe section de consultation. Ancien locator section.filter({has:heading}) peut cibler plusieurs ancêtres ; cause très plausible mais logs #24 ne donnent pas l'exception détaillée. 399eb2f : région accessible nommée unique via aria-labelledby et test getByRole('region',{name:'Consulter les preuves',exact:true}), sans first/nth. Assertions indépendantes : RPC HTTP 200 et correspondance ID/chemin avec preuve réellement persistée ; ligne unique, JPEG authentifié HTTP 200 et MIME, image décodée URL blob éphémère, masquage et fermeture retirent aperçu et lignes. Checkpoints affinés. Aucun assouplissement caméra, RLS ou Storage.
- Gate #756 (45888152390) et Replay #25 (45888152222) déclenchés sur 399eb2f ; non terminaux à la rédaction. Ne pas déclarer le Replay vert avant son résultat terminal. Pas de déploiement, modification main, migration persistante, ni capture physique. Les autres réserves B1–B6 restent distinctes.


### 22.58 — Fermeture Replay 25 et création réunion complète v18 (26 novembre 2026)
- Replay #25 (45888152222) SUCCESS sur 399eb2f : pointage GPS/caméra simulés sur Chromium réel, confirmation HTTP 200 applied, stockage privé et lecture UI authentifiée, JPEG décodé, masquage/fermeture, non-régression. Gate #756 (45888152390) SUCCESS 13/13 sur même SHA. Ceci ferme l'échec #24, pas la preuve physique Android ni tous les parcours du cahier.
- bfc7413 : v18 candidat ns_schedule_internal_meeting_details, agenda/durée dès INSERT révision 1, invitation atomique, contrôle strict des destinataires, idempotence même UUID/mêmes paramètres tant que version initiale, rejet de payload différent et durée hors limites. Recette hébergée PostgreSQL en rollback PASS: initial agenda and duration, idempotent invitation, host scope and invalid duration denial. Contrôle indépendant candidate_rolled_back, meetings_rolled_back, fixtures_removed = true. Idempotence serveur qualifiée ; reprise client après réponse réseau perdue avec conservation UUID/horodatage reste à qualifier.
- d246e11 : Web/PWA et Android transmettent agenda et durée dès création ; validation UI native de durée, région réunions accessible ; bilan Web recharge les faits serveur avant lecture, écarte réponse annulée/ancienne, désactive changement langue/vitesse pendant requête. Voix locales seulement, pas de voix attestée.
- Replay #26 (45888999919) lancé sur d246e11 : candidats v9–v18 nécessaires activés uniquement sur base jetable, flags planning/réunions/bilan/pointage actifs dans build de recette ; nouveau scénario de deux sessions Auth navigateur (promoteur + employé même org) : agenda/durée, RSVP, choix langue, consentement, ouverture sans média, main levée/chat/réaction/modération, demande audio et retrait, clôture, bilan partiel scope personnel/site et traduction texte, publication et accusé planning. En cours au dernier contrôle, pas de résultat affirmé. Gate #758 (45888999779) en cours, 10/13 success, Web/PG/Android non terminaux.
- Restant : B1 preuve physique/expirée/offline/postes/rotations/congés/justification et planification cleanup, B2 récurrence/rappels/modif invités/SFU réel/révocation/presence/caméra/micro/partage, B3 audio réel et archive/6 traductions voix et bilan exhaustif/IA, B4 recettes complètes ERP 13 activités, B5 preuves fournisseurs externes, B6 linguistique physique/juridique/release. Pas de mutation persistante, main, déploiement ni dépense. Ne pas annoncer vert global avec CI technique seule.


### 22.59 — Replay hiérarchique vert et récurrences v19 (26 novembre 2026)
- Replay #26 (45888999919) SUCCESS sur d246e11, logs effectifs : PASS two browser accounts: initial agenda, RSVP, language preference, chat, hand, reaction, moderator restriction and recording consent withdrawal; no media capture. PASS real scoped partial briefing text and language selection, no synthetic audio claim. PASS two browser accounts: published roster, employee acknowledgement and manager view. PASS commercial proof review et GPS/caméra simulés, stockage privé et reçu. Gate #758 (45888999779) 12/13 success, Android Keystore/PIN non terminal à la lecture. Aucun échec constaté.
- 54f856b : candidat v19 séries quotidiennes/hebdomadaires, 2–12 occurrences (limite provisoire), première date ≤ 1 an, cadence UTC+1 Douala en heures 24/168, UUID occurrence déterministe, création atomique via v18 avec agenda/durée et invitations. Répétition de même requête idempotente, conflit si payload différent, limitation et refus rôle employé, table série privée ; annulation d'une occurrence distincte. Recette transactionnelle FAMILLE-NAXA PASS: bounded recurring meetings, cadence, invitation idempotence and individual cancellation. Contrôle indépendant series_rolled_back, rpc_rolled_back, fixtures_removed = true.
- 5e03963 : champs répétition/quantité et indicateur occurrence Android/Web/PWA, recette deux comptes pour série 3 réunions et annulation isolée, activée seulement dans stack jetable. Gate #760 (45889838748) pending, Replay #27 (45889838677) in_progress au relevé. La recette UI de série, relance réseau stable côté client, édition/annulation globale de série, rappels, modification invités, SFU/caméra/micro/partage et traduction/recording effectifs restent ouverts. Aucune activation de flags en production, aucune migration persistante, modification main ni dépense.
