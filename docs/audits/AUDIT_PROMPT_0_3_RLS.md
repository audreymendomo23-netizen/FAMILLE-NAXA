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

## Autorisation opérationnelle

Les GitHub Actions et migrations Supabase sont autorisées pour le chantier Famille NAXA. Les Actions CI peuvent être exécutées avec permissions minimales. Les migrations doivent être versionnées, testées en PostgreSQL éphémère puis appliquées au projet Supabase de développement Famille explicitement identifié, après contrôle de son project ID et de son historique.

Les projets visibles dans le compte connecté sont `naxa-ci-replay` (`fnlyjlvflgiewrkmnisi`, INACTIVE), `naxa-ci-replay-2` (`pwfftcsjyeibxxqhwysw`, ACTIVE_HEALTHY) et `Naxa` (`eouwtuusnsuxaejsxknf`, ACTIVE_HEALTHY). Aucun n'est identifié comme projet Supabase de développement dédié à Famille NAXA. Aucun SQL n'a été appliqué à ces projets. Ne pas utiliser Replay ni NAXA historique comme cible par défaut.

## Limites et décision

Le run prouve la validité des scénarios actuellement écrits, pas la sécurité exhaustive des dix applications. Les tables métier et vues agrégées réelles restent à raccorder ; la couverture des rôles, fonctions SECURITY DEFINER, GRANT et des scopes app/organisation/lieu doit être complétée.

**État : PARTIEL — RLS CI validée sur PostgreSQL 17 éphémère ; Prompt 0.3 non VERT.** Ne pas déclarer le chantier vert ni ouvrir 0.4 avant raccordement métier, couverture complète et validation sur le projet Supabase Famille de développement.
