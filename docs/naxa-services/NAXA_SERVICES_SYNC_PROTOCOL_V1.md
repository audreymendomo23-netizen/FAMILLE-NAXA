# NAXA SERVICES — contrat de synchronisation ERP v1

**Statut :** spécification technique candidate — non implémentée, non activée, non déployée.  
**Périmètre :** synchronisation Android natif Kotlin/Room ↔ passerelle Edge ↔ Supabase isolé Famille NAXA.  
**Référence d'audit :** branche `work/naxa-services-completion-20261120`, commit `2d4334e9eaeae4cc1fdf63aa07859b47ba165a32`.

## 1. Décision d'architecture

La synchronisation sera une réplication d'opérations métier idempotentes, pas un envoi aveugle de lignes locales. Le téléphone conserve le droit de travailler hors ligne ; le serveur confirme et consolide seulement les opérations qu'il a authentifiées, autorisées, validées et appliquées.

Aucun enregistrement local ne doit être déclaré synchronisé sur la seule base d'un envoi HTTP accepté. L'état local ne passe à `synced` qu'après une réponse serveur `applied` ou la répétition idempotente d'une opération déjà appliquée avec le même contenu.

## 2. État réel audité

### 2.1 Outbox Android actuelle

La table `local_outbox_events` existe, et le dépôt déclenche environ 55 points d'enqueue métier. Le contrat actuel de `payloadJson` ne contient cependant que `aggregate_id` et `site_id`. Il ne contient ni la photographie complète de l'entité ni les paramètres nécessaires pour rejouer l'action côté serveur.

Conséquence : cette outbox est un journal local d'intentions, pas encore une file de réplication exploitable. Un worker ne doit pas transmettre ces événements et les marquer comme synchronisés.

### 2.2 Dépendances et identifiants du cycle fournisseur

Le draft SQL v4 contient des RPC pour créer une commande fournisseur, enregistrer une réception et enregistrer un règlement. Dans l'état du draft, la création serveur génère un UUID pour la commande et pour chaque ligne. L'application locale détient déjà d'autres UUID pour ces objets. Les RPC de réception et de paiement exigent ensuite les identifiants serveur.

Pour une commande créée hors ligne, les opérations suivantes ne peuvent donc pas encore être rejouées de manière fiable sans l'une de ces deux stratégies :
- **ID partagé :** le client fournit ses UUID locaux à la création serveur ; après validation stricte et contrôle de périmètre, le serveur conserve les mêmes UUID pour la commande et ses lignes ;
- **Correspondance explicite :** le serveur renvoie et conserve une correspondance durable `local_id → remote_id` pour l'organisation, le site et le type d'objet ; les opérations dépendantes attendent la résolution de cette correspondance.

La première stratégie est préférée pour les agrégats créés par un appareil. Elle évite les tables de correspondance pour les commandes et lignes, mais doit être appliquée de façon cohérente aux fournisseurs, articles, caisses et autres références métier. La seconde demeure nécessaire pour les objets dont l'identifiant est exclusivement serveur.

## 3. Enveloppe d'événement cible

Chaque événement transmissible doit contenir au minimum :

| Champ | Règle |
|---|---|
| `event_id` | UUID stable généré une seule fois localement ; clé d'idempotence transport |
| `schema_version` | Version entière du contrat de payload |
| `app_code` | Constante `naxa-services` |
| `org_id`, `site_id` | Périmètre attendu ; toujours revérifié côté serveur |
| `aggregate_type`, `aggregate_id` | Objet métier ciblé |
| `action_code` | Action autorisée et versionnée, jamais du SQL ni un nom de table arbitraire |
| `device_sequence` | Séquence strictement croissante de l'installation |
| `occurred_at` | Date locale de l'opération, conservée comme donnée métier |
| `payload` | Champs nécessaires à l'action, pas seulement un pointeur local |
| `payload_sha256` | Empreinte canonique calculée côté serveur sur le contenu normalisé |

L'identité du membre, du compte et de l'appareil doit être dérivée de la session bearer active et des enregistrements d'appareil côté serveur. L'application Android n'a jamais de clé `service_role` et ne peut pas déclarer elle-même qu'un paiement, une vente ou un rapprochement est confirmé.

## 4. Exemple de contrat : cycle fournisseur

### 4.1 Création d'une commande

Payload requis : UUID client de la commande, UUID client de chaque ligne, fournisseur, référence, facture fournisseur, lignes complètes (article de stock éventuel, type de ligne, description, unité, quantité, coût unitaire), taxes récupérables et non récupérables, transport, autres frais, échéance, notes et clé idempotente.

Le serveur vérifie :
- membre authentifié et droit de gestion sur le site ;
- fournisseur et articles appartenant au même couple organisation/site ;
- types de lignes et montants admissibles ;
- absence de réutilisation de clé avec un contenu différent ;
- unicité des UUID dans le périmètre.

Réponse : `applied`, ID canonique de la commande et des lignes, statut et version serveur.

### 4.2 Réception partielle ou totale

Payload requis : IDs canoniques de commande et de ligne, quantité reçue, clé idempotente et version attendue de la ligne/commande. Le serveur recalcule les coûts, la ventilation des taxes/frais et les écritures comptables ; il ne fait confiance ni au total local ni à un compte comptable fourni par le téléphone.

Une réception ne peut être appliquée avant que la commande et la ligne existent côté serveur. Une même clé avec une quantité ou un objet différent devient un conflit/rejet explicite.

### 4.3 Règlement fournisseur

Payload requis : ID canonique de commande, montant, méthode, référence, clé idempotente et, pour un paiement espèces, ID canonique d'une session de caisse ouverte. Le serveur vérifie le solde dû, les droits de caisse, le montant restant et le statut de la commande. Un règlement n'est jamais comptabilisé comme une seconde charge d'exploitation.

Les règlements espèces restent bloqués tant que la session de caisse locale n'a pas un identifiant serveur reconnu et une session distante ouverte correspondante.

## 5. Ordonnancement, idempotence et conflits

- Les événements sont traités dans l'ordre des dépendances et dans l'ordre de séquence d'un appareil.
- Les commandes parentes doivent être appliquées avant leurs lignes dépendantes, réceptions et règlements.
- L'unicité de `(org_id, client_event_id)` et `(device_id, device_sequence)` côté serveur empêche les doubles soumissions.
- Même clé + même empreinte : retourner le reçu initial, sans nouvelle mutation.
- Même clé + empreinte différente : rejeter et créer une trace de conflit ; ne jamais choisir silencieusement le dernier payload.
- Les écritures append-only (paiements, réceptions, ventes, événements comptables) ne sont jamais fusionnées ni remplacées par `last-write-wins`.
- Les objets mutables utilisent une version optimiste. Les versions incompatibles donnent `conflict` avec snapshots serveur/client.
- Résolutions permises : serveur gagnant, client gagnant, fusion validée ou arbitrage manuel ; la résolution et son auteur sont audités.
- Une opération `rejected` pour validation ou autorisation ne doit pas être retentée automatiquement.

## 6. États locaux, reprise et erreurs

États proposés : `queued`, `sending`, `accepted`, `synced`, `conflict`, `rejected`, `blocked_dependency`, `retry_wait`.

- Réseau indisponible, timeout, HTTP 429 ou 5xx : reprise avec backoff exponentiel plafonné et jitter.
- HTTP 400/401/403 ou code métier de validation : pas de boucle automatique ; renouvellement de session si autorisé, sinon action utilisateur ou support.
- `conflict` : conserver les deux snapshots et bloquer les opérations dépendantes.
- `blocked_dependency` : attendre l'application de l'objet parent (commande, article, fournisseur ou caisse).
- Le nombre d'essais, la prochaine date de reprise et le dernier code d'erreur sont conservés sans jeton ni données secrètes.
- Les événements ne sont jamais supprimés avant confirmation d'application et conservation locale conforme à la politique de rétention.

## 7. Sécurité serveur

La passerelle doit :
1. valider le JWT et la session appareil active ;
2. résoudre le membre actif de l'organisation ;
3. recalculer les autorisations organisation/site/poste via les helpers de périmètre ;
4. valider le schéma et la taille de chaque payload ;
5. calculer elle-même l'empreinte canonique ;
6. enregistrer le reçu et appliquer l'opération dans une transaction contrôlée ;
7. n'accorder à l'application que les appels d'actions autorisées ;
8. préserver l'audit sans exposer les secrets, alias Auth, données personnelles non nécessaires ou contenu sensible dans les journaux.

Les tables `ns_sync_receipts`, `ns_sync_conflicts` et `ns_notification_outbox` restent réservées à `service_role`. Le téléphone n'écrit jamais directement dans ces tables.

## 8. Critères d'acceptation avant activation

1. Contrat de payload complet pour chaque action activée ; les actions non prises en charge restent bloquées et visibles.
2. IDs stables ou table de correspondance transactionnelle pour toutes les références croisées.
3. Tests unitaires de normalisation JSON, hash, idempotence et séquence.
4. Tests API négatifs : autre tenant, autre site, appareil révoqué, poste non assigné, montant excessif, compte non autorisé.
5. Tests de reprise après coupure réseau, fermeture forcée, redémarrage et répétition de la même requête.
6. Tests de concurrence sur réception partielle et règlements partiels.
7. Tests d'intégration sur une base Supabase **isolée**, avec RLS et jeux de données artificiels.
8. Recette Android sur au moins deux appareils d'une même organisation et deux sites ; vérification des conflits.
9. Aucun statut `synced` avant un reçu `applied` vérifié.

## 9. Phasage de réalisation

| Phase | Livrable | Gate |
|---|---|---|
| S0 | Projet Supabase Famille isolé et coût/accès approuvés | Aucun toucher à l'ancien projet NAXA |
| S1 | Contrat UUID stable ou mappings, schémas et RPC idempotentes | Tests SQL/contrats réussis |
| S2 | Edge Function de synchronisation avec scopes, reçus et conflits | Tests Auth, RLS et API réussis |
| S3 | Migration Room de l'outbox, payloads complets, reprises et worker WorkManager | Tests locaux et hors ligne réussis |
| S4 | Pilote multi-appareils / multi-sites | Validation des doublons, conflits et rapprochements |
| S5 | Activation progressive et supervision | Retour arrière documenté |

## 10. État de livraison

Ce document est une spécification de travail. Le worker, l'endpoint sync, les mappings d'IDs et les tests d'intégration ne sont pas implémentés ici. Les écrans qui indiquent que la synchronisation n'est pas encore raccordée doivent conserver cette mention jusqu'à réussite des gates ci-dessus.

Aucune migration SQL n'est appliquée, aucune Edge Function n'est déployée, aucun projet Supabase existant n'est modifié et aucune version de production n'est déclarée.


## 12. Addendum — Implémentation du contrat d'identifiants et de l'orchestration manuelle (21 novembre 2026)

Le code candidat conserve les UUID locaux pour fournisseurs, commandes et lignes. `ns_save_supplier` accepte l'ID fournisseur local et rejette tout ID déjà détenu par une autre organisation/site. La création de commande utilise l'ID de la commande comme clé d'idempotence et clé primaire serveur ; le payload transmet un ID pour chaque ligne, que le RPC conserve également. Les réponses de commande retournent les IDs des lignes.

Room version 12 ajoute métadonnées de tentative/reprise. Les événements du cycle fournisseur portent un snapshot complet. Le coordinateur manuel traite seulement les actions fournisseur, commande, réception et paiement, dans l'ordre du journal ; il n'accepte l'état `synced` qu'après réponse serveur et ID distant. Les erreurs transitoires sont retentées avec backoff ; les rejets et dépendances sont conservés. Un paiement espèces reste bloqué tant que la session de caisse serveur n'a pas de correspondance.

L'activation est fausse par défaut et exige une référence de projet de recette Famille NAXA, identique à la référence configurée, ainsi qu'un endpoint Edge correspondant. Le projet NAXA historique connu est explicitement refusé.

**Reste ouvert :** sync des articles importés/autres familles, réplication de caisse, worker automatique, résolution de conflits et tests sur deux appareils/base isolée. Cette implémentation n'a encore été ni compilée par la CI de ce commit, ni déployée.
