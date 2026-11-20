# PROMPT 0.3 — Sécurité des données et règles RLS

Source : `Projet.zip` → `Nouveau projet/Prompt/Prompts_00_Socle_commun.pdf`, page 6. Le texte historique vise 7 apps Android ; le périmètre actuel prévaut : 10 applications, chacune Android native + Web responsive/PWA.

Mission : point de vente limité à ses lignes ; compte mère à tous ses points ; gérant à ses lieux assignés et jamais à un autre propriétaire ; admin voit abonnements/agrégats mais aucune transaction détaillée ; commercial/partenaire sans transaction ; blocage métier au-delà de la tolérance ; paiement et « J'ai payé » accessibles ; helpers `is_admin()`, `outlet_ids()` et tests SQL locaux.

Sémantique : `locations.id` est le point ; `owner` = portée organisation sans lieu ; `manager` = portée lieu ; `platform_admin` exclu des détails ; capacités inconnues refusées ; `grace_until` est fourni par le workflow de facturation, sans inventer une durée ; `submit_payment_intent()` passe à submitted, jamais confirmed ; `payment_matches` non lisible par les clients.

Livrables : migration candidate 0002, bootstrap/test PostgreSQL, runner local, textes FR/EN et passation.

## Décision structurante — backend commun

Les dix applications partagent un même backend. Le choix initial explicite retrouvé dans les échanges du 13 novembre 2026 est le partage direct du projet Supabase NAXA existant. Le dépôt Famille est indépendant, mais le backend ne doit pas être dupliqué par application ni remplacé automatiquement par un nouveau projet. Les données et autorisations sont isolées logiquement par application, organisation/propriétaire, lieu, rôle et affectation.

Le schéma `famille_core` et les migrations 0001/0002 sont des candidats d'intégration au backend commun, pas la preuve d'une décision de créer un projet Supabase séparé.

## Politique d'exécution

Les GitHub Actions, les workflows CI, les migrations Supabase versionnées et leur exécution font partie du travail normal de Famille NAXA. Ils ne sont pas interdits par défaut.

- Exécuter les GitHub Actions nécessaires aux tests, builds, contrôles de sécurité et validations de migrations. Les permissions de jeton doivent rester minimales et limitées au besoin réel du workflow.
- Exécuter d'abord les migrations sur PostgreSQL éphémère/local.
- Avant toute exécution sur Supabase réel, auditer en lecture seule le projet NAXA partagé : project ID, historique des migrations, schémas, tables, fonctions, RLS, GRANT, extensions, dépendances, collisions et risques de régression pour NAXA historique.
- Après cet audit, proposer un diff d'intégration additif, les risques, les tests et le plan de retour arrière ; demander validation explicite avant toute écriture réelle.
- Ne jamais appliquer une migration Famille à un projet Replay, à un nouveau projet ou à Production par simple proximité de nom ou disponibilité des identifiants.
- Ne pas prétendre qu'une migration réelle a été appliquée si seule la base éphémère CI a été utilisée.
- Documenter chaque exécution : projet ciblé, nom/version de migration, résultat, contrôles post-migration et limites.

## État technique au 14 novembre 2026

- Le run GitHub Actions `43545105030` confirme le succès des deux jobs PostgreSQL 17 : draft 0001, migration candidate RLS 0002 et assertions RLS/facturation.
- Le job d'inventaire échoue car les 20 manifests attendus sont absents : 10 `apps/android/<app>/build.gradle.kts` et 10 `apps/web/<app>/package.json`.
- La migration 0002 est exécutée uniquement dans une base PostgreSQL éphémère CI ; aucune base Supabase réelle n'a été modifiée.
- Les tables métier, transactions, vues agrégées et permissions propres aux dix applications restent à raccorder et à tester.
- La compatibilité de `famille_core` avec le backend Supabase NAXA partagé reste à auditer.

## Critères de validation

Le succès du job RLS valide les scénarios actuellement écrits, pas l'ensemble du système. Avant VERT : vérifier la couverture de toutes les tables et fonctions, les GRANT, les rôles et utilisateurs sans membership, les accès inter-organisation/app/lieu, les opérations SELECT/INSERT/UPDATE/DELETE, les chemins SECURITY DEFINER, les paiements et les agrégats ; raccorder les vraies tables métier des dix applications ; réaliser l'audit de compatibilité avec le backend commun et faire valider toute migration réelle avant exécution.

Ne pas ouvrir le Prompt 0.4 avant clôture des critères du Prompt 0.3 et preuve de continuité.


## Addendum obligatoire — intégration au backend Supabase commun NAXA

L'audit de compatibilité du 14 novembre 2026 confirme que les dix applications partagent le projet Supabase NAXA existant (eouwtuusnsuxaejsxknf). Ne pas créer un backend dédié Famille et ne pas appliquer les migrations candidates 0001/0002 en l'état.

Avant tout DDL réel, le travail du Prompt 0.3 doit :
1. conserver auth.users comme identité canonique ;
2. produire la matrice de correspondance entre le modèle Famille et profiles, partners, partner_members, pharmacies, promoteur_pharmacies et naxa_professional_assignments ;
3. supprimer les duplications de source de vérité ou les convertir en références/mappings explicites ;
4. rendre chaque helper RLS dépendant du contexte app_id, organisation et lieu pertinent ; aucun helper de scope ne doit retourner des droits inter-applications ;
5. définir les rôles et capacités métier application par application, sans généraliser le rôle NAXA historique ;
6. remplacer tout GRANT EXECUTE global par une liste blanche de RPC ; les helpers SECURITY DEFINER restent non appelables directement par les clients ;
7. couvrir les opérations et workflows de création, invitation, affectation, suspension, révocation, appareils, abonnements et paiements ;
8. tester les refus inter-utilisateur, inter-app, inter-organisation et inter-lieu sur PostgreSQL 17 éphémère ;
9. générer une séquence de migrations additive autonome, sans dépendre d'un draft hors du répertoire migrations.

La migration candidate 0002 présente actuellement un risque de portée inter-applications dans outlet_ids() et has_organization_access(), et is_admin() est global sans contexte app. Ces fonctions doivent être corrigées avant toute validation. Aucune migration Supabase réelle n'est autorisée par cet addendum ; la revue du diff et la validation explicite restent obligatoires.

## État de clôture — mise à jour du 14 novembre 2026

Le Prompt 0.3 reste **PARTIEL / NON VERT**. L'audit de compatibilité du backend partagé est clôturé, mais la migration candidate 0002 ne satisfait pas encore les exigences d'isolation : outlet_ids() et has_organization_access() doivent être contextualisés par app_id ; is_admin() doit avoir une sémantique de portée explicite ; les EXECUTE doivent être contrôlés par une liste blanche justifiée ; le modèle doit éviter la duplication d'identités/organisations/lieux du backend NAXA. Les tests PostgreSQL éphémères existants ne couvrent pas encore ces constats.

Ne pas appliquer 0001/0002 au Supabase réel. Le Prompt 0.4 ne doit pas être ouvert tant que ces défauts ne sont pas corrigés et testés. Son contenu officiel n'est pas présent dans le dépôt consulté ; retrouver le PDF/ZIP source avant de définir son périmètre.


## Revue consolidée — 14 novembre 2026, après contrôle du backend partagé

La candidate Famille 0003 a été renforcée : `outlet_ids()` exige maintenant une application active, un lien organisation/app actif et un abonnement actif ou dans sa tolérance ; `has_organization_access()` ne confère plus une portée organisation à un rôle limité à un lieu et exige aussi un abonnement autorisé. Les tests ajoutés simulent le claim signé pour la matrice de droits après contextualisation.

Le contrôle en lecture seule du projet Supabase NAXA Production confirme que les ressources canoniques à préserver sont `auth.users`, `public.profiles`, `partners`, `partner_members`, `pharmacies`, `promoteur_pharmacies`, `naxa_professional_assignments`, `abonnements`, `abonnement_paiements`, `ventes` et `stocks`. La correspondance et les contradictions détaillées sont documentées dans [PROMPT_0_3_COMPATIBILITE_BACKEND_NAXA.md](../audits/PROMPT_0_3_COMPATIBILITE_BACKEND_NAXA.md).

**Blocage confirmé :** la policy existante `public.ventes_scope` permet `is_admin() OR can_access_pharmacy(pharmacie_id)`, donc l'Admin NAXA peut lire des ventes détaillées. Les helpers NAXA observés n'utilisent pas de contexte `active_app_id` Famille. Il faut arbitrer la séparation Admin NAXA / Admin Famille et raccorder les tables métier des dix domaines avant de déclarer le Prompt 0.3 vert. Les candidates `famille_core` restent un banc de test et ne doivent pas être appliquées au projet réel en l'état.

Aucune écriture n'a été faite sur Supabase NAXA Production. Le statut global reste **PARTIEL / NON VERT** tant que les points de compatibilité ci-dessus ne sont pas levés et testés.

## Résultat d'exécution — 14 novembre 2026, 05:07 UTC

Local RLS gate: PASS. Le workflow dédié https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43559938233 est SUCCESS sur PostgreSQL 17 éphémère. Il a appliqué 0001, 0002 puis la candidate contextualisée 0003, et exécuté avec succès les deux suites : claims signés/refus par défaut, puis matrice complète après durcissement.

Scénarios confirmés par ce run : propriétaire/compte mère, gérant limité à son lieu, autre propriétaire, Admin agrégats sans détail, commercial, partenaire, abonnement expiré et accès de facturation conservé, isolation Kiosko/Campus237, claim absent et claim malformé. Les helpers internes non accordés aux clients restent non appelables directement ; les assertions testent les points d'entrée réellement accordés.

Interprétation exacte : le noyau RLS Famille en environnement éphémère est validé. Le Prompt 0.3 global reste PARTIEL / NON VERT, car le run ne prouve ni l'émission réelle du claim par un Auth Hook, ni le raccordement aux tables métier des dix applications, ni la compatibilité additive avec le backend NAXA partagé. Les fichiers 0001/0002/0003 ne sont toujours pas appliqués à Supabase Production. Voir le rapport ../audits/PROMPT_0_3_COMPATIBILITE_BACKEND_NAXA.md.


Note de cohérence : cette mise à jour remplace les mentions antérieures selon lesquelles les scénarios contextualisés n'étaient pas encore testés. La migration 0002 seule reste insuffisante ; l'enchaînement 0001 + 0002 + candidate 0003 est désormais validé en test PostgreSQL 17 éphémère par le run 43559938233. Le statut global du prompt reste partiel pour les raisons d'intégration listées ci-dessus.
