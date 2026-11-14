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


## Mise à jour — audit Prompt 0.4, invitations Examens et enrôlement appareils (14 novembre 2026)

### Preuves de cette passe
- Les cinq implémentations privées d'invitation Examens ont été lues : création, acceptation, récupération token, liste, révocation.
- Acceptation verrouille l'invitation `FOR UPDATE`, vérifie le destinataire Auth/e-mail confirmé, le profil Client complet et majeur, le centre actif et l'absence d'affectation active en doublon ; affectation, acceptation et audit sont dans la même transaction.
- Les fonctions privées sont SECURITY DEFINER avec search_path vide ; le rôle authenticated dispose cependant de USAGE sur `private` et EXECUTE sur les cinq fonctions. Anomalie d'exposition directe à traiter ; aucun ACL n'a été modifié.
- Les consommateurs SQL de `public.appareils` identifiés sont `naxa_device_permissions_v1`, `naxa_apply_offline_operation_v1` et `naxa_apply_offline_sale_v1`, exécutables par service_role seulement.
- Aucun chemin SQL de création/mise à jour d'`appareils` n'a été trouvé. L'inventaire Edge Functions ne contient que `naxa-images-import-temp` (JWT requis), sans rapport apparent avec l'enrôlement ; le chemin reste à rechercher dans le backend applicatif.
- Aucun outil Supabase connecté ne permet de lire les réglages Auth globaux. Allow signups, MFA, password policy, leaked-password protection, rate limits et templates restent NON VÉRIFIÉS.

### État
- Prompt 0.4 : AUDIT STRUCTUREL PARTIEL / NON VERT.
- Prompt 0.3 : PARTIEL / NON CLOS.
- Aucun DDL/DML, changement ACL, réglage Auth, migration ou déploiement sur Supabase réel.
- Rapport détaillé : `docs/audits/AUDIT_PROMPT_0_4_COMPTES_APPAREILS.md`.

### Reprise exacte
1. Inventorier les Edge Functions et le code backend qui provisionnent `public.appareils`.
2. Auditer les dépendances/exposition PostgREST du schéma `private`, puis proposer un diff ACL minimal pour retirer EXECUTE authenticated aux cinq implémentations privées si aucune dépendance légitime ne l'exige.
3. Vérifier les réglages Auth via Dashboard/API autorisée, sans exposer de secrets.
4. Construire la matrice des dix applications : identité, type d'organisation, membership, lieu, rôle, installation, appareil et session.
5. Concevoir et tester les corrections sur PostgreSQL 17 éphémère ; aucune modification Supabase réelle sans autorisation explicite.
