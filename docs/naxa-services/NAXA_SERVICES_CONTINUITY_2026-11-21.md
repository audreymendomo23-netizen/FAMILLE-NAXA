# NAXA SERVICES — document de continuité dédié

**Version :** 1.0  
**Date d'audit :** 21 novembre 2026  
**Dépôt :** `audreymendomo23-netizen/FAMILLE-NAXA`  
**Branche de travail :** `work/naxa-services-completion-20261120`  
**HEAD de référence :** `38df9449e196c1074272097d9440fcf132dfa99b`  
**Statut global :** **NON VERT — construction fonctionnelle à poursuivre avant Supabase**

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

- Branche de travail : `work/naxa-services-completion-20261120`.
- HEAD et dernier gate technique : `38df9449e196c1074272097d9440fcf132dfa99b`.
- Gate technique [44944767801](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44944767801) : terminé, **12/12 jobs en succès**.
- Le commit `ac239b915777dfa0bfdb0b45dddc902f6a28aafb` est le HEAD du workflow séparé de sauvegarde/restauration [44942987790](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44942987790), qui a terminé **1/1 job en succès**. Il ne faut pas le présenter comme commit du dernier gate technique.
- Aucune fusion vers `main`, aucun déploiement et aucune migration sur Supabase historique constatés.

### 2.2 Ce que couvre le gate technique

Les douze jobs réussis couvrent : Auth et périmètres, build Web, contrat de synchronisation offline, catalogue tarifaire Famille, paiements/commissions/fiscalité, API de parrainage, contrats FCM/notifications, promotion/parrainage client, comptabilité fournisseurs/prévisions, vérification statique RLS/SQL, compilation et tests Android instrumentés, PostgreSQL 17 et tests RLS runtime sur base jetable.

Ce résultat valide le socle CI et les contrats testés. Il ne prouve pas que toutes les fonctions affichées par Android et Web sont opérationnelles.

### 2.3 Artefacts

- APK Debug : artefact GitHub Actions [14723675607](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/44944767801), taille 13 571 428 octets.
- Digest SHA-256 de l'archive de l'artefact : `fc436b37e95cc28d74d072f903e228a68da7eb994ab1e2c2569fac3fbee9a90a`.
- Ne pas confondre le digest de l'archive avec le hash du fichier APK individuel.
- La Release reste non signée tant que le keystore/certificat du propriétaire et les secrets GitHub ne sont pas disponibles.

Le drill backup/restore PostgreSQL 17 est vert sur deux bases jetables isolées. Il ne représente pas encore une reprise réelle d'un environnement hébergé.

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

## 5. Web/PWA — travaux obligatoires

Le code actuel de `apps/web/naxa-services/src/main.tsx` conserve les opérations via `addLocalEntry()` dans l'état React. Les enregistrements disparaissent au rechargement et ne sont pas envoyés au backend. Les pages de modules montrent explicitement des états locaux/à connecter.

Le package `packages/offline-web` contient une base IndexedDB avec lease multi-onglets, retries, états de conflit/rejet et acquittement par reçu serveur. Ce mécanisme n'est pas encore raccordé à chaque formulaire et module Web.

Sortie requise :
- brancher les formulaires et vues sur les API de domaine ;
- partager les règles d'autorisation, validations et statuts métier avec l'Android ;
- mettre les snapshots en IndexedDB avant envoi ;
- appliquer les reçus explicites, conserver les conflits et les rejets ;
- recharger les vues depuis la base serveur et le cache local ;
- tester online/offline, reconnexion, double onglet, reprise après crash et changements de session ;
- ne jamais afficher une création locale comme un encaissement ou un document serveur confirmé.

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
| Cycle fournisseur | Quatre snapshots, quatre actions supportées par le coordinateur manuel ; dépendances article distant et caisse espèces | PARTIEL — code et coordinateur présents ; dépendances et activation isolée non prouvées |
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

## 11. Correctif d'audit comparatif — 21 novembre 2026

Le comptage des 55 appels d'outbox n'est pas un inventaire de 55 fonctionnalités non terminées. Le précédent texte qui présentait les 51 appels sans snapshot comme 51 fonctions incomplètes est retiré : il n'était pas suffisamment étayé.

Le document de confrontation NAXA_SERVICES_EVIDENCE_RECONCILIATION_2026-11-21.md met en regard les déclarations des sections 30, 34, 39, 41, 44, 46 et 47 du dossier de construction, les écrans Android, les fonctions Auth/Edge, les contrats et les tests.

Règle de qualification :
- VERT LOCAL : parcours Android/Room construit et explicitement livré dans la portée locale ;
- VERT API/CONTRAT : endpoint, client et contrat/test présents, sans présumer de leur déploiement réel ;
- PARTIEL : une partie du parcours fonctionne, mais un maillon métier, ledger, worker ou dépendance reste ouvert ;
- ROUGE PROUVÉ : une contre-preuve directe existe (écran local, appel métier absent, route absente du coordinateur actif, garde fail-closed ou workflow non exécuté) ;
- BLOQUÉ EXTERNE : projet, secret, compte marchand, clé ou validation professionnelle/juridique manquante ;
- À QUALIFIER : les éléments disponibles ne suffisent pas pour conclure.

Le parrainage client Android, le centre de notifications Android, l'API Auth/profil/site/poste, les briefings locaux et les rappels de charges locaux sont des capacités réellement présentes : elles ne doivent plus être listées comme absentes. Les limites restant démontrées concernent leur portée (FCM réel, intégration de récompense au ledger, synchronisation CRM/ERP, déploiement), pas leur simple existence.

Le gate CI le plus récent est le run 44946137015, 12/12 jobs SUCCESS sur le commit documentaire 697d58f. L'artefact Android correspondant est Debug, ID 14724147044, digest d'archive SHA-256 edfa9665b220a1442b1a82455d6da2e07f221172d7b226761cf25c95b46b5e7e. La branche main reste indépendante.
