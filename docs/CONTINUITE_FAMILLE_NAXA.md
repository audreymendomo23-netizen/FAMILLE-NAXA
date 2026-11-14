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
