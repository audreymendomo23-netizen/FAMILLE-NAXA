# Continuité — Famille NAXA
Dernière mise à jour : 14 novembre 2026
Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA` — `main`.

## Décisions canoniques
- Dix applications : Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA Hotel, Campus237, NAXA Security, GrillaD.
- Android natif Kotlin/Compose et Web responsive/PWA autonome pour chacune.
- Un seul backend Supabase NAXA existant ; réutilisation des ressources canoniques ; isolation côté serveur par app/organisation/lieu.
- Main uniquement, pas de branches/PR. Tests PostgreSQL 17 éphémères. Aucun déploiement, migration Supabase réelle ou publication APK sans autorisation explicite.
- Distribution APK depuis le site officiel, jamais Play Store.

## Preuves confirmées
- Run 43551672204 SUCCESS.
- Run 43557643046 SUCCESS : PostgreSQL 17, RLS 0.3, 10 builds Web/PWA, 10 builds Android natifs.
- Les vingt socles sont persistés sur main au commit `4a8af10c82017485578ebb24af82c48aeeb31b2f`.
- `scripts/bootstrap-foundations.mjs` est la source de vérité du générateur. Toute évolution du socle est codée dans ce script puis reconstruite et persistée.

## Architecture présente
- `apps/android/<app>/` : dix modules Kotlin/Compose, manifests et Room queue.
- `apps/web/<app>/` : dix cibles Vite/React, manifests PWA, service workers.
- `packages/contracts/`, `design-system/`, `assistant/`, `offline-web/`, `core-web/`.
- `supabase/drafts/0001_famille_core_proposed.sql`, `supabase/migrations/0002_famille_core_rls.sql`, `supabase/drafts/0003_prompt_0_3_contextual_rls.sql`.

## Lot en cours
- Correction RLS multi-app : tous les helpers sensibles vérifient le claim signé `active_app_id`; test multi-app Kiosko/Campus237.
- Module Android `core-android` : canaux Critique/Opérations/Abonnement/Information/Coaching IA et briefings locaux WorkManager.
- Calculs FCFA abonnement et tests unitaires.
- Sept thèmes de marque et calcul WCAG AA ; les palettes des trois apps supplémentaires restent à valider.

## Restant avant vert
1. Auth Hook serveur pour signer/rafraîchir le claim app actif.
2. Tests RLS exhaustifs sur dix apps, plusieurs organisations, lieux et rôles.
3. Création Admin, MFA, appareils/sessions, limitation tentatives, employés.
4. Sync réseau réelle, idempotence serveur, corrections immuables et conflits par agrégat.
5. FCM, jetons, centre de notifications, actions rejouables, santé Android.
6. Abonnements intégrés au backend métier et à la vérification de paiement.
7. Administration Web réelle, FR/EN, composants, thèmes, contrastes et parcours.
8. Keystore hors dépôt, vérification certificat côté serveur, exports PDF/XLSX.
9. IA locale connectée aux données métiers, anonymisation et voix.
10. Page APK, guide par constructeur, vérification de version/signature.

## Garde-fous
Aucune migration appliquée au Supabase réel ; aucun secret ou keystore dans le dépôt ; aucune publication ou déploiement.

## Mise à jour — Prompt 0.3, 14 novembre 2026, 05:07 UTC

### Preuve obtenue
- Workflow dédié https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43559938233 : SUCCESS.
- PostgreSQL 17 éphémère : bootstrap Auth, schéma 0001, policies 0002, candidate contextualisée 0003, tests claims signés/refus par défaut et matrice complète après contextualisation : tous réussis.
- Couverture testée : propriétaire/compte mère, gérant/lieu, autre propriétaire, Admin agrégats sans transactions détaillées, commercial, partenaire, abonnement expiré avec facturation encore accessible, isolation Kiosko/Campus237, claims absent et malformé.
- supabase/drafts/0003_prompt_0_3_contextual_rls.sql reste une candidate de test ; aucune migration ou configuration Auth n'a été appliquée au Supabase NAXA réel.

### État réel
- Noyau RLS candidat : VERT EN TEST ÉPHÉMÈRE.
- Prompt 0.3 global : PARTIEL / NON VERT. Il reste l'Auth Hook serveur qui émet le claim app_metadata.active_app_id, la correspondance et la couverture RLS des tables métier des dix applications, les droits par application/domaine, et une migration additive compatible avec le backend NAXA partagé. Le contrôle du backend est consigné dans docs/audits/PROMPT_0_3_COMPATIBILITE_BACKEND_NAXA.md.
- Ne pas ouvrir le Prompt 0.4 avant clôture de ces critères, conformément au prompt 0.3.

### Dernier commit de code/test de cette passe
- 6a68fdeaf3ec622fa61a152a8d229e38e209b621 — assertions test limitées aux helpers exposés.
- Workflow dédié : .github/workflows/prompt-03-rls.yml ; il exécute les tests dans le conteneur PostgreSQL 17 sans installation locale du client.
