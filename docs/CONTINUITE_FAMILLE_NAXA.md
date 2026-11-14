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

## Reprise vérifiée — recherche Prompt 0.4 et correction 0.3 (14 novembre 2026, 23:xx UTC+1)

### Recherche du Prompt 0.4 sur GitHub

Vérifications effectuées en lecture seule :
- Dépôt Famille audreymendomo23-netizen/FAMILLE-NAXA, branche par défaut main : recherches GitHub de « Prompt 0.4 », « PROMPT_0_4 », « Prompt 0.4 page 7 » et « Prompts_00_Socle_commun » : aucun résultat.
- Dépôt NAXA historique audreymendomo23-netizen/NAXA : mêmes recherches sans résultat.
- Tentatives de lecture des chemins probables Nouveau projet/Prompt/Prompts_00_Socle_commun.pdf, docs/Prompts_00_Socle_commun.pdf, Prompts_00_Socle_commun.pdf, docs/prompts/Prompts_00_Socle_commun.pdf et des chemins Markdown docs/architecture-360/PROMPT_0_4.md / PROMPT_0_4_FONCTIONNEL.md : fichiers absents (404).
- La source de Prompt 0.3 est explicitement indiquée dans docs/architecture-360/PROMPT_0_3_SECURITE_RLS.md : Projet.zip → Nouveau projet/Prompt/Prompts_00_Socle_commun.pdf, page 6. Cela ne permet pas de déduire le texte de la page suivante.

**Verdict Prompt 0.4 : non retrouvé dans aucun des deux dépôts GitHub consultés.** Le PDF/ZIP source n'est pas présent aux chemins recherchés. Ne pas fabriquer le Prompt 0.4 à partir de suppositions. Il faut récupérer l'archive source ou un chemin GitHub exact si elle a été déposée ailleurs.

### Correction Prompt 0.3 — audit de la migration candidate 0002

Relecture du contenu actuel de supabase/migrations/0002_famille_core_rls.sql et de ses tests :
- Les helpers is_admin(), outlet_ids() et has_organization_access(uuid) sont encore sans paramètre applicatif.
- Les policies appellent ces helpers sans contexte app_id, y compris sur les tables où ce contexte est disponible.
- Le script termine par GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA famille_core TO authenticated, qui contredit le principe de liste blanche.
- Le test 0002_prompt_0_3_rls_assertions.sql couvre actuellement plusieurs cas organisation/lieu, mais n'établit pas les refus inter-app ; il utilise un seul rôle applicatif (Kiosko) pour ses jeux de données.
- Le runner local refuse explicitement toute connexion distante, ce qui est conservé.

### Cause racine et décision de correction

La correction ne peut pas se limiter à renommer trois fonctions : plusieurs policies utilisent un admin global sur des tables sans app_id, et le modèle 0001 crée aussi des organisations, memberships, lieux, appareils et identités parallèles aux entités déjà existantes du backend NAXA partagé. Une modification partielle risquerait de donner une fausse assurance sans régler la duplication ni la propagation des droits.

**État de cette passe : audit statique approfondi réalisé ; correction SQL et test inter-app non encore appliqués ; Prompt 0.3 reste NON CLOS / PARTIEL.** Aucun commit de correction SQL, aucune migration Supabase réelle et aucun déploiement n'ont été effectués pendant cette passe. La preuve CI historique 43545105030 ne valide pas les défauts nouvellement identifiés.

### Point de reprise technique obligatoire

1. Reconcevoir 0001 comme couche additive au backend NAXA existant : réutiliser les identités et organisations/lieux/memberships existants lorsqu'ils sont sémantiquement compatibles ; documenter les correspondances et les écarts avant DDL.
2. Définir une source fiable de contexte applicatif pour chaque appel RLS et RPC ; les helpers et policies doivent exiger ce contexte. Les lignes sans app_id ne doivent pas bénéficier d'un bypass admin implicite.
3. Remplacer les grants globaux par des droits explicites, testés avec les rôles PostgreSQL réels ; tenir compte des fonctions appelées par les policies.
4. Ajouter des tests positifs et négatifs inter-app, inter-organisation, inter-lieu, sans membership, ainsi que des tests de droits EXECUTE et des RPC SECURITY DEFINER.
5. Exécuter toute la suite sur PostgreSQL 17 éphémère, vérifier le workflow GitHub Actions, puis mettre à jour le statut. Ne pas toucher au Supabase NAXA réel sans diff validé et autorisation explicite.

## Rectification — Prompt 0.4 retrouvé dans le dépôt historique NAXA (14 novembre 2026)

La recherche précédente est rectifiée : le Prompt 0.4 existe bien dans le dépôt historique audreymendomo23-netizen/NAXA, fichier source Markdown :

7 famille naxa/02-prompts/00-socle-commun.md

Lien : https://github.com/audreymendomo23-netizen/NAXA/blob/main/7%20famille%20naxa/02-prompts/00-socle-commun.md

Le fichier précise qu'il s'agit de la version Markdown issue de Prompts_00_Socle_commun.txt, version 1.0 du 31 octobre 2026. Le Prompt 0.4 porte le titre « Comptes créés par l'administration ».

### Périmètre exact retrouvé
1. Création des fiches clients par l'administration : applications autorisées, palier, durée, remise/période d'essai éventuelle, identifiant basé sur le téléphone et lien de téléchargement.
2. Première connexion : changement obligatoire du mot de passe (minimum 6 caractères), puis code local à 4 chiffres ou biométrie à l'ouverture.
3. Mot de passe oublié : e-mail si disponible, sinon demande WhatsApp traitée par l'administration après contrôle d'identité.
4. Limite de deux appareils actifs par point ; fermeture du plus ancien au-delà, notification au propriétaire, déconnexion à distance et blocage temporaire après cinq tentatives échouées ; pas de SMS payant.
5. Création des comptes employés par le gérant ou propriétaire, accès individuel, changement d'utilisateur sans déconnexion et fonction serveur de création de compte non déployée.

### Contradictions et adaptations obligatoires avant exécution dans Famille NAXA actuel
- Le prompt source décrit 7 applications ; le périmètre actuel en compte 10.
- Il répète des contraintes historiques « Android uniquement » et « aucun CI » ; le projet actuel exige Android natif Kotlin/Compose et Web responsive/PWA, et autorise les GitHub Actions nécessaires.
- Son modèle « client / point / gérant / propriétaire » doit être aligné sur les entités canoniques déjà présentes dans le backend NAXA (auth.users, profiles, partners, partner_members, pharmacies, naxa_professional_assignments) sans créer de comptes ou memberships parallèles.
- Le parcours de création de comptes doit utiliser les mécanismes serveur Supabase/Auth ; aucune clé privilégiée ne doit être embarquée dans les clients. La fonction de création reste non déployée tant que l'autorisation requise n'est pas donnée.
- Le code local à 4 chiffres doit rester local, protégé par le stockage sécurisé Android et soumis à limitation de tentatives ; ne jamais le traiter comme un mot de passe serveur ou le stocker en clair.
- Les règles exactes de rattachement et de plafond d'appareils doivent être définies par application et par entité métier (organisation/lieu), et non transposées aveuglément à « deux appareils par point ».
- Le contrôle d'identité pour une réinitialisation WhatsApp doit être documenté sans exposer de PIN/OTP ni demander leur transmission.
- Le texte source prévoit l'identifiant égal au téléphone ; ce choix doit être concilié avec les identifiants Auth canoniques et les règles de confidentialité/normalisation des numéros.

Verdict : Prompt 0.4 historique retrouvé et lu. Il est exploitable comme base documentaire, mais PAS directement exécutable sans adaptation au périmètre actuel à 10 applications et au backend NAXA partagé. Aucun code, migration, modification Supabase, déploiement ou publication n'a été effectué pendant cette recherche.

### Point de reprise
Produire une version Famille NAXA actuelle du Prompt 0.4, en conservant les exigences fonctionnelles ci-dessus et en corrigeant les contradictions identifiées ; ensuite seulement, l'implémenter et la tester.


## Prompt 0.4 — adaptation Famille NAXA créée (14 novembre 2026)

Le prompt historique « Comptes créés par l'administration » a été retrouvé dans le dépôt NAXA : `7 famille naxa/02-prompts/00-socle-commun.md`, version Markdown de `Prompts_00_Socle_commun.txt`, version 1.0 du 31 octobre 2026. Il couvre création administrative, activation, verrouillage local/biométrie, récupération, appareils, limitation après échecs et création individuelle des employés.

Une version adaptée au périmètre actuel a été créée : `docs/architecture-360/PROMPT_0_4_COMPTES_ADMIN.md`.

Adaptations explicites : 10 applications actuelles ; Android natif Kotlin/Compose et Web responsive/PWA ; GitHub Actions autorisées ; backend Supabase NAXA unique ; réutilisation obligatoire de `auth.users`, profils, partenaires, organisations, lieux et affectations canoniques lorsqu'ils sont compatibles ; aucun compte/membership parallèle ; aucun `service_role` client ; fonctions privilégiées non déployées sans autorisation ; tests PostgreSQL 17 et tests négatifs inter-app/organisation/lieu.

Le prompt adapte également les exigences historiques : identifiant téléphone à valider contre Auth et normalisation ; mot de passe soumis à la politique Auth actuelle plutôt qu'au minimum historique de 6 caractères ; code local quatre chiffres jamais stocké en clair ni envoyé au serveur ; plafond de deux appareils à confirmer par application et catégorie d'acteur au lieu d'une règle globale ; récupération WhatsApp humaine sans échange de PIN/OTP.

Preuve de création : commit `cb7a7610bb2c632c72be5d78dc542f270e1ae119`.
Lien : https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/docs/architecture-360/PROMPT_0_4_COMPTES_ADMIN.md

**État Prompt 0.4 adapté : PRÉPARATION DOCUMENTAIRE.** Le prompt est rédigé, mais aucun audit technique détaillé des flux de comptes/appareils, aucun code, aucun test d'implémentation et aucune migration n'ont été exécutés dans cette passe. Prompt 0.3 reste NON CLOS / PARTIEL ; cette adaptation ne le clôt pas et ne justifie aucune migration Production.

### Reprise exacte
Commencer par l'audit en lecture seule des ressources Auth, profils, partenaires, memberships, affectations, appareils, invitations, récupération et RPC existantes sur le backend NAXA. Produire la matrice réutiliser/adapter/créer/écarter et relever les écarts du prompt avant toute implémentation. Aucun changement Supabase réel sans diff validé et autorisation explicite.


## Prompt 0.4 — audit structurel backend NAXA (14 novembre 2026)

Audit en lecture seule du projet Supabase Naxa `eouwtuusnsuxaejsxknf`, PostgreSQL 17.11.0.002, statut ACTIVE_HEALTHY. Rapport : `docs/audits/AUDIT_PROMPT_0_4_COMPTES_APPAREILS.md`.

Preuves principales : auth.users=10, profiles=10, partners=0, partner_members=0, pharmacies=4, promoteur_pharmacies=1, naxa_professional_assignments=0, appareils=0, naxa_livreur_invites=0, exam_staff_invites=0, suivi_user_devices=1. Ces comptages sont agrégés, aucune donnée personnelle n'a été extraite.

Mapping : `auth.users` est l'identité canonique ; `profiles.id` est PK/FK auth.users ; `profiles` contient déjà téléphone/pays, état actif, majorité/consentement, parent et fonctions ; `partners`/`partner_members` sont adaptés aux relations partenaire mais actuellement vides ; `pharmacies`/`promoteur_pharmacies` structurent les points pharmacies ; `naxa_professional_assignments` et `naxa_roles` sont le registre d'affectation professionnelle ; `exam_staff_invites` et `naxa_livreur_invites` sont des flux spécialisés, non un service générique ; `appareils` est un registre professionnel pharmacie-spécifique ; `suivi_user_devices` est réservé aux appareils connectés Santé ; `auth.sessions` et les journaux NAXA sont la base des sessions/audits.

Anomalie critique prouvée : `public.naxa_enforce_session_limit()` est un trigger SECURITY DEFINER dont le corps fait seulement `RETURN NEW`; `public.naxa_session_count(uuid)` retourne toujours `0`. Aucun plafond réel de sessions/appareils n'est donc démontré par ces fonctions. `appareils` a RLS activé mais aucune policy et aucun grant direct anon/authenticated dans les grants examinés ; les invitations ont également RLS sans policy et aucun grant direct client observé, avec RPC dédiées. `profiles` a des policies de lecture/écriture mais des grants directs très larges à anon/authenticated, notamment anon ; revue de moindre privilège prioritaire, sans révocation avant cartographie des dépendances.

Le trigger `auth.users.on_auth_user_created` appelle `handle_new_user()` SECURITY DEFINER pour créer un profil avec les métadonnées fournies à l'inscription. Le réglage Auth autorisant ou bloquant l'inscription libre n'a pas été confirmé par SQL ; il reste à vérifier dans Dashboard/API. Le contenu de user_metadata ne doit pas être utilisé pour les autorisations.

**État Prompt 0.4 : AUDIT STRUCTUREL PARTIEL — NON VERT.** Aucun DDL/DML, changement Auth, création de compte, révocation, migration, déploiement ou publication effectué. Prompt 0.3 reste PARTIEL/NON CLOS.

Reprise : (1) inspecter la chaîne complète des triggers de sessions et résoudre les stubs dans PostgreSQL 17 éphémère ; (2) inspecter helpers privés d'invitation et consommateurs de `appareils` ; (3) confirmer réglages Auth allow-signups, politique mot de passe, leaked password protection, MFA, rate limits et templates ; (4) cartographier organisations/lieux et appareils par les dix apps ; (5) tests positifs/négatifs inter-app/org/lieu ; aucun changement Production sans diff validé et autorisation explicite.


### Extension audit Prompt 0.4 — chaîne sessions et consommateurs appareils

Le contrôle des triggers Auth confirme que `auth.sessions` ne porte que deux triggers de journalisation (insert/delete). Aucun trigger de limitation n'est attaché ; `naxa_enforce_session_limit()` est un stub non raccordé et `naxa_session_count(uuid)` retourne 0. Les sessions Supabase sont par défaut illimitées ; la fonction native « Single session per user » ne permet qu'une session et n'est pas équivalente à deux appareils par point (documentation : https://supabase.com/docs/guides/auth/sessions).

Les fonctions `naxa_device_permissions_v1`, `naxa_apply_offline_operation_v1` et `naxa_apply_offline_sale_v1` consomment `public.appareils` pour vérifier état appareil, fraîcheur 7 jours, profil, rôle, pharmacie, privilèges, séquences hors ligne et ventes. Leurs ACL inspectées limitent EXECUTE à postgres/service_role ; il ne faut donc pas ouvrir la table aux clients par une policy générique. Les RPC livreur contrôlent le Promoteur/Pharmacie, l'e-mail confirmé, la majorité et l'exclusivité du rôle Livreur avant de créer l'affectation ; les invitations examens délèguent à des implémentations privées dont le code reste à auditer.

Réglages Auth (allow signups, politique de mot de passe, leaked-password protection, MFA, rate limits, templates) toujours non vérifiés : get_project ne les expose pas. Pas de réglage modifié.

Rapport d'audit enrichi : `docs/audits/AUDIT_PROMPT_0_4_COMPTES_APPAREILS.md`, commit `f0cbf7cd4e2076e58e16d5c808598fb3f96afc49`.

**État inchangé : Prompt 0.4 audit partiel/non vert ; Prompt 0.3 partiel/non clos.** Aucun changement Production.


## Audit transversal des prompts 0.3 à 0.13 — 14 novembre 2026

Rapport de référence : [AUDIT_TRANSVERSAL_PROMPTS_0_3_A_0_13.md](audits/AUDIT_TRANSVERSAL_PROMPTS_0_3_A_0_13.md). Commit de création : `7bf59c51c4f44e9d5c244f2bbd04e707895a151a`.

L'audit a retrouvé les onze sections normatives dans `7 famille naxa/02-prompts/00-socle-commun.md` et les adaptations 0.3/0.4 sous `docs/architecture-360/`. Il confirme que le chantier doit être traité comme un programme transversal, avec contrats communs et preuves séparées par prompt.

**Statut initial au 14/11/2026 : 0 VERT / 11.**
- 0.3 : PARTIEL / NON VERT — helpers RLS sans contexte app complet, duplication de ressources, matrice et tests d'isolation incomplets.
- 0.4 : audit structurel PARTIEL / NON VERT — provisioning non implémenté, stubs de limite de session, réglages Auth non vérifiés, appareils/invitations à raccorder.
- 0.5 à 0.13 : NON IMPLÉMENTÉS / NON VERTS — aucune implémentation compilable n'a été démontrée ; les 20 manifests Android/Web attendus par le workflow sont absents, packages communs non créés, pas de moteur offline, notifications/briefings, paiements applicatifs, design system, admin Web, signature/export, IA ou page de téléchargement prouvés.

Contradictions à appliquer globalement : 10 applications et non 7 ; Android Kotlin/Compose natif + Web/PWA autonomes ; backend Supabase NAXA commun ; GitHub Actions autorisées ; aucune écriture Production, migration réelle, publication ou déploiement sans autorisation distincte. Les règles financières du prompt historique 0.8 doivent être conciliées avec les décisions NAXA actuelles avant codage. Les règles de conflit et de priorité FCM doivent être spécifiées par type d'événement, pas généralisées.

La suite est organisée en pistes simultanées : (A) RLS/identité/provisioning/paiements/admin ; (B) stockage local/synchronisation/notifications/briefings ; (C) dix Android + dix Web/PWA/design/i18n ; (D) sécurité APK/exports/versions/distribution ; (E) moteur IA explicable et anonymisation. Les pistes utilisent des contrats communs et des tests d'intégration.

Aucune opération Supabase réelle, aucun réglage Auth, aucune Edge Function, aucun site ou APK n'a été modifié/publié par cet audit. Les tests éphémères et builds locaux/CI sont autorisés. Le vert global exige les onze prompts verts avec tests reproductibles au commit.

Point de reprise : figer les contrats communs et la matrice des dix apps, corriger le socle 0.3 en PostgreSQL 17 éphémère, puis lancer les fondations applicatives et les pistes transversales en parallèle.

## Exécution simultanée des cinq pistes — Lot 1 (14 novembre 2026)

Rapport d'exécution : [EXECUTION_LOT_1_PROMPTS_0_3_A_0_13.md](audits/EXECUTION_LOT_1_PROMPTS_0_3_A_0_13.md). Le générateur versionné `scripts/bootstrap-foundations.mjs` pose les dix squelettes Android Kotlin/Compose et les dix cibles Web/PWA, les contrats communs (sync/version/conflits, preuves paiement, états notifications), les premiers jetons design, la coquille Admin Web, un moteur de règles explicables supervisé et les règles de sécurité/distribution. Les cibles sont générées à l'exécution CI et ne sont pas encore matérialisées comme fichiers suivis dans Git.

CI : les dix Web/PWA ont compilé dans le run `43550594076`; les contrôles PostgreSQL 17 du draft 0001 et des assertions 0002 ont réussi dans les runs `43550680382` et `43550728397`. L'action setup-android initiale échouait sur le paquet obsolète `tools`; elle a été remplacée par une installation SDK explicite. Le run `43550728397` et le run associé au commit `29e88e990d1258545058011fa3afaa6e8013cab2` doivent être vérifiés avant de conclure sur les builds Android.

Statut des cinq pistes : A fondations de sécurité/paiement/admin créées mais pas raccordées au backend Auth/RLS ; B contrats sync/notification créés mais pas de Room/queue/FCM ; C 20 squelettes générables et Web compilé, Android encore à prouver ; D manifeste de distribution documenté, pas de signature/export/site ; E moteur de règles explicable créé, pas de modèle local/anonymisation. **Aucun prompt 0.3–0.13 n'est VERT.**

Aucun changement Supabase réel, aucune migration, aucun DDL/DML, aucune modification Auth, aucun déploiement ni publication. Prochaine reprise : vérifier les runs CI, corriger et prouver les dix builds Android, matérialiser les sources générées dans Git, puis avancer en parallèle sur Room/sync, RLS contextuelle inter-app, provisioning/paiement, Admin MFA, distribution et tests de confidentialité IA.


### Complément d'exécution — queues offline et CI Android
Le générateur `scripts/bootstrap-foundations.mjs` inclut désormais une file Room persistante dans chaque module Android, un package IndexedDB de file Web, ainsi qu'un service worker PWA limité au shell statique (les chemins Auth et API sont exclus du cache). Le workflow teste les contrats communs et le moteur de règles explicables, compile les dix cibles Web/PWA et prépare le SDK Android préinstallé du runner. Le run `43550939743` a franchi les étapes Web et tests ; la compilation des dix modules Android était encore en cours au dernier contrôle. Le run suivant `43550999833` couvre la version avec Room/IndexedDB ; sa compilation Android doit aussi être confirmée. Ces fondations ne constituent pas encore une synchronisation serveur, des notifications FCM, une authentification/RLS intégrée ni une distribution signée. Aucun prompt n'est vert.


### Correctif Android JVM — 14/11/2026
Le premier build Android natif a atteint la compilation Kotlin puis a échoué sur l'incompatibilité de cible JVM : javac 1.8 contre Kotlin 17. Le générateur a été corrigé pour fixer `sourceCompatibility`, `targetCompatibility` et `kotlinOptions.jvmTarget` à Java 17 dans les dix modules. Commit correctif : `d5dbea85e3340c2ce0e002c7544bbdfbcc25a30e`. Le build Android des dix applications doit être relancé et vérifié après ce correctif ; aucun vert natif n'est encore revendiqué.
