# AUDIT — PROMPT 0.3 — RLS

Date : 14 novembre 2026. Dépôt `audreymendomo23-netizen/FAMILLE-NAXA`, branche `main`.

## Résultat prouvé

- Migration candidate 0002, helpers, policies du socle, GRANT minimaux, action de paiement idempotente, bootstrap et assertions SQL présents.
- Run GitHub Actions [43545105030](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43545105030) : job « SQL draft + contraintes + isolation par défaut » SUCCESS ; job « Prompt 0.3 — policies RLS et scénarios d'isolation » SUCCESS.
- Le job RLS a exécuté le draft 0001, la migration candidate RLS 0002 et les assertions sur PostgreSQL 17 éphémère.
- Tests couverts : compte mère, gérant affecté, isolation d'un autre propriétaire, admin sans détail transactionnel, commercial/partenaire, fenêtre de grâce, blocage SELECT/INSERT/UPDATE/DELETE après expiration, soumission de paiement et confidentialité de `payment_matches`.
- Le runner shell avait passé `bash -n`.

## Échec restant — applications

Le job « Inventaire des 20 applications (preuve de build requise) » FAILURE. Logs : 20 manifests absents, soit les 10 fichiers `apps/android/<app>/build.gradle.kts` et les 10 fichiers `apps/web/<app>/package.json` pour Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA Hotel, Campus237, NAXA Security et GrillaD. Aucun build des 20 applications n'a donc été exécuté.

## Décision de backend à respecter

Les dix applications partagent un même backend. Le choix initial explicite retrouvé dans les échanges du 13 novembre 2026 est le partage direct du projet Supabase NAXA existant. Le dépôt Famille indépendant ne signifie pas que les applications doivent disposer de backends distincts ni qu'un projet Supabase dédié doit être créé automatiquement.

Les données doivent être isolées logiquement par application, organisation/propriétaire, lieu, rôle et affectation. Le schéma `famille_core` et les migrations 0001/0002 restent des candidats à comparer et intégrer au backend commun ; ils ne sont pas encore appliqués à un projet Supabase réel.

## État des projets Supabase et précautions

Les projets visibles dans le compte connecté sont `naxa-ci-replay` (`fnlyjlvflgiewrkmnisi`, INACTIVE), `naxa-ci-replay-2` (`pwfftcsjyeibxxqhwysw`, ACTIVE_HEALTHY) et `Naxa` (`eouwtuusnsuxaejsxknf`, ACTIVE_HEALTHY). Le projet `Naxa` est le backend historique désigné par le choix initial de partage ; sa compatibilité doit être auditée en lecture seule avant toute proposition de migration. Les projets Replay ne deviennent pas la cible du backend commun par défaut.

Aucune migration Famille 0001/0002 n'a été appliquée à un projet Supabase réel. Avant toute écriture, vérifier l'historique des migrations, les schémas, tables, fonctions, policies RLS, GRANT, extensions, dépendances, collisions et risques de régression ; préparer un diff additif, les tests et le plan de retour arrière ; obtenir une validation explicite.

## Limites et décision

Le run prouve la validité des scénarios actuellement écrits, pas la sécurité exhaustive des dix applications. Les tables métier et vues agrégées réelles restent à raccorder ; la couverture des rôles, fonctions SECURITY DEFINER, GRANT et des scopes app/organisation/lieu doit être complétée.

**État : PARTIEL — RLS CI validée sur PostgreSQL 17 éphémère ; Prompt 0.3 non VERT.** Ne pas déclarer le chantier vert ni ouvrir 0.4 avant raccordement métier, couverture complète et audit de compatibilité avec le backend Supabase NAXA partagé.


## Addendum — impact de l'audit du backend commun (14 novembre 2026)

Le projet cible partagé est Supabase NAXA eouwtuusnsuxaejsxknf (PostgreSQL 17.11). Le schéma famille_core n'y existe pas. Aucune migration Famille n'a été appliquée au projet réel.

Le Prompt 0.3 reste PARTIEL et doit être corrigé avant VERT :
- la migration 0002 n'est pas compatible en l'état : outlet_ids() et has_organization_access() ignorent app_id ; is_admin() est global ;
- les helpers SECURITY DEFINER sont tous rendus exécutables à authenticated par un GRANT global, au lieu d'une liste blanche ;
- le modèle générique risque de dupliquer auth.users/profiles, partners, pharmacies, memberships et affectations existantes ;
- les rôles génériques doivent être remplacés/complétés par une matrice métier propre aux dix apps ;
- 0001 reste un draft hors migrations, alors que 0002 en dépend : produire une séquence additive autonome ;
- les tests actuels ne couvrent pas encore ces risques sur les tables et fonctions réelles.

Le rapport docs/audits/AUDIT_COMPATIBILITE_BACKEND_COMMUN.md consigne les mesures, advisors et limites. Verdict : backend partagé confirmé, intégration du DDL 0001/0002 refusée en l'état, refonte additive et tests éphémères requis. Aucun DDL/DML ni changement de configuration Supabase n'a été effectué.
