# CONTINUITÉ — FAMILLE NAXA

14 novembre 2026 — dépôt `audreymendomo23-netizen/FAMILLE-NAXA`, branche `main`.

## État des prompts

- Prompt 0.1 : architecture cadrée ; VERT technique non acquis (20 applications non compilées).
- Prompt 0.2 : schéma commun documenté ; draft 0001 exécuté dans PostgreSQL 17 éphémère ; VERT technique complet non acquis.
- Prompt 0.3 : migration candidate 0002, helpers RLS, policies core, GRANT minimaux et assertions exécutés avec succès sur PostgreSQL 17 éphémère au run GitHub Actions `43545105030`. Job SQL 0.2 SUCCESS et job RLS 0.3 SUCCESS.
- Échec restant du run : inventaire des 20 applications FAILURE ; les 10 manifests Android et 10 manifests Web/PWA sont absents. Aucun build applicatif n'a été exécuté.
- Prompt 0.3 reste PARTIEL : les vraies tables métier, vues agrégées et fonctions des dix applications ne sont pas encore raccordées ni couvertes.

## Règle opérationnelle corrigée

Les GitHub Actions et les migrations Supabase sont autorisées et doivent être utilisées lorsqu'elles sont nécessaires au chantier. Les workflows CI conservent les permissions minimales. Toute migration est versionnée, testée en base éphémère, puis appliquée au projet Supabase de développement Famille après identification certaine du project ID et vérification de l'historique.

Projets Supabase actuellement visibles dans le compte connecté :
- `naxa-ci-replay` — `fnlyjlvflgiewrkmnisi` — INACTIVE.
- `naxa-ci-replay-2` — `pwfftcsjyeibxxqhwysw` — ACTIVE_HEALTHY.
- `Naxa` — `eouwtuusnsuxaejsxknf` — ACTIVE_HEALTHY.

Aucun de ces projets n'est confirmé comme environnement dédié Famille NAXA. Aucun n'a été modifié. Ne pas appliquer de migration Famille sur Replay ou NAXA historique. L'application en Production nécessite une validation distincte de la cible et du diff.

## Décisions d'architecture conservées

10 applications ; chacune Android native Kotlin/Compose, Web responsive et PWA autonome ; pas de wrapper WebView/Capacitor ; APK distribuées depuis le site NAXA, pas Play Store ; backend Famille isolé ; droits métier isolés par application, organisation, lieu, rôle et affectation ; aucun `service_role` dans les clients.

## Preuves et liens

- [Run GitHub Actions 43545105030](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43545105030)
- [Workflow groupé](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/.github/workflows/famille-technical-gate.yml)
- [Migration candidate RLS 0002](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/supabase/migrations/0002_famille_core_rls.sql)
- [Tests RLS SQL](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/blob/main/supabase/local-tests/0002_prompt_0_3_rls_assertions.sql)

## Point de reprise

1. Raccorder les tables métier et vues agrégées des dix applications à la politique RLS.
2. Étendre les tests positifs/négatifs, GRANT, SECURITY DEFINER, absence de membership et isolation app/organisation/lieu.
3. Créer ou identifier formellement le projet Supabase de développement Famille, puis appliquer les migrations versionnées et exécuter les advisors.
4. Créer les 20 manifests applicatifs natifs/Web-PWA et remplacer l'inventaire simple par de vrais builds.
5. Actualiser l'audit et cette continuité avec les preuves. Ne pas ouvrir 0.4 avant clôture du Prompt 0.3.
