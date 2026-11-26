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
