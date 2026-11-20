# PROMPT 0.2 — Schéma de données commun

**État : PROMPT 0.2 CLÔTURÉ POUR LE CADRAGE ET LA CONCEPTION ; AUCUNE MIGRATION AUTORISÉE.**
**Projet consulté : naxa-ci-replay-2 (pwfftcsjyeibxxqhwysw) uniquement. Production non modifiée.**

## 1. Périmètre actualisé

Le prompt historique demandait un socle pour sept applications. Il est actualisé aux dix applications : Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA Hotel, Campus237, NAXA Security et GrillaD.

Le périmètre couvre identité, organisations, lieux, membres, rôles, accès aux applications, appareils, abonnements, paiements, notifications, audit, versions, règles de parsing SMS, support et synchronisation.

## 2. Inventaire Replay observé

Projet en eu-west-1, PostgreSQL 17.11.0.003, ACTIVE_HEALTHY.

| Ressource | Quantité |
|---|---:|
| Tables public | 249 |
| Tables private | 2 |
| Tables RLS activé | 251/251 |
| Policies | 372 (inventaire catalogue relancé le 14/11/2026) |
| Migrations | 575 |
| Fonctions | 516 (inventaire précédent ; nombre à revalider avec la nouvelle extraction) |
| Fonctions SECURITY DEFINER | 447 (requête catalogue relancée le 14/11/2026) |
| SECURITY DEFINER sans search_path explicite | 0 selon le contrôle précédent ; non revalidé dans ce passage |
| Triggers | 194 |
| Index | 827 |
| Vues public/private | 6 |

Dernière migration observée lors du premier inventaire : 20261113224605 payment_reference_lock_before_matching. Les métriques catalogues évoluent : 372 policies et 447 SECURITY DEFINER ont été constatés au contrôle du 14/11/2026.

## 3. Structures candidates repérées

- auth.users : identité d'authentification.
- public.profiles : profil NAXA avec enum de rôles pharmacie (client, pharmacie, promoteur, caisse, admin).
- public.partners, partner_members, partner_universes, universes : structures partenaire/univers.
- public.appareils : appareil lié à utilisateur et pharmacie.
- public.notifications : notification utilisateur/pharmacie.
- public.audit_log et naxa_session_audit : audit.
- public.offline_operations, naxa_offline_operations et private.naxa_offline_lww_config : mode hors ligne.
- public.feature_flags : activation fonctionnelle.

## 4. Contradictions et risques

1. profiles.role ne représente pas les dix métiers ; ne pas étendre cet enum en rôle universel.
2. appareils est lié à pharmacie_id ; pas un registre universel multi-applications.
3. offline_operations est spécifique pharmacie/produit ; ne pas le réutiliser tel quel.
4. notifications comporte un périmètre pharmacie ; concevoir une abstraction multi-apps sans casser NAXA.
5. partners/universes sont réutilisables conceptuellement, mais leur sémantique doit être comparée aux cahiers métier.
6. Les six vues inspectées doivent être examinées individuellement. Les Security Advisors identifient deux vues SECURITY DEFINER : public.marketplace_assureurs et public.marketplace_assurance_conventions.
7. anon dispose de USAGE sur public et private ; private ne doit pas être exposé aux clients. L'exposition d'un schéma et les GRANT de table/fonction doivent être audités séparément.
8. Le contrôle ACL montre des droits de table anon sur plusieurs tables. RLS actif ne suffit pas à prouver la minimisation des privilèges. Le contrôle advisor relève 66 tables avec RLS activé sans aucune policy : cela peut être un choix de refus total, mais doit être confirmé contre les GRANT et usages applicatifs.
9. 447 fonctions SECURITY DEFINER existent au contrôle catalogue du 14/11/2026. Les advisors signalent 3 fonctions exécutables par anon (marketplace_offre_stock_disponible, search_pharmacies, search_pharmacies_bulk) et 233 exécutables par authenticated. EXECUTE n'est pas une preuve de vulnérabilité à lui seul : chacune doit être examinée pour propriétaire, search_path, auth.uid(), autorisation par organisation/lieu, validations d'arguments, effets et exposition intentionnelle.
10. La protection Auth contre les mots de passe compromis est désactivée selon l'advisor du 14/11/2026. Ce réglage relève du projet Supabase et nécessite une décision/configuration distincte.
11. L'existence d'une table ou policy ne prouve pas le fonctionnement métier.

Conclusion : le backend est riche mais spécialisé NAXA. Ne pas dupliquer ses tables, ne pas ajouter immédiatement Famille dans public, ne pas réutiliser aveuglément ses politiques.

## 5. Modèle commun proposé

- Identité partagée via auth.users, sous réserve de confirmation de la politique d'identité commune.
- Schéma famille_core pour les fonctions transverses.
- Schémas métier isolés : kiosko, bootik, zipple, naxa_services, cotiz, loyable, naxa_hotel, campus237, naxa_security, grillad.
- Aucune nouvelle table Famille dans public par défaut.
- Chaque enregistrement métier est rattaché à app_id et, selon le domaine, organization_id et location_id.
- Rôles contextualisés par application, organisation et lieu. Un utilisateur peut avoir plusieurs affectations mais une seule affectation active dans une session de travail donnée.
- Comptes clients et droits d'accès provisionnés par le service d'administration autorisé ; aucune inscription libre.
- Écritures financières et validations critiques contrôlées côté serveur.
- Aucun schéma Famille exposé au Data API avant validation des grants, RLS, policies et vues.

## 6. Modèle conceptuel

auth.users → identities
identities → client_app_access → applications (10)
identities → devices → app_installations
identities → memberships → organizations
organizations → organization_apps → applications
organizations → locations
memberships → role_assignments → role_catalog
famille_core → plans / subscriptions / payment_intents / payment_matches
famille_core → notifications / notification_preferences / audit_events
famille_core → app_versions / payment_parser_rules / support_tickets / sync_receipts
appareils → Room (Android) ou IndexedDB (Web) → sync_queue locale

## 7. Dictionnaire des entités

| Entité | Rôle | Relations |
|---|---|---|
| applications | Registre des dix apps | app_id, code unique |
| identities | Profil commun minimal | user_id → auth.users.id |
| organizations | Structure exploitante | organization_id |
| organization_apps | Apps activées pour organisation | organization_id + app_id |
| locations | Lieux physiques précis | location_id → organization_id |
| memberships | Appartenance à organisation/app | user_id + org_id + app_id |
| role_catalog | Rôles disponibles par app | app_id + role_code |
| role_assignments | Rôle dans un périmètre | membership + app + lieu |
| client_app_access | Autorisation d'un client | user_id + app_id |
| devices | Appareil enregistré | device_id + user_id |
| app_installations | Installation par app/appareil | device_id + app_id |
| plans | Offres par application | plan_id + app_id |
| subscriptions | Abonnement organisation/app | organization_id + app_id |
| payment_intents | Intention de paiement | subscription_id + montant |
| payment_matches | Rapprochement transaction externe | provider + référence UNIQUE |
| promo_codes | Codes promotionnels | code + app_id |
| referrals | Parrainage | referrer + referred + app_id |
| notifications | Notification contextualisée | user_id + app_id |
| notification_preferences | Préférences par canal | user_id + app_id + channel |
| audit_events | Journal append-only | actor + app + cible + heure |
| app_versions | Version et minimum supporté | app_id + platform |
| payment_parser_rules | Règles parser versionnées | app_id + provider + version |
| support_tickets | Support multi-apps | user_id + app_id |
| sync_receipts | Accusé serveur idempotent | device_id + operation_id UNIQUE |

Les commissions partenaires restent propres au modèle commercial de chaque app. Les sauvegardes relèvent de l'infrastructure et de la politique Supabase ; une ligne dans une table ne prouve pas qu'une sauvegarde existe.

## 8. Règles de données

- UUID pour identifiants distribués ; FK, contraintes et index explicites.
- FCFA en entiers ou NUMERIC exact, jamais REAL/FLOAT.
- timestamptz en UTC ; fuseau d'affichage explicite.
- created_at, updated_at, created_by selon pertinence.
- deleted_at pour objets opérationnels lorsque légalement permis ; journaux et écritures append-only.
- Références de paiement uniques selon fournisseur/canal.
- RLS activé et policies testées sur toute table exposée.
- Les policies vérifient identité, application, organisation, lieu et rôle ; authenticated seul ne constitue jamais une autorisation.
- Aucun service_role, secret, PIN, OTP ou SMS brut dans les clients.
- Parsing SMS local ; seuls champs extraits autorisés et preuves minimisées peuvent être transmis.
- sync_queue est locale : operation_id UUID, app_code, aggregate_type/id, action, payload protégé, base_version, device_sequence, created_at, retry_count, next_retry_at, status, last_error_code.
- Le serveur conserve des reçus idempotents, pas une deuxième file cliente globale.
- Aucun LWW universel sur soldes, paiements, stocks ou écritures comptables.

## 9. Audit de sécurité restant

- Grants sur schémas, tables, séquences, fonctions et vues.
- Audit individuel des 441 fonctions SECURITY DEFINER.
- Audit des six vues, sécurité invoker/definer et privilèges.
- Audit des 348 policies : CRUD, rôles, accès croisés, récursion RLS et tests négatifs.
- Storage : buckets, policies, chemins et accès signés.
- Triggers, contraintes, index, extensions, pg_cron et Edge Functions.
- Comparaison Replay/Production et revue des migrations du dépôt.
- Contrôle Data API ; private non exposé.
- Révocation des droits anon non indispensables.


## 9 bis. Résultats du contrôle de sécurité Supabase (14 novembre 2026)

Contrôle en lecture seule sur le projet Replay `pwfftcsjyeibxxqhwysw` (naxa-ci-replay-2), compte Supabase NAXA. Aucun SQL DDL/DML n'a été exécuté.

| Contrôle | Résultat | Lecture correcte |
|---|---:|---|
| Tables public / private | 249 / 2 | Inventaire de ce projet Replay uniquement |
| Policies catalogue | 372 | À rapprocher des tables, rôles, opérations et grants |
| Fonctions SECURITY DEFINER | 447 | Inventaire catalogue ; pas un verdict de vulnérabilité |
| Tables RLS sans policy | 66 | Refus par défaut possible ; vérifier les grants et l'usage attendu |
| Vues SECURITY DEFINER | 2 | À corriger ou justifier après analyse des données exposées |
| Fonctions SECURITY DEFINER exécutables par anon | 3 | Surface RPC publique à examiner en priorité |
| Fonctions SECURITY DEFINER exécutables par authenticated | 233 | Surface RPC authentifiée ; vérifier chaque contrôle d'autorisation |
| Protection mots de passe compromis | Désactivée | Paramètre Auth à décider et activer séparément |

Les trois RPC anon signalées sont :
- `public.marketplace_offre_stock_disponible(p_pharmacie uuid, p_produit uuid)` ;
- `public.search_pharmacies(p_terms text[], p_lat double precision, p_lng double precision, p_rayon_km double precision)` ;
- `public.search_pharmacies_bulk(p_terms text[], p_quantities integer[], p_lat double precision, p_lng double precision, p_rayon_km double precision)`.

Les deux vues signalées sont `public.marketplace_assureurs` et `public.marketplace_assurance_conventions`. Aucun changement n'a été effectué sur ces objets : ce sont des constats pour l'audit NAXA, pas des autorisations de correction.

**Portée :** ce contrôle est limité à Replay. Il ne constitue ni une certification de Production ni une revue exhaustive du code des 447 fonctions et 372 policies. Les findings Supabase Advisor sont des signaux à examiner, pas des preuves automatiques d'exploitation.

## 9 ter. Corrections de conception exigées avant toute migration Famille

Le DDL actuel est un squelette de modèle, pas une migration prête. Avant toute exécution, il faut au minimum :

1. **Correction partielle déjà intégrée au draft** : clés étrangères composites imposant que `role_assignments.membership_id/app_id/organization_id` correspondent au membership et que `location_id` appartienne à la même organisation. Ces contraintes doivent encore être exécutées et testées en PostgreSQL isolé.
2. **Correction partielle déjà intégrée au draft** : `subscriptions` référence une activation `organization_apps(organization_id,app_id)` et un `plans(id,app_id)` de la même application. L'exécution SQL et les tests négatifs restent à faire.
3. Définir le cycle d'invitation, l'acceptation, la révocation, les changements de rôle et les sessions actives ; ne pas confondre membership, compte Auth et rôle.
4. Formaliser les organisations multi-activités et les lieux partagés : une organisation peut exploiter plusieurs apps ; une affectation doit être bornée à l'app et au lieu ; les droits ne se propagent jamais automatiquement entre apps.
5. Définir la politique de comptes personnels et de comptes professionnels, de liaison/déliaison Auth, de récupération, de fermeture et de suppression conformément aux dix cahiers des charges.
6. Séparer les données financières et journaux immuables des données modifiables ; définir les règles de rapprochement, idempotence et prévention de double paiement côté serveur.
7. Ne pas conserver `phone_e164` en double dans `identities` sans source de vérité et politique de synchronisation définies ; limiter les données personnelles au strict nécessaire.
8. Pour `devices` et `app_installations`, définir l'enrôlement, preuve de possession, révocation, rotation des tokens, intégrité Android et séparation des installations par application.
9. Définir une stratégie de synchronisation par domaine. Aucun LWW global ; les soldes, tontines, loyers, réservations, stocks, ventes, paiements, accès et alertes de sécurité nécessitent des transitions métier serveur et une gestion des conflits spécifique.
10. Créer une matrice RLS par table et par opération, avec tests positifs et négatifs inter-utilisateur, inter-organisation, inter-lieu et inter-application. Les policies ne seront pas génériques par simple `auth.uid()`.
11. Définir les rôles serveur d'administration et les procédures SECURITY DEFINER minimales, non exposées par défaut ; aucun droit EXECUTE implicite PUBLIC/anon.
12. Décider explicitement quelles ressources doivent rester dans les schémas privés et lesquelles nécessitent une API serveur. Aucun schéma Famille ne sera exposé au Data API avant cette revue.

## 9 quater. Matrice métier obligatoire

La validation finale exige une matrice, application par application, des entités métier qui restent dans leurs schémas dédiés et des seules fonctions réellement transverses. La présence d'une table générique `organizations` ou `locations` ne remplace pas les modèles spécialisés :

- Kiosko : opérateurs Mobile Money, points de vente, caisses, opérations et rapprochements ;
- Bootik : commerces/dépôts de gaz, produits, variantes, stocks, achats, ventes et caisse ;
- Zipple : bars/restaurants, menus, tables, commandes, service et caisse ;
- NAXA Services : pressing/coiffure, prestations, rendez-vous, production et encaissement ;
- CotiZ : groupes de tontine, membres, cycles, cotisations, tours, prêts et remboursements ;
- Loyable : biens, unités locatives, bailleurs, locataires, contrats, échéances, paiements et interventions ;
- NAXA Hotel : établissements, chambres, tarifs, disponibilités, séjours, réservations et facturation ;
- Campus237 : établissements, années scolaires, classes, élèves, responsables, enseignants, évaluations et frais ;
- NAXA Security : sites, équipements, caméras, passerelles, alertes, preuves, télésurveillance et accès ;
- GrillaD : vendeurs de grillades, lieux précis, managers, vendeurs affectés, stocks/production/ventes/caisse par lieu. Les trois modes validés sont manager autonome sur un lieu, manager + un vendeur, manager + plusieurs vendeurs sur plusieurs lieux. Catalogue limité aux grillades validées.

Cette liste est une grille de couverture initiale, pas un remplacement des cahiers complets. Les cardinalités, statuts, workflows, permissions et contraintes de chaque application doivent être extraits et comparés aux cahiers avant de figer le DDL.

## 10. État du livrable

- Prompt historique 0.2 retrouvé et actualisé de sept à dix applications.
- Audit Replay de premier niveau et contrôle Supabase Security Advisors en lecture seule ; résultats datés du 14/11/2026.
- Modèle conceptuel et dictionnaire proposés.
- Collisions avec le schéma NAXA identifiées.
- SQL draft non appliqué préparé séparément.
- Aucune table créée dans Supabase ; Replay et Production non modifiés.
- Aucun test SQL/RLS Famille exécuté ; aucun audit ligne par ligne des 372 policies ou 447 fonctions achevé.
- Statut : PARTIEL / NON VALIDÉ — modèle proposé et contrôles d'alerte documentés ; audit exhaustif des policies/fonctions, grants, vues, Storage, triggers, extensions, fonctions Edge, comparaison Production et matrice complète des dix cahiers restent ouverts.

## 11. Passation

FICHIER DE PASSATION — Famille NAXA — Prompt 0.2 — 14 novembre 2026

1. Fait : inventaire Replay de premier niveau, modèle commun et dictionnaire.
2. Fichiers : Prompt 0.1, Prompt 0.2 et draft SQL non appliqué.
3. Tables Supabase créées : aucune. Entités conceptuelles proposées : 24 ; DDL draft : 22 tables.
4. Décisions : identité Auth commune ; couche Famille isolée ; rôles contextualisés ; file offline locale.
5. Points ouverts : analyse individuelle des 447 SECURITY DEFINER et 372 policies ; grants, 2 vues SECURITY DEFINER, 66 tables sans policy, Storage, triggers, extensions, Edge Functions ; comparaison Production ; matrice complète des dix cahiers ; tests PostgreSQL du draft durci, contraintes complémentaires, grants et tests RLS.
6. Suite : bootstrap des builds Android/Web, validation PostgreSQL isolée du draft durci, puis audit détaillé des droits, GRANT et tests RLS. Aucun déploiement/migration Supabase.
7. Accord explicite requis pour exposition Data API, grants, migration appliquée, modification Replay/Production, déploiement ou dépense. L'audit courant n'a effectué que des lectures.

**Prompt 0.2 : modèle et cadrage approfondis documentés ; PAS VERT. Le schéma SQL reste un draft non exécutable tant que les invariants, les policies, les grants, les tests et la matrice métier ne sont pas finalisés.**


---

## 12. Clôture du Prompt 0.2 — contrôle consolidé du 14/11/2026

**Décision de clôture : le travail de cadrage et de conception demandé par le Prompt 0.2 est terminé et documenté. Le modèle Famille est retenu comme proposition d'architecture, mais il n'est ni migré ni déclaré prêt pour la production.** Cette clôture ne certifie pas la sécurité globale du backend NAXA.

### 12.1 Inventaire comparatif Replay / Production

Contrôles en lecture seule, effectués le 14/11/2026. Replay = `pwfftcsjyeibxxqhwysw`; Production = `eouwtuusnsuxaejsxknf`.

| Indicateur | Replay | Production | Conclusion |
|---|---:|---:|---|
| Tables public | 249 | 246 | Schémas existants distincts |
| Tables private | 2 | 7 | Ne pas supposer une parité |
| Policies toutes catégories | 372 | 367 | Écart de 5 policies |
| Fonctions SECURITY DEFINER (catalogue interrogé) | 446 | 427 | Écart de 19 ; métrique de catalogue, pas un score de risque |
| Schémas Famille dédiés déjà présents | Aucun | Aucun | Aucun socle Famille n'a été créé |
| Vues public/private identifiées | 6 vues public dans l'inventaire initial | 6 vues public | Les deux vues marketplace signalées ne sont pas en security_invoker |

Les nombres de fonctions peuvent différer d'un relevé Advisor à un relevé SQL selon le périmètre et l'instant d'observation : Advisor avait signalé 447 fonctions SECURITY DEFINER sur Replay. Le relevé SQL consolidé du présent passage en compte 446 dans le périmètre interrogé. Ne pas fusionner ces chiffres en une fausse valeur unique.

Les historiques de migrations Replay et Production ont été consultés : ils ne sont pas identiques. Aucune tentative de synchronisation, de rebase, de migration ou d'écriture n'a été faite. L'inventaire ne prouve pas que les deux bases sont interchangeables.

### 12.2 Contrôles de sécurité Replay

- 372 policies recensées : 347 dans `public`, 23 dans `storage`, 2 dans `cron`.
- Supabase Advisor signale 66 tables avec RLS activé et sans policy. Ce signal n'est pas automatiquement une faille : certaines tables internes peuvent être volontairement inaccessibles aux clients. Il faut néanmoins vérifier les grants et l'usage attendu.
- Le comptage SQL élargi a repéré 92 tables RLS sans policy sur l'ensemble des schémas interrogés, incluant des schémas système/techniques. Ce total n'est pas comparable au seul finding Advisor de 66 tables.
- 446 fonctions SECURITY DEFINER dans le relevé SQL ; aucune sans `search_path` explicite dans ce contrôle.
- Trois fonctions SECURITY DEFINER de `public` sont exécutables par `anon` : `marketplace_offre_stock_disponible`, `search_pharmacies`, `search_pharmacies_bulk`. Leurs définitions ont été lues. Elles exposent des fonctions de recherche et de disponibilité Marketplace, filtrent les pharmacies inactives, démo ou archivées, et imposent une fraîcheur de stock de 48 h pour la première. Ce comportement est cohérent avec une lecture publique du catalogue, mais les fonctions restent des points d'entrée privilégiés : tests de paramètres limites, volumétrie, fuite d'information et abus à effectuer avant certification.
- Les vues `public.marketplace_assureurs` et `public.marketplace_assurance_conventions` ont l'option `security_barrier=true`, mais pas `security_invoker=true`. Elles sont donc à traiter comme vues à privilèges du propriétaire ; leur exposition doit être justifiée par l'examen des définitions et des grants. Aucune correction n'a été faite.
- Le schéma `private` apparaît dans les schémas pour lesquels `anon` dispose de USAGE. C'est un constat de privilège de schéma, pas la preuve d'un accès effectif aux lignes ; les droits de tables, fonctions et vues doivent être minimisés séparément. Ne pas exposer `private` ni les schémas Famille.
- Storage Replay : 9 buckets observés, dont des buckets publics et privés ; 23 policies sur `storage.objects`. Les règles sont fortement orientées pharmacie/partenaires/examens. Elles ne constituent pas une politique de fichiers Famille réutilisable.
- 6 tâches pg_cron actives observées ; 9 extensions installées, dont `pg_cron`, `pgcrypto`, `pg_trgm`, `unaccent`, `http`, `uuid-ossp`, `supabase_vault` et `pg_stat_statements`.
- Deux Edge Functions Replay recensées : `naxa-pharmacy-code` (JWT non requis) et `naxa-e2e-provision` (JWT requis). Ce sont des fonctions NAXA ; aucune fonction Famille n'a été déployée.
- Advisor performance signale 215 clés étrangères sans index couvrant. Ce constat concerne la dette/performance du schéma existant ; aucune correction n'a été entreprise dans ce chantier.
- Advisor sécurité signale la protection contre les mots de passe compromis désactivée. Ce paramètre Auth est à traiter séparément par le propriétaire du projet.

### 12.3 Décision d'architecture arrêtée

1. Les dix applications Famille utilisent une couche transverse dédiée `famille_core`, avec schémas métier séparés pour les dix applications.
2. Aucune table métier Famille ne sera ajoutée à `public` par défaut.
3. `auth.users` peut être le fournisseur d'identité commun ; l'identité de connexion ne confère aucun droit métier par elle-même.
4. `public.profiles`, `partners`, `partner_members`, `universes`, `appareils`, `notifications` et les tables offline NAXA ne sont pas adoptés tels quels comme modèle Famille. Leur sémantique reste propre au produit NAXA.
5. Les permissions sont contextuelles : application + organisation + lieu + rôle + état de l'affectation. Aucun rôle ni accès ne se propage automatiquement d'une application à l'autre.
6. Les données de stock, caisse, tontine, loyer, réservation, séjour, paiement, comptabilité et sécurité physique restent dans leurs domaines métier dédiés ; aucune synchronisation LWW générique n'est autorisée pour ces agrégats.
7. Les 24 entités du dictionnaire sont le modèle conceptuel. Le fichier SQL contient 22 tables de base : `promo_codes` et `referrals` restent au niveau conceptuel, car leurs règles métier et cycles de vie ne sont pas suffisamment définis pour figer leur DDL sans inventer des règles.
8. Le SQL dans `supabase/drafts/0001_famille_core_proposed.sql` reste un brouillon de structure : il active RLS, intègre désormais plusieurs contraintes composites app/organisation, mais ne contient ni GRANT ni policy. Il n'a pas été exécuté ni validé syntaxiquement par PostgreSQL ; il n'est pas approuvé pour migration et ne doit pas être appliqué.

### 12.4 Limites exactes — ne pas transformer la clôture du prompt en faux « vert »

Les opérations suivantes n'ont pas été faites : audit manuel exhaustif de chaque définition des 446/447 fonctions SECURITY DEFINER, analyse sémantique et tests d'intrusion des 372 policies, tests d'accès avec identités réelles, audit exhaustif des grants objet par objet, revue complète des définitions de toutes les vues, audit ligne par ligne des 194 triggers, revue de chaque migration, test de chaque bucket/fichier, test de toutes les Edge Functions, test de charge et validation des workflows des dix applications contre leurs cahiers complets. Ces travaux dépassent ce qui peut être prouvé par un inventaire catalogue en lecture seule.

La comparaison Production/Replay a porté sur les inventaires et migrations consultés ; elle n'est pas un diff exhaustif de chaque objet et de chaque donnée.

**Critère de clôture du Prompt 0.2 : ATTEINT pour le cadrage, le modèle conceptuel, les frontières de schémas, la comparaison d'inventaire et la décision de non-réutilisation aveugle. NON ATTEINT pour l'autorisation de migration, l'exposition Data API, la certification de sécurité et la mise en production.**

Aucune action destructive ou mutante n'a été réalisée sur Replay ou Production. Aucun SQL Famille n'a été exécuté. Aucun déploiement, publication ou dépense.

## 13. Conclusion du prompt

Le socle commun proposé est suffisamment défini pour servir de référence aux prompts de conception métier suivants, sans démarrer prématurément les applications ni créer de tables. Le schéma SQL reste un artefact de conception à durcir avant toute migration. Le Prompt 0.2 est clos comme livrable de cadrage ; il ne doit pas être rouvert pour élargir le périmètre. Toute future action sur Supabase doit rester un chantier distinct, avec autorisation explicite et preuves propres.


## 14. Preuve technique consolidée — 14 novembre 2026

**État révisé : PROMPT 0.2 — VERT TECHNIQUE POUR LE MODÈLE COMMUN ET LE DRAFT SQL ISOLÉ.**

Le workflow GitHub Actions [43563686065](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43563686065), sur le commit `52d5b2b2b52d4eae59521091e85812ceda39e39c`, a exécuté avec succès sous PostgreSQL 17 éphémère :
- création du schéma candidat et de ses 22 tables ;
- insertion des 10 applications attendues ;
- scénario positif de membership, rôle et lieu cohérents ;
- rejet d'une affectation de rôle sur une autre application ;
- rejet d'un lieu appartenant à une autre organisation ;
- rejet d'un abonnement utilisant un plan d'une autre application ;
- vérification de RLS activé et de l'absence de GRANT/policies dans le draft (default-deny).

Cette preuve remplace les mentions antérieures « SQL non exécuté / non validé syntaxiquement » pour le draft exact testé. Elle ne vaut que pour le script et les assertions du test éphémère.

**Limites maintenues sans ambiguïté :** le schéma n'est pas migré dans Supabase ; aucune policy RLS fonctionnelle ni aucun GRANT applicatif n'est livré ; l'exposition Data API, l'Auth lifecycle complet, les workflows métier détaillés et la certification sécurité restent hors de cette validation. Le draft demeure non autorisé à la migration et ne doit pas être appliqué à Replay ou Production sans chantier et autorisation distincts.
