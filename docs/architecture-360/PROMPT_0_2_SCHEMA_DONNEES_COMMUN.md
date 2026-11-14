# PROMPT 0.2 — Schéma de données commun

**État : AUDIT INITIAL RÉALISÉ ; MODÈLE PROPOSÉ ; SQL DRAFT NON APPLIQUÉ.**
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
| Policies | 348 (347 public + 1 private) |
| Migrations | 575 |
| Fonctions | 516 |
| Fonctions SECURITY DEFINER | 441 |
| SECURITY DEFINER sans search_path explicite | 0 selon contrôle effectué |
| Triggers | 194 |
| Index | 827 |
| Vues public/private | 6 |

Dernière migration observée : 20261113224605 payment_reference_lock_before_matching.

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
6. Les six vues inspectées ne déclarent pas security_invoker=true dans le contrôle effectué ; examiner chacune et ses grants.
7. anon dispose de USAGE sur public et private ; private ne doit pas être exposé aux clients.
8. Le contrôle ACL montre des droits de table anon sur plusieurs tables. RLS actif ne suffit pas à prouver la minimisation des privilèges.
9. 441 fonctions SECURITY DEFINER existent. Le search_path est explicitement défini selon le contrôle, mais propriétaires, EXECUTE, auth.uid(), contrôles de périmètre et effets doivent être audités.
10. L'existence d'une table ou policy ne prouve pas le fonctionnement métier.

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

## 10. État du livrable

- Prompt historique 0.2 retrouvé et actualisé de sept à dix applications.
- Audit Replay de premier niveau en lecture seule.
- Modèle conceptuel et dictionnaire proposés.
- Collisions avec le schéma NAXA identifiées.
- SQL draft non appliqué préparé séparément.
- Aucune table créée dans Supabase ; Replay et Production non modifiés.
- Aucun test SQL/RLS exécuté.
- Statut : PARTIEL — modèle proposé, audit sécurité et cartographie métier incomplets.

## 11. Passation

FICHIER DE PASSATION — Famille NAXA — Prompt 0.2 — 14 novembre 2026

1. Fait : inventaire Replay de premier niveau, modèle commun et dictionnaire.
2. Fichiers : Prompt 0.1, Prompt 0.2 et draft SQL non appliqué.
3. Tables Supabase créées : aucune. Entités proposées : 23.
4. Décisions : identité Auth commune ; couche Famille isolée ; rôles contextualisés ; file offline locale.
5. Points ouverts : revue SECURITY DEFINER, policies, vues, grants, Storage ; cartographie des dix cahiers ; validation des schémas exposés.
6. Suite : audit détaillé des droits et finalisation des migrations SQL draft non appliquées.
7. Accord explicite requis pour exposition Data API, grants, migration appliquée, modification Replay/Production, déploiement ou dépense.

**Prompt 0.2 : audit initial et modèle proposés ; validation finale suspendue jusqu'à fermeture des points de sécurité et de périmètre.**
