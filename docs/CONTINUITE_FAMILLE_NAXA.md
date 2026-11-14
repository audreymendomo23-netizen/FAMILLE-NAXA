# CONTINUITÉ — FAMILLE NAXA

14 novembre 2026 — dépôt `audreymendomo23-netizen/FAMILLE-NAXA`, branche `main`.

## Décision d'architecture de référence — backend commun

Décision utilisateur retrouvée dans les échanges du 13 novembre 2026 :
- Les dix applications de Famille NAXA partagent **un même backend**.
- Le choix initial explicite était le **partage direct du projet Supabase NAXA existant** ; GitHub héberge les dix applications dans un dépôt Famille indépendant.
- Famille NAXA reste un ensemble de dix produits distinct du produit NAXA historique, mais cela ne signifie pas dix backends ni la création automatique d'un nouveau projet Supabase.
- L'isolation est logique et obligatoire : application, organisation/propriétaire, lieu/point de vente, rôle, affectation et données métier. Une application ou un lieu ne doit jamais accéder aux données d'un autre périmètre sans autorisation explicite.
- Le schéma `famille_core` et les migrations 0001/0002 sont des propositions techniques candidates pour ce backend commun. Ils ne constituent pas une décision de créer un projet Supabase physique dédié.
- Avant toute migration réelle, auditer le projet Supabase NAXA existant : schémas, tables, fonctions, migrations appliquées, RLS, rôles/GRANT, extensions, collisions de noms, dépendances et risques de régression pour NAXA historique. Déterminer ensuite comment intégrer Famille dans le backend commun sans casser l'existant.
- Aucun projet Supabase réel n'a été modifié par les migrations Famille 0001/0002 à la date de cette mise à jour. Aucune migration ne doit être appliquée avant l'audit de compatibilité et la validation de la cible et du diff.

## État des prompts

- Prompt 0.1 : architecture cadrée ; VERT technique non acquis (20 applications non compilées).
- Prompt 0.2 : schéma commun documenté ; draft 0001 exécuté dans PostgreSQL 17 éphémère ; VERT technique complet non acquis.
- Prompt 0.3 : migration candidate 0002, helpers RLS, policies core, GRANT minimaux et assertions exécutés avec succès sur PostgreSQL 17 éphémère au run GitHub Actions `43545105030`. Job SQL 0.2 SUCCESS et job RLS 0.3 SUCCESS.
- Échec restant du run : inventaire des 20 applications FAILURE ; les 10 manifests Android et 10 manifests Web/PWA sont absents. Aucun build applicatif n'a été exécuté.
- Prompt 0.3 reste PARTIEL : les vraies tables métier, vues agrégées et fonctions des dix applications ne sont pas encore raccordées ni couvertes ; compatibilité avec le Supabase NAXA partagé non auditée.

## Règle opérationnelle

Les GitHub Actions et les migrations Supabase sont autorisées et doivent être utilisées lorsqu'elles sont nécessaires au chantier. Les workflows CI conservent les permissions minimales. Les migrations sont testées d'abord en base éphémère. Leur application au backend Supabase commun exige au préalable l'audit de compatibilité, l'identification certaine du projet NAXA partagé, la revue du diff et des risques de régression, puis une validation explicite de l'exécution réelle. Ne jamais considérer un projet Replay ou un projet nouvellement créé comme cible par défaut.

Projets Supabase actuellement visibles dans le compte connecté :
- `naxa-ci-replay` — `fnlyjlvflgiewrkmnisi` — INACTIVE.
- `naxa-ci-replay-2` — `pwfftcsjyeibxxqhwysw` — ACTIVE_HEALTHY.
- `Naxa` — `eouwtuusnsuxaejsxknf` — ACTIVE_HEALTHY.

Le projet `Naxa` — `eouwtuusnsuxaejsxknf` — est le backend NAXA historique mentionné dans la décision initiale de partage ; son adéquation à Famille doit être vérifiée avant toute écriture. Les deux projets Replay sont des environnements de test, pas le backend partagé par défaut. Aucun projet n'a été modifié par les migrations Famille 0001/0002.

## Décisions d'architecture conservées

10 applications : Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA Hotel, Campus237, NAXA Security et GrillaD. Chacune dispose d'une application Android native Kotlin/Compose, d'une application Web responsive et d'une PWA autonome ; pas de wrapper WebView/Capacitor ; APK distribuées depuis le site NAXA, pas Play Store. Un backend commun ; séparation logique stricte des données et autorisations par application, organisation, lieu, rôle et affectation ; aucun `service_role` dans les clients.

## Preuves et liens

- [Run GitHub Actions 43545105030](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43545105030)
- [Workflow groupé](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/.github/workflows/famille-technical-gate.yml)
- [Migration candidate RLS 0002](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/supabase/migrations/0002_famille_core_rls.sql)
- [Tests RLS SQL](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/supabase/local-tests/0002_prompt_0_3_rls_assertions.sql)

## Point de reprise exact

1. Auditer en lecture seule le backend Supabase NAXA partagé : historique des migrations, schémas, tables, vues, fonctions, RLS, GRANT, extensions, dépendances et risques de collision/régression.
2. Comparer le modèle Famille `famille_core` à l'existant et définir une intégration additive, sans duplication ni rupture du produit NAXA historique.
3. Compléter les tests RLS positifs/négatifs, GRANT, SECURITY DEFINER, absence de membership et isolation app/organisation/lieu sur les tables et fonctions réelles.
4. Après audit et validation explicite, appliquer les migrations compatibles au backend commun, puis vérifier les advisors et les parcours.
5. Créer les 20 manifests applicatifs natifs/Web-PWA et remplacer l'inventaire simple par de vrais builds.
6. À chaque réponse qui modifie une décision, un état, une preuve ou un point de reprise, actualiser ce document de continuité et les documents techniques concernés avant de conclure. Ne pas ouvrir 0.4 avant clôture du Prompt 0.3.

## Audit de compatibilité du backend commun — checkpoint 14 novembre 2026, 03:26 (lecture seule)

Projet audité : Supabase `Naxa`, project ID `eouwtuusnsuxaejsxknf`, organisation `unuefguzgsohvietmvmq`, région `eu-west-1`, statut `ACTIVE_HEALTHY`, PostgreSQL `17.11.0.002`.

Constats obtenus par requêtes SELECT et outils d'inventaire uniquement :
- Le schéma `famille_core` n'existe pas actuellement dans ce projet.
- Inventaire : 246 tables `public`, 7 `private`, 2 `cron`, 2 `net`, plus les schémas système Supabase ; 305 tables au total dans les schémas non système listés par PostgreSQL.
- RLS activé sur 281/305 tables, forcé sur 19. Aucune table sans RLS détectée dans `public` et `bi` lors de la requête ciblée.
- 367 policies recensées sur `public`, `cron` et `storage`.
- 680 fonctions recensées hors schémas système, dont 428 SECURITY DEFINER ; 344 fonctions SECURITY DEFINER dans `public`. Ce volume impose une revue ciblée des droits EXECUTE, du search_path et des contrôles auth.uid() avant d'introduire de nouvelles fonctions.
- 11 vues/vues matérialisées recensées. Leur mode d'exécution et les droits d'accès doivent être vérifiés individuellement, en particulier les vues BI et les façades publiques.
- 541 entrées d'historique de migrations, de `20261004030744` à `20261114004001`. L'historique est très dense ; les migrations Famille 0001/0002 ne figurent pas dans ce constat et ne sont pas appliquées.
- Extensions observées : http 1.6, pg_cron 1.6.4, pg_net 0.20.4, pg_stat_statements 1.11, pg_trgm 1.6, pgcrypto 1.3, plpgsql 1.0, supabase_vault 0.3.1, unaccent 1.1, uuid-ossp 1.1.
- L'inventaire des advisors a signalé de nombreuses policies permissives multiples et au moins un index dupliqué sur `public.stocks_lots`. Ces constats doivent être triés et rapprochés des audits NAXA existants ; ils ne sont pas des défauts Famille introduits par cet audit.

## Conclusion provisoire de compatibilité

Le backend commun est techniquement identifiable et possède déjà un vaste modèle métier NAXA. L'absence de `famille_core` évite une collision immédiate de schéma, mais ne prouve pas encore que la migration candidate est compatible : ses dépendances, fonctions SECURITY DEFINER, rôles/GRANT, schémas exposés par Data API, conventions d'identité, memberships et scopes doivent être comparés à l'existant.

Décision opérationnelle : aucune migration Famille à ce stade. Ne pas créer de backend séparé. Poursuivre la comparaison détaillée du modèle Famille aux tables et fonctions NAXA, puis concevoir une intégration additive au backend commun.

Preuve : requêtes SQL de lecture seule exécutées via l'outil Supabase sur `eouwtuusnsuxaejsxknf`, le 14 novembre 2026. Aucun DDL, DML, changement de configuration ou déploiement n'a été effectué.


## Clôture de l'audit de compatibilité Supabase — 14 novembre 2026, 03:28 UTC+1

### Verdict

L'audit de compatibilité architecturale du backend commun est terminé pour permettre la reprise des prompts. Le projet partagé reste Supabase NAXA eouwtuusnsuxaejsxknf. Aucun backend supplémentaire ne doit être créé. Les dix applications utilisent un seul projet Supabase et une isolation logique stricte par app, organisation, lieu, rôle et affectation.

**Le backend NAXA est réutilisable comme socle commun, mais les migrations Famille 0001/0002 ne sont PAS compatibles en l'état.** Elles doivent être refondues avant toute exécution.

### Résultats complémentaires vérifiés

- Les 246 tables de public ont RLS activé.
- Advisor signale 66 tables RLS sans policy : 59 public et 7 private. Les 59 tables publiques n'accordent aucun accès direct à anon/authenticated (seulement postgres/service_role) ; refus par défaut confirmé.
- 428 fonctions SECURITY DEFINER dont 344 dans public ; toutes ont un search_path explicite au catalogue. Advisor signale 7 RPC accessibles à anon et 216 signalements de fonctions accessibles à authenticated.
- Trois vues SECURITY DEFINER : public.medicaments_cima_photos_public, public.marketplace_assureurs et public.marketplace_assurance_conventions. Deux vues BI restent à vérifier pour leur mode d'invocation et leurs ACL.
- Auth leaked-password protection désactivée.
- Advisors performance : 245 FK sans index couvrant, 13 auth_rls_initplan, 267 index inutilisés, 83 groupes de policies permissives multiples, 1 index dupliqué.
- 7 buckets Storage, dont 3 privés ; 17 policies Storage.
- 14 tâches pg_cron actives ; une Edge Function active (naxa-images-import-temp, JWT requis).
- Aucune migration Famille appliquée, aucun DDL/DML ni changement de configuration.

### Contradictions de conception à corriger avant Prompt 0.3 VERT

1. Le draft 0001 crée identities, organizations, locations, devices, notifications, subscriptions et payment_intents qui recouvrent partiellement des structures déjà existantes dans NAXA. Auth.users doit rester l'identité canonique ; toute correspondance avec profiles, partners, pharmacies, partner_members et naxa_professional_assignments doit être spécifiée avant duplication.
2. La migration 0002 contient des helpers sans app_id (outlet_ids et has_organization_access), ce qui ne prouve pas l'isolation entre les dix applications.
3. is_admin est global, sans contexte applicatif explicite.
4. Les rôles owner/manager/platform_admin/commercial/partner sont génériques et ne couvrent pas les rôles métiers propres à chaque app.
5. GRANT EXECUTE ON ALL FUNCTIONS à authenticated ouvre tous les helpers SECURITY DEFINER ; remplacer par une liste blanche de RPC publiques/authentifiées.
6. Les workflows d'écriture d'organisations, memberships, rôles, appareils et installations ne sont pas encore complets.
7. 0001 est un draft dans supabase/drafts ; 0002, placée dans supabase/migrations, en dépend. La séquence n'est pas autonome pour un déploiement CLI neuf.

### Point de reprise actualisé

Le Prompt 0.3 doit maintenant être révisé comme une phase de conception et de test de l'intégration additive au backend commun NAXA, pas comme l'application du schéma 0001/0002 tel quel. Il faut d'abord produire la matrice de correspondance Auth/identités/organisations/lieux/affectations, puis corriger les helpers RLS pour exiger app_id et tester les refus inter-apps, inter-organisations et inter-lieux. Les migrations réelles restent suspendues jusqu'à validation explicite du diff.

Le rapport détaillé est docs/audits/AUDIT_COMPATIBILITE_BACKEND_COMMUN.md. Le présent document est la source de continuité prioritaire et doit être actualisé à chaque réponse qui fait évoluer les décisions, preuves ou états.

## État faisant foi — tentative de clôture Prompt 0.3 (14 novembre 2026)

Cette section prévaut sur les formulations antérieures plus optimistes du présent fichier.

**Prompt 0.3 : NON CLOS / PARTIEL.** L'audit de compatibilité du backend commun est terminé, mais le contrôle statique de la migration candidate 0002 a identifié des défauts de sécurité qui empêchent une clôture honnête :
- outlet_ids() et has_organization_access() ne prennent pas app_id ; le périmètre peut traverser les applications ;
- is_admin() est global et ne distingue pas un administrateur global d'un administrateur applicatif ;
- le GRANT EXECUTE global sur toutes les fonctions du schéma n'est pas une liste blanche de capacités ;
- le modèle 0001 duplique potentiellement des concepts déjà présents dans le backend partagé ;
- les tests CI 43545105030 prouvent uniquement les scénarios écrits dans la base éphémère et ne couvrent pas ces défauts révélés ensuite ;
- aucune migration Famille réelle n'a été appliquée ; aucune table Famille métier n'est raccordée au backend partagé.

L'ancien run CI reste une preuve historique valide de ses tests, mais il ne constitue pas une preuve de correction des nouveaux constats. Ne pas marquer 0.3 VERT.

**Prompt 0.4 : non ouvert.** Aucun contenu ni périmètre officiel du Prompt 0.4 n'a été retrouvé dans les conversations consultables ni dans les documents présents sur main. Ne pas inventer son contenu. Rechercher le document source Prompts_00_Socle_commun.pdf / ZIP avant d'en fixer le périmètre.

Point de reprise unique : corriger la conception additive du socle partagé et la migration candidate RLS, écrire des tests négatifs inter-app, inter-organisation et inter-lieu, exécuter la suite sur PostgreSQL 17 éphémère, puis actualiser ce document avec les preuves. Ne pas toucher au Supabase réel.
