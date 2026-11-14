# Continuité — Famille NAXA

Dernière mise à jour : 14 novembre 2026  
Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA` — `main`

## Décisions canoniques
- Dix applications : Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA Hotel, Campus237, NAXA Security, GrillaD.
- Pour chacune : application Android native Kotlin/Compose et expérience Web responsive/PWA autonome.
- Un seul backend Supabase NAXA existant ; identités et ressources canoniques réutilisées, isolation stricte par application/organisation/lieu.
- Tests PostgreSQL 17 éphémères avant toute migration réelle.
- Aucune migration Supabase réelle, publication APK ou déploiement sans autorisation explicite.
- Travail sur `main`, sans branche ni PR.

## Dernier lot exécuté — cinq chantiers en parallèle
Commit précédent : `d952eed3fc90161d918b51a3a585db166b5014e6`.

Fichiers ajoutés :
- `supabase/drafts/0003_prompt_0_3_contextual_rls.sql`
- `supabase/local-tests/0003_prompt_0_3_context_assertions.sql`
- `packages/core-kotlin/src/main/kotlin/cm/naxa/core/offline/SyncContract.kt`
- `packages/core-kotlin/src/main/kotlin/cm/naxa/core/notifications/NotificationContract.kt`
- `packages/core-kotlin/src/main/kotlin/cm/naxa/core/ai/LocalInsights.kt`
- `packages/core-web/package.json`
- `packages/core-web/src/release/verifyManifest.js`
- `packages/core-web/src/whatsapp/safeMessage.js`
- `packages/core-web/test/core.test.js`
- `docs/audits/EXECUTION_CINQ_CHANTIERS_2026-11-14.md`

Résultats :
- Ajout d'un scope RLS dépendant d'un claim signé `app_metadata.active_app_id`, fail-closed sans claim.
- Ajout de contrats Kotlin pour synchronisation offline, notifications et IA locale.
- Ajout d'outils Web pour empreinte SHA-256, version minimale et garde WhatsApp.
- Tests Node fournis mais non exécutés ; tests PostgreSQL/Kotlin non exécutés.
- Les vingt projets Android/Web restent à construire.
- Aucun changement Supabase réel ni déploiement.

## Point de reprise exact
1. Exécuter `node --test packages/core-web/test/core.test.js` sur Node 20+.
2. Exécuter candidate SQL 0003 + assertions dans PostgreSQL 17 éphémère avec fixtures de deux apps, deux organisations et deux lieux ; ajouter les tests négatifs complets.
3. Construire le mécanisme serveur/Auth du claim signé avant toute activation de ce modèle.
4. Créer les dix projets Android Kotlin/Compose et les dix projets Web/PWA, puis compiler/tester.
5. Compléter les modules natifs notification/briefing, stockage/sync, signature APK, exports et assistant IA local.
6. Mettre à jour ce document et l'audit après chaque preuve réelle.

## Statut
Les cinq chantiers ont reçu un premier lot de code. Aucun prompt 0.3–0.13 n'est VERT.
