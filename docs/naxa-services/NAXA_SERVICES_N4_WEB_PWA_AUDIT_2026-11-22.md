# NAXA SERVICES — N4 Web/PWA : audit de démarrage et blocages vérifiés

**Date :** 22 novembre 2026  
**Dépôt :** `audreymendomo23-netizen/FAMILLE-NAXA`  
**Branche :** `work/naxa-services-completion-20261120`  
**Gate :** N4 — Web/PWA et parité métier  
**Verdict de départ :** PARTIEL — N4 lancé en audit, fermeture refusée tant que les contrats serveur manquants ne sont pas livrés et testés.

## 1. Règle de qualification

N4 n'est vert que lorsque chaque parcours Web livré utilise un contrat métier serveur autorisé, persiste les mutations dans IndexedDB hors ligne, ne confirme qu'après reçu serveur vérifié, recharge les données depuis une source persistante, et passe les tests de reprise, concurrence, scopes et parité avec Android.

Une page, un formulaire React, une ligne de brouillon en mémoire, un build Vite ou un événement placé dans la file ne prouvent pas une mutation métier serveur.

## 2. Preuves de code consultées

- `apps/web/naxa-services/src/main.tsx` : authentification Web, renouvellement et révocation de session, file IndexedDB, traitement des reçus, création d'article de stock.
- `packages/offline-web/src/index.ts` : file IndexedDB v2, idempotence de l'event ID, leases de batch, retries et reçus.
- `apps/web/naxa-services/src/erp/inventory.ts` : normalisation/validation des fiches article.
- `supabase/functions/naxa-services-accounting/index.ts` : allowlist effective des actions comptables Web.

### 2.1 Actions actuellement exposées par l'Edge Accounting

Actions observées dans le switch de la fonction :
- `pull_sync_changes`
- `apply_sync_event`
- `save_inventory_item`
- `record_inventory_movement`
- `save_supplier`
- `create_supplier_purchase`
- `receive_supplier_purchase_line`
- `record_supplier_payment`
- `post_sale_inventory`
- `create_performance_objective`
- `performance`

Cette liste est la surface d'API constatée dans ce fichier, pas une preuve que tous les parcours Android ou les 44 mutations du registre N1 ont un handler Web utilisable. Toute action non présente dans l'allowlist doit échouer explicitement ; ne pas inventer de nom RPC ou de schéma.

## 3. Matrice de l'interface Web au HEAD audité

| Module / parcours | État observé | Qualification N4 |
|---|---|---|
| Authentification, changement de mot de passe, déconnexion | Auth réelle, jetons en mémoire, renouvellement et révocation | VERT API/CONTRAT — périmètre Auth uniquement |
| Stock — création d'article | File IndexedDB, action `save_inventory_item`, reçu obligatoire et acquittement contrôlé | VERT API/CONTRAT pour cette action ciblée ; pas de parité stock complète |
| Stock — mouvements, import, valorisation | Actions serveur partielles existantes mais écrans Web non raccordés à l'ensemble du parcours | PARTIEL |
| Fournisseurs, achats, réceptions, paiements | Actions Edge disponibles ; aucun parcours UI Web complet démontré | PARTIEL — connecteurs UI et tests E2E à réaliser |
| Vue d'ensemble / indicateurs | Métriques affichées comme placeholders ; pas de chargement serveur démontré | ROUGE |
| Agenda / rendez-vous / liste d'attente | Écran et brouillons en mémoire ; transitions locales | ROUGE |
| Pressing / tickets / transitions | État de ticket modifié localement par `setEntries` | ROUGE |
| Caisse / ventes / dépenses / clôtures | Aperçu local ; aucune mutation caisse Web confirmée | ROUGE |
| Catalogue de prestations / services | Aperçu local ; aucune API métier Web démontrée | ROUGE |
| Clients / CRM / suivis / fidélité | Aperçu local ; aucune API métier Web démontrée | ROUGE |
| Équipe / présence / commissions | Aperçu local ; aucune API métier Web démontrée | ROUGE |
| Rapports / comptabilité | Lecture `performance` disponible dans Edge, mais non raccordée à l'écran ; le reste n'est pas démontré | PARTIEL/ROUGE |
| Organisation / sites / postes / réseau | Mode, site et états gérés en React ; aucune persistance métier Web démontrée dans ces écrans | ROUGE |
| Sécurité / appareils / assistance | Auth et demande de récupération sont raccordées ; journal d'audit et support métier non démontrés depuis les écrans | PARTIEL |

## 4. Limites transversales vérifiées

1. `addLocalEntry()` crée des entrées dans le seul état React ; elles ne sont pas des mutations serveur.
2. Les transitions pressing et certains réglages de structure modifient également l'état local de l'interface.
3. Le composant Web n'effectue pas de chargement/reconstruction complète des registres métier depuis le serveur au démarrage ou après rechargement.
4. Le package offline expose une file sortante, mais le client Web n'a pas encore de consommateur complet du journal entrant N3 ni d'application des projections dans ses registres métier.
5. Le flux d'acquittement de la file ne peut valider que les reçus reconnus par sa politique ; les opérations rejetées ou en attente doivent rester visibles et récupérables.
6. Le gate N1 classe 44 mutations distantes, dont 33 contrats sont indiqués comme cible des gates de réalisation. Le gate serveur N2 reste décrit comme PARTIEL dans la définition de sortie de continuité. La parité de 92 codes d'action entre Android et Edge ne doit pas être interprétée comme 92 handlers métier implémentés.

## 5. Dépendances et ordre de fermeture

### N4-A — Contrats serveur utilisables par le Web
- Fermer d'abord le gate N2 pour chaque mutation réellement requise : handler typé, RPC transactionnel, scope Auth/org/site/poste/rôle, reçu atomique, idempotence, payload divergent, dépendances et tests négatifs.
- Publier une matrice explicite des actions Web autorisées par module.
- Ne jamais router un événement Web vers `apply_sync_event` comme substitut à un handler métier manquant.

### N4-B — Couche de données Web
- Créer des clients de domaine typés sur les actions réellement livrées.
- Charger les données initiales et recharger les projections après mutation.
- Persister les mutations hors ligne avec IDs stables, dépendances et version de schéma.
- Appliquer les reçus seulement après validation de l'event ID et de l'état métier.
- Consommer le pull N3 avec curseur persistant et appliquer les changements distants sans écho.
- Conserver conflits, rejets et dépendances bloquées ; ne jamais supprimer une mutation en attente.

### N4-C — Raccordement écran par écran
- Agenda, pressing, caisse/ventes, services, CRM/clients, équipe, stock, achats/fournisseurs, rapports, organisation/sites/postes et assistance.
- Chaque action UI doit afficher sans ambiguïté : brouillon local, en attente, confirmé serveur, conflit ou rejet.
- Retirer les chemins qui ressemblent à une opération réelle lorsqu'ils ne font qu'appeler `addLocalEntry()`, ou les garder explicitement dans un mode Aperçu non opérationnel.

### N4-D — Recette Web/PWA
- Online/offline, reconnexion, onglets multiples, double clic, lease expiré, crash/reprise et réponse serveur perdue après mutation.
- Changement de compte, révocation, changement d'organisation/site, rôle insuffisant et payload divergent.
- Persistance après rechargement et convergence Web ↔ Android ↔ serveur.
- Vérifier qu'aucun événement distant ne crée une nouvelle entrée outbox.
- Build, tests unitaires, tests navigateur et tests PostgreSQL 17 jetables sur les mêmes contrats.

## 6. Garde-fous conservés

- Branche de travail uniquement : `work/naxa-services-completion-20261120`.
- Aucun commit sur `main`, aucune fusion et aucun déploiement.
- Aucun draft SQL ni Edge Function sur le projet Supabase historique NAXA/pharmacie.
- Aucun secret ou donnée client réelle dans Git.
- Aucun écran ou endpoint non implémenté ne sera marqué opérationnel.
- Les parcours Android validés par N3 ne sont pas réécrits pour fabriquer une fausse parité Web.

## 7. Verdict

**N4 est lancé et audité ; N4 n'est pas fermé.** La création Web d'article de stock et l'authentification sont des vertical slices réels, mais le reste de l'interface métier est encore en aperçu local ou sans raccordement complet. Le blocage structurel est l'absence de handlers métier démontrés pour l'ensemble des mutations attendues, ainsi que l'absence de lecture/reconstruction Web et de consommation du pull entrant.

Le gate N4 ne pourra passer au vert qu'après livraison et preuve de N4-A à N4-D. Un changement documentaire, un build ou une couche générique qui masque l'absence de handler ne satisfait pas la recette.
