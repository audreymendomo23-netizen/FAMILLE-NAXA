# PROMPT 0.3 — Sécurité des données et règles RLS

Source : `Projet.zip` → `Nouveau projet/Prompt/Prompts_00_Socle_commun.pdf`, page 6. Le texte historique vise 7 apps Android ; le périmètre actuel prévaut : 10 applications, chacune Android native + Web responsive/PWA.

Mission : point de vente limité à ses lignes ; compte mère à tous ses points ; gérant à ses lieux assignés et jamais à un autre propriétaire ; admin voit abonnements/agrégats mais aucune transaction détaillée ; commercial/partenaire sans transaction ; blocage métier au-delà de la tolérance ; paiement et « J'ai payé » accessibles ; helpers `is_admin()`, `outlet_ids()` et tests SQL locaux.

Sémantique : `locations.id` est le point ; `owner` = portée organisation sans lieu ; `manager` = portée lieu ; `platform_admin` exclu des détails ; capacités inconnues refusées ; `grace_until` est fourni par le workflow de facturation, sans inventer une durée ; `submit_payment_intent()` passe à submitted, jamais confirmed ; `payment_matches` non lisible par les clients.

Livrables : migration candidate 0002, bootstrap/test PostgreSQL, runner local, textes FR/EN et passation.

## Politique d'exécution — autorisation explicite du chantier

Les GitHub Actions, les workflows CI, les migrations Supabase versionnées et leur exécution font partie du travail normal de Famille NAXA. Ils ne sont pas interdits par défaut.

- Exécuter les GitHub Actions nécessaires aux tests, builds, contrôles de sécurité et validations de migrations. Les permissions de jeton doivent rester minimales et limitées au besoin réel du workflow.
- Exécuter d'abord les migrations sur PostgreSQL éphémère/local, puis sur le projet Supabase de développement explicitement identifié pour Famille NAXA, après vérification du project ID, de l'état et de l'historique des migrations.
- Ne jamais appliquer une migration Famille NAXA à Replay, à NAXA historique ou à Production par simple proximité de nom ou disponibilité des identifiants.
- Une migration Production exige une validation distincte de la cible, du diff, des risques et du plan de retour arrière. Aucun déploiement applicatif Production n'est implicite.
- Ne pas prétendre qu'une migration réelle a été appliquée si seule la base éphémère CI a été utilisée.
- Documenter chaque exécution : projet ciblé, nom/version de migration, résultat, contrôles post-migration et limites.

## État technique au 14 novembre 2026

- Le run GitHub Actions `43545105030` confirme le succès des deux jobs PostgreSQL 17 : draft 0001, migration candidate RLS 0002 et assertions RLS/facturation.
- Le job d'inventaire échoue car les 20 manifests attendus sont absents : 10 `apps/android/<app>/build.gradle.kts` et 10 `apps/web/<app>/package.json`.
- La migration 0002 est exécutée uniquement dans une base PostgreSQL éphémère CI ; aucune base Supabase réelle n'a été modifiée.
- Les tables métier, transactions, vues agrégées et permissions propres aux dix applications restent à raccorder et à tester.

## Critères de validation

Le succès du job RLS valide les scénarios actuellement écrits, pas l'ensemble du système. Avant VERT : vérifier la couverture de toutes les tables et fonctions, les GRANT, les rôles et utilisateurs sans membership, les accès inter-organisation/app/lieu, les opérations SELECT/INSERT/UPDATE/DELETE, les chemins SECURITY DEFINER, les paiements et les agrégats ; raccorder les vraies tables métier des dix applications ; exécuter les migrations sur le projet Supabase Famille de développement identifié et contrôler les advisors.

Ne pas ouvrir le Prompt 0.4 avant clôture des critères du Prompt 0.3 et preuve de continuité.
