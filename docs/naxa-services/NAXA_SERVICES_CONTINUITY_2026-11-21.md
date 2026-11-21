# NAXA SERVICES — document de continuité dédié

**Version :** 1.1  
**Date de mise à jour :** 22 novembre 2026  
**Dépôt :** `audreymendomo23-netizen/FAMILLE-NAXA`  
**Branche de travail :** `work/naxa-services-completion-20261120`  
**HEAD de référence :** `ada9bc2fe4986925a6afcc07238c0bbdc11f2073`  
**Statut global :** **VERT CI (12/12) et VERT RLS LABORATOIRE — NON VERT OPÉRATIONNEL / PRODUCTION**

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
- HEAD vérifié le 22 novembre : `ada9bc2fe4986925a6afcc07238c0bbdc11f2073`.
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

Le coordinateur SupplierSyncCoordinator.kt ne prend actuellement en charge que quatre actions pour la synchronisation ERP manuelle du cycle fournisseur : supplier.saved, purchase.ordered, purchase.receipt.confirmed et supplier.payment.recorded. Ces quatre actions disposent de snapshots spécifiques et d'un handler Edge/RPC correspondant.

Les 51 autres appels utilisent encore le payload de repli aggregate_id/site_id. Cela prouve qu'ils ne sont pas rejouables par ce coordinateur avec le contrat actuel ; cela ne prouve pas, à lui seul, que les fonctions correspondantes sont absentes. Certaines opérations ont des chemins API directs distincts de l'outbox (Auth, profil organisation, sites, postes, parrainage PME, parrainage client/promotions et centre de notifications). D'autres sont explicitement des registres locaux Room. Le classement fonction par fonction figure dans NAXA_SERVICES_EVIDENCE_RECONCILIATION_2026-11-21.md.

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

La liste doit être extraite et validée contre les 55 call sites à chaque étape. Ne pas inventer un mapping serveur par ressemblance de nom.

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
| Inventaire des 55 points d'outbox | Classer chaque call site : mutation métier à synchroniser, journal local, copie/cache ou action couverte par une API directe | À QUALIFIER — ne pas assimiler 55 événements à 55 fonctions manquantes |
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

1. Construire la matrice des 55 actions et dépendances depuis les sources Android et les tables SQL.
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
- HEAD : `ada9bc2fe4986925a6afcc07238c0bbdc11f2073`.
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
| 1 | Inventaire et qualification des événements métier | **À QUALIFIER / PARTIEL** | Les 55 points d'émission d'outbox sont recensés un par un et classés : mutation à répliquer, événement local/audit, cache/mirror ou action déjà couverte par une API directe. Pour chaque mutation à répliquer : agrégat, code d'action/version, snapshot, ID stable, organisation/site/poste/acteur, dépendances, source de vérité, handler, reçu, conflit, stratégie retry et test sont documentés. Aucun événement n'est déclaré manquant sur la seule base d'un comptage. Le code actuel accepte 11 codes d'action du cycle fournisseur et des prérequis stock ; la couverture complète des autres domaines n'est pas démontrée. Le gate est vert quand 100 % des call sites sont classés et que chaque mutation promise a un contrat approuvé, sans événement orphelin ni doublon de périmètre. |
| 2 | Handlers et mutations serveur | **PARTIEL — contrats/RPC en laboratoire, pas de backend hébergé dédié** | Chaque action issue de la matrice possède un handler typé et un RPC transactionnel ; Auth vérifie organisation, site, poste, rôle et propriété de l'agrégat. La mutation métier et son reçu idempotent sont persistés atomiquement. Un double envoi identique renvoie le même résultat ; un même ID avec payload divergent est rejeté ; une dépendance manquante ou un scope invalide est bloqué ; un crash/retry ne crée ni doublon ni perte. Tous les scénarios sont testés positivement et négativement sur PostgreSQL jetable et, après autorisation, sur l'environnement dédié. Le gate est vert lorsque toutes les actions du gate 1 ont une implémentation serveur prouvée, et non lorsque quelques RPC compilent. |
| 3 | Synchronisation Android globale | **ROUGE — cycle fournisseur/stock étendu, synchronisation universelle non livrée** | Chaque mutation locale qui doit être partagée rejoint une outbox durable avec snapshot versionné, identifiants stables et dépendances ; le coordinateur prend en charge toutes les actions approuvées, automatiquement et manuellement, avec backoff, reprise, mapping des IDs distants et résolution de conflits. Les reçus persistants seuls font passer un événement à synchronisé. Les scénarios multi-appareils, hors ligne prolongé, redémarrage, double envoi, ordre de dépendances, changement de site et rejet serveur passent. Au HEAD courant, `SupplierSyncCoordinator` n'est toujours que manuel/opt-in ; il accepte 11 codes `supplier.*`, `inventory_item.*`, `inventory_movement.*` et `purchase.*`, et bloque encore les achats sans mapping article ainsi que les règlements espèces sans mapping de session de caisse. Les autres domaines ne sont pas couverts par un coordinateur global. |
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

1. Terminer l'inventaire des 55 call sites et approuver le périmètre de réplication par domaine.
2. Élargir les handlers/RPC et leurs reçus transactionnels selon la matrice, en conservant les tests PostgreSQL jetables.
3. Construire les coordinateurs Android par agrégat avec les dépendances et la résolution de conflits, puis couvrir multi-appareils.
4. Étendre la file Web/PWA des parcours déjà intégrés (à commencer par stock) à chaque module du périmètre validé.
5. Relier les événements de caisse/prestation aux commissions, fidélités, parrainages, paiements et journaux ; obtenir les visas métier et professionnels.
6. Obtenir les environnements et contrats Firebase/Mobile Money, puis réaliser les essais intégrés réels.
7. Préparer signature, conformité, recette physique et restauration hébergée.
8. Exécuter un gate final complet, constituer le dossier de preuves et seulement ensuite soumettre la création du projet Supabase dédié à autorisation.

**Décision de continuité au 22 novembre 2026 :** le dépôt est **VERT CI 12/12** sur le HEAD mentionné, et le laboratoire PostgreSQL 17 couvre le schéma/RLS ; la restauration laboratoire est **VERT 1/1** sur son run distinct. NAXA SERVICES n'est pas déclaré globalement vert : les gates 1 à 8 conservent les statuts précis ci-dessus. Aucun Supabase NAXA Services hébergé, aucune Release signée et aucune intégration marchande/FCM réelle ne sont attestés à cette date.
