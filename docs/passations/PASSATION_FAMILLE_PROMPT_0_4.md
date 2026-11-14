# PASSATION — Famille NAXA — Prompt 0.4
Date : 14 novembre 2026
État : PARTIEL / NON VERT (ne pas ouvrir 0.5 tant que les critères ci-dessous ne sont pas fermés).

## Fait
- Identité canonique Auth préservée : `auth.users` + `public.profiles`.
- Candidate SQL privée pour invitations, droits par application, appareils, lockout et récupération.
- Enregistrement d'appareil avec plafond transactionnel de deux installations par compte et scope app/organisation/lieu.
- Edge Function source pour invitation/activation, connexion limitée, registre/révocation appareil et demande WhatsApp.
- Console d'administration Web FR/EN de création d'accès.
- Bibliothèque Android Keystore/HMAC pour PIN local et accès biométrique.
- Workflow de validation PostgreSQL 17, Deno, Web et Android ajouté.

## Fichiers
- `supabase/drafts/0004_prompt_0_4_account_lifecycle.sql`
- `supabase/local-tests/0004_prompt_0_4_account_assertions.sql`
- `supabase/functions/famille-account-lifecycle/index.ts`
- `supabase/functions/famille-account-lifecycle/index_test.ts`
- `apps/web/admin-console/src/main.tsx`
- `packages/core-android/build.gradle.kts`
- `packages/core-android/src/main/java/cm/naxa/core/security/LocalAppLock.kt`
- `packages/core-android/src/main/java/cm/naxa/core/security/BiometricGate.kt`
- `.github/workflows/prompt-04-accounts.yml`
- `docs/audits/EXECUTION_PROMPT_0_4_2026-11-14.md`

## Tables / fonctions
- `famille_private.account_app_access`, `account_invites`, `account_devices`, `login_guard`, `recovery_requests`, `account_audit_log`
- `famille_private.register_device`, `record_login_failure`, `login_is_locked`, `clear_login_failures`, `revoke_device`
- Edge actions : `create_invite`, `create_employee`, `activate`, `login`, `register_device`, `revoke_device`, `request_recovery`

## Critères restant pour VERT
1. Corriger le workflow jusqu'à SUCCESS (PostgreSQL 17, Deno typecheck/tests, Web build, Android build).
2. Intégrer l'activation/login/obligation de changement de mot de passe et LocalAppLock dans les dix applications natives et les dix Web/PWA.
3. Brancher l'affectation métier à l'activation : insert RPC NAXA pour pharmacy, partner_members pour les partenaires, mapping par app pour les autres structures.
4. Ajouter la révocation de session effective côté serveur (JWT déjà émis inclus) ; le registre appareil seul ne suffit pas.
5. Ajouter parcours récupération e-mail Supabase et revue humaine WhatsApp avec décisions auditées.
6. Rejouer tests inter-app/organisation/lieu et tests négatifs complets.

## Gouvernance
- Travail sur main uniquement, aucun PR.
- Aucun déploiement Edge Function, aucune migration Supabase Production, aucune modification Auth Production, aucune création réelle d'utilisateur sans autorisation distincte.
- Aucun secret privilégié dans le dépôt.
- Prompt 0.5 reste fermé jusqu'au vert complet du Prompt 0.4.
