# NAXA SERVICES — N3-B : conception du flux de synchronisation entrant

**Date :** 22 novembre 2026  
**Branche de travail :** `work/naxa-services-completion-20261120`  
**Statut :** conception initiale / non implémentée / non validée  
**Périmètre :** Android NAXA SERVICES uniquement ; le lot Web/PWA N4 reste séparé.

## 1. Objectif et verdict d'entrée

N3 doit permettre à une installation Android de récupérer, après reconnexion, les mutations autorisées réalisées depuis une autre installation, puis de mettre à jour son état local Room sans perte, doublon ni écrasement silencieux.

**Constat :** le push Android vers le serveur existe déjà dans `SupplierSyncCoordinator`. La passerelle SQL `public.ns_apply_sync_event` applique les mutations et émet un reçu idempotent. En revanche, aucun endpoint de pull utilisé par Android ni application des changements distants dans Room n'a été identifié au HEAD audité.

**Verdict N3-B : OUVERT / NON VERT.** Cette note fixe les contraintes de conception avant toute migration candidate ou modification du client.

## 2. État existant observé

### 2.1 Reçu serveur actuel

La table `public.ns_sync_receipts`, créée dans le draft `naxa_services_v3_operations_rewards_sync.sql`, contient notamment :

- organisation, site, poste, appareil et membre ;
- `client_event_id`, `device_sequence`, agrégat et code d'action ;
- `payload_sha256`, statut, `response_json`, dates de réception et d'application.

Elle est protégée par RLS et ses privilèges directs sont réservés au rôle serveur. Elle ne conserve pas le payload métier entrant. Elle sert de reçu d'idempotence et de preuve de mutation, **pas de journal de distribution complet** vers les autres appareils.

### 2.2 Passerelle serveur

La RPC `public.ns_apply_sync_event` :

- dérive le compte, le membre et la session depuis le contexte Auth ;
- vérifie que l'appareil est actif et lié à la session ;
- vérifie les scopes et invariants du handler métier ;
- impose une séquence monotone par appareil ;
- détecte le rejeu identique et rejette un même identifiant avec un contenu divergent ;
- persiste le reçu dans la transaction de la mutation métier.

Le draft v4 est exécuté en CI sur PostgreSQL jetable. Il n'est pas déployé sur un projet NAXA Services hébergé.

### 2.3 Client Android

`NaxaServicesSyncWorker` et `SupplierSyncCoordinator` traitent actuellement la file locale sortante. Le coordinateur vérifie le reçu avant de marquer l'événement local synchronisé. Aucun endpoint `pull` n'est exposé par l'Edge Function Accounting au HEAD audité et aucun applicateur générique n'alimente les projections Room depuis un appareil pair.

## 3. Invariants obligatoires du futur flux entrant

1. **Aucun accès direct du client à `ns_sync_receipts`** : conserver les privilèges serveur-only et exposer uniquement une fonction/Edge Function contrôlée.
2. **Identité dérivée du contexte Auth** : le client ne choisit pas l'identité du membre, le propriétaire de l'appareil ou ses rôles.
3. **Appareil actif lié à la session courante** : un appareil révoqué, une session étrangère ou un compte suspendu ne peut ni tirer ni acquitter des changements.
4. **Filtrage domaine et périmètre côté serveur** : organisation, site, poste, transferts multisites et autorisations de lecture propres au domaine. La seule appartenance à un site ne doit pas être présumée suffisante pour tous les agrégats.
5. **Minimisation des données** : ne jamais diffuser en bloc les payloads bruts des événements à tous les membres d'une organisation. Les clients reçoivent un changement minimisé ou une projection explicitement autorisée.
6. **Curseur stable et paginé** : la pagination ne perd pas un événement validé pendant que le client lit les pages. Les trous et curseurs expirés ont un résultat explicite.
7. **Pas d'écho** : appliquer une projection distante dans Room ne doit pas générer une nouvelle mutation locale dans l'outbox.
8. **Idempotence locale** : le même changement distant appliqué plusieurs fois ne modifie pas deux fois le registre, le stock, les ventes, les paiements ou les agrégats.
9. **Conflits par domaine** : ne jamais écraser automatiquement les faits financiers, ventes, paiements, abonnements ou journaux append-only. Conserver les changements entrants qui rencontrent une mutation locale non acquittée.
10. **Aucune perte** : une erreur réseau, un redémarrage, une pagination partielle ou une expiration ne supprime ni l'outbox locale non acquittée ni les changements distants non appliqués.

## 4. Architecture candidate à instruire

### 4.1 Journal de changements distinct des reçus

Créer un journal serveur dédié, alimenté dans la même transaction que `ns_apply_sync_event`. Le journal doit contenir au minimum :

- un curseur de changement monotone et son organisation ;
- `event_id`, appareil source, date serveur ;
- `site_id`, `workstation_id` si applicables ;
- `aggregate_type`, `aggregate_id`, `action_code` ;
- version d'agrégat et version de projection ;
- une classification d'accès/visibilité explicite et une indication de suppression éventuelle.

Le journal ne doit pas recopier sans contrôle le payload complet de l'outbox. Deux voies sont à comparer avant implémentation :

**Option A — invalidation + relecture typée.** Le pull renvoie l'identité/version de l'agrégat modifié. Le client appelle ensuite une lecture métier authentifiée, qui renvoie uniquement la projection que le membre a le droit de consulter. Cette voie réduit l'exposition de PII mais exige de recenser les lecteurs métier et les projections pour les domaines nécessaires.

**Option B — projection de distribution contrôlée.** Le serveur construit, par action, une projection minimale à partir de l'état métier après mutation, applique les règles de lecture du domaine, puis la place dans le journal. Aucun payload libre fourni par le client n'est distribué tel quel. Cette voie peut réduire les lectures supplémentaires, mais chaque projection doit avoir un schéma versionné et une revue d'accès.

La décision A/B peut être hybride par domaine. Une projection complète n'est jamais autorisée uniquement parce qu'un événement a été accepté en écriture.

### 4.2 Curseur et concurrence

Ne pas utiliser uniquement `received_at` ou un UUID aléatoire comme curseur si les transactions peuvent valider dans un ordre différent de leur allocation : une transaction tardive pourrait être oubliée après que le client a avancé son curseur.

Évaluer un compteur transactionnel par organisation, verrouillé au moment de l'écriture du journal et validé dans la même transaction. Ce mécanisme donne un ordre de commit exploitable, mais sérialise les publications d'une organisation ; la concurrence et le débit doivent donc être mesurés sur PostgreSQL 17 avant d'en retenir l'implémentation.

Le pull doit employer une pagination keyset, un `limit` strict, un curseur opaque signé ou validé côté serveur, et un curseur de reprise renvoyé uniquement après construction d'une page cohérente. Les changements invisibles à un membre doivent faire progresser le curseur sans révéler leurs champs.

### 4.3 RPC / Edge Function

Contrat fonctionnel à préciser avant le SQL final :

- entrée : organisation active, curseur optionnel, taille de page bornée ;
- identité et appareil : dérivés du JWT/session, sans identifiants d'acteur faisant autorité dans le body ;
- sortie : page de changements autorisés, curseur suivant, indicateur `has_more`, état `reset_required` si l'historique demandé n'est plus disponible ;
- erreurs : Auth/device révoqué, organisation inaccessible, curseur invalide/expiré, version de schéma incompatible ;
- aucun accès SELECT direct à la table du journal depuis `authenticated`.

### 4.4 Application Room

Le client doit d'abord enregistrer durablement le changement entrant et son curseur, puis appliquer chaque changement dans une transaction Room. L'acquittement local ne progresse qu'une fois la projection réellement mise à jour ou classée en conflit/revue.

Les changements distants doivent utiliser des méthodes DAO dédiées qui ne déclenchent pas `enqueue()`. Ils ne doivent pas être traités comme des saisies locales nouvelles. Un conflit avec une opération locale encore queued/retry/blocked doit être conservé et rendu visible ; aucune opération locale n'est supprimée ou marquée `synced` à la place de l'autre.

## 5. Tests de sortie requis

### PostgreSQL 17 jetable

- deux appareils distincts du même compte/membre et deux installations de membres autorisés ;
- un événement validé par A est visible par B seulement selon le scope et les permissions du domaine ;
- une mutation sur un autre site, une autre organisation ou un domaine interdit n'expose ni payload ni projection ;
- pagination avec plusieurs pages, transactions concurrentes, redémarrage entre pages et événements validés pendant le pull ;
- curseur rejoué, invalide et expiré ; appareil/session révoqués ;
- aucune lecture directe des reçus/journal par `authenticated` ;
- journal et reçu sont atomiques à la mutation : rollback = aucune diffusion ;
- aucun payload PII libre ni secret dans le flux.

### Room / Android instrumenté

- A crée hors ligne puis pousse ; B récupère et applique sans doublon ;
- B modifie à son tour ; A récupère et applique ;
- redémarrage avant, pendant et après une page ;
- même page rejouée, réponse perdue après application, pagination partielle ;
- changement d'organisation/site et révocation de session/appareil ;
- conflit entre événement distant et mutation locale encore non acquittée ;
- transfert multisite visible aux deux périmètres concernés sans fuite vers les autres ;
- ventes, paiements, caisse et avances restent append-only/contrôlés ;
- aucun événement distant ne repart dans l'outbox sortante.

Un test de fonction serveur isolé ou un test de deux appareils qui ne valide que les reçus de push ne suffit pas. Le gate N3 exige au moins un scénario vertical réellement bidirectionnel, puis l'extension aux 44 mutations indépendantes concernées.

## 6. Points d'arbitrage avant le premier SQL

1. Matrice des domaines : qui peut lire quelle projection pour chaque action/agrégat, notamment RH, CRM, clients, support, caisse, ventes et documents.
2. Portée du flux : notifications d'invalidation seules ou projections minimisées par domaine.
3. Durée de rétention et procédure `reset_required` / rebootstrap pour un appareil longtemps hors connexion.
4. Politique de conflit si un appareil a une version locale en attente pendant qu'un autre publie une version serveur.
5. Mesure de contention du compteur de curseur par organisation.
6. Stratégie des suppressions et changements de scope afin qu'un appareil retire localement les données auxquelles son membre n'a plus accès.

## 7. Garde-fous

- Modifier uniquement la branche `work/naxa-services-completion-20261120`.
- Ajouter les drafts SQL et fonctions candidates au workflow PostgreSQL 17 jetable ; ne jamais les appliquer au Supabase historique NAXA/pharmacie.
- Garder le feature flag Android désactivé par défaut jusqu'à la recette multi-appareils et à l'autorisation explicite de l'environnement dédié.
- Ne pas déclarer N3 vert avant les tests de sortie de la section 5 et leur preuve CI.
- N4 Web/PWA reste hors de ce lot.

**Décision proposée :** instruire d'abord la matrice d'accès et l'option A/B par domaine ; ensuite produire le draft serveur et son test d'isolation avant d'écrire l'applicateur Room.
