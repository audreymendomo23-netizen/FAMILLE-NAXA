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


## Ouverture Prompt 0.5 — Hors connexion et synchronisation (14 novembre 2026)

### Source et cadrage
- Prompt historique identifié : `7 famille naxa/02-prompts/00-socle-commun.md`, section « PROMPT 0.5 — Hors connexion et synchronisation ».
- Adaptation Famille 10 applications : `docs/architecture-360/PROMPT_0_5_HORS_CONNEXION_SYNCHRONISATION.md`.
- Rapport d'audit initial : `docs/audits/AUDIT_PROMPT_0_5_HORS_CONNEXION_SYNCHRONISATION.md`.

### Preuves du dépôt
- Dix files Android Room `OfflineQueue.kt` existent, une par application, avec eventId, appId, aggregateType, payload, deviceSequence, createdAt et state. Elles n'ont pas de transport, batch, retry/backoff ni accusé serveur prouvé.
- `scripts/bootstrap-foundations.mjs` génère ces dix files ; toute évolution doit modifier le générateur puis reconstruire les modules.
- `packages/offline-web/src/index.ts` expose uniquement enqueue/listQueued/setQueueState via IndexedDB ; aucun transport/retry/conflit.
- Les dix service workers Web ont le même SHA et cachent uniquement le shell/manifest/assets ; pas de sync de données métier.
- `packages/contracts/src/index.ts` contient déjà `SyncEnvelope` et une politique de conflit : vente/paiement/abonnement = revue manuelle ; inventaire = compensation ; autres = revue manuelle.

### Preuves du backend NAXA réel — lecture seule
- Tables existantes : `public.offline_operations`, `public.naxa_offline_sales`, `private.naxa_offline_lww_config`, `public.appareils`, `public.stock_manager_movement_journal`.
- RPC existantes : `naxa_apply_offline_operation_v1` (stock_set_quantity uniquement, LWW spécifique, appareil ≤ 7 jours), `naxa_apply_offline_sale_v1` (contrôles caisse/prix/stock, idempotence operation_id, séquence appareil, ≤ 7 jours) et `offline_stock_set_quantity`.
- Ces flux sont pharmacie-spécifiques, ne forment pas un moteur générique pour les dix apps et ne doivent pas être détournés.
- `public.abonnements` porte une formule et une échéance pharmacie ; aucune matrice globale 10 apps ↔ Essentiel/Pro/Réseau ↔ 7/14 jours n'a été démontrée.
- Les tables de preuves SMS inspectées n'ont pas de trigger append-only observé ; `service_role` possède UPDATE/DELETE. Immutabilité DB non démontrée, aucune correction appliquée.

### Contradiction structurante
La règle historique « le plus ancien enregistrement serveur gagne » ne peut pas être appliquée uniformément : l'idempotence d'un même event est distincte du conflit entre deux événements métier. La politique existante `decideConflict` et les règles NAXA (revue financière, compensation inventaire, LWW stock pharmacie spécifique) priment ; aucun écrasement financier automatique.

### État
- Prompt 0.5 : AUDIT DE DÉPART PARTIEL / NON VERT ; aucune implémentation Prompt 0.5 ni migration Production réalisée.
- Prompt 0.4 : PARTIEL / NON VERT.
- Prompt 0.3 : PARTIEL / NON CLOS.
- Aucun DDL/DML, ACL, migration, réglage ou déploiement Production.

### Reprise exacte
1. Concevoir et tester le contrat de file, transitions, idempotence, lots, retry et conflits par domaine dans `packages/contracts`.
2. Implémenter le moteur IndexedDB commun et tests reload/partial ack.
3. Implémenter le moteur Room/WorkManager commun dans `packages/core-android` et modifier le générateur `scripts/bootstrap-foundations.mjs`.
4. Cartographier les plans/tolérances des dix apps avant le verrouillage 7/14 jours.
5. Auditer les chemins d'écriture des preuves SMS et concevoir append-only sur PostgreSQL 17 éphémère.
6. Aucun changement Supabase réel sans autorisation explicite.


## Ouverture Prompt 0.6 — Notifications (14 novembre 2026)

### Source et cadrage
- Prompt historique : `NAXA/7 famille naxa/02-prompts/00-socle-commun.md`, section « PROMPT 0.6 — Notifications ».
- Adaptation Famille 10 applications : `docs/architecture-360/PROMPT_0_6_NOTIFICATIONS.md`.
- Audit initial : `docs/audits/AUDIT_PROMPT_0_6_NOTIFICATIONS.md`.

### Preuves de code lues
- `packages/core-android/src/main/java/cm/naxa/core/notifications/NotificationChannels.kt` : cinq canaux Critique/Opérations/Abonnement/Information/Coaching IA ; API de publication locale ; contrôle runtime POST_NOTIFICATIONS Android 13+.
- `BriefingScheduler.kt` et `BriefingWorker.kt` : planification et récurrence de briefings via WorkManager.
- `packages/core-android/src/main/AndroidManifest.xml` : permission POST_NOTIFICATIONS déclarée au niveau bibliothèque.
- `apps/android/kiosko/src/main/AndroidManifest.xml` : manifeste application lu ; permission non déclarée localement, fusion de manifestes et demande runtime à vérifier.
- `packages/core-web/src/whatsapp/safeMessage.js` : préparation wa.me avec filtre PIN/OTP et séquences numériques.
- Libellés Android codés en dur en français : à externaliser FR/EN.

### Écarts non démontrés
- FCM data, stockage/rotation/révocation des jetons et fonction serveur d'envoi.
- Centre persistant lu/non lu, actions rejouables idempotentes et statuts distincts.
- Anti-doublon métier, préférences, heures calmes et réarmement d'alertes.
- Écran Santé de l'appli, assistant de configuration et tests ciblés.
- Couverture Android/Web des dix applications.

### État
- Prompt 0.6 : AUDIT INITIAL PARTIEL / NON VERT.
- Les canaux, notifications locales, briefings WorkManager et liens WhatsApp préparés existent partiellement ; ne pas les reconstruire.
- Aucun DDL/DML, changement ACL, configuration FCM, migration Supabase, déploiement ou publication.
- Prompt 0.5 reste PARTIEL / NON VERT ; Prompt 0.4 PARTIEL / NON VERT ; Prompt 0.3 PARTIEL / NON CLOS.

### Reprise exacte
1. Inventorier tout le dépôt pour FCM, jetons, notifications Web, centre, préférences et tests ; inspecter les manifestes fusionnés et le générateur.
2. Cartographier en lecture seule les ressources notifications/appareils existantes du backend Supabase NAXA.
3. Définir contrat partagé, clé d'idempotence, états, actions, canaux et préférences.
4. Concevoir les migrations et la fonction d'envoi candidates ; tests PostgreSQL 17 éphémères uniquement.
5. Implémenter le centre, FCM, santé Android et intégration dix apps avec preuves.


## Mise à jour — validation technique Prompts 0.1 et 0.2 (14 novembre 2026)

- Run groupé GitHub Actions : [43563686065](https://github.com/audreymendomo23-netizen/FAMILLE-NAXA/actions/runs/43563686065), commit testé `52d5b2b2b52d4eae59521091e85812ceda39e39c`.
- Prompt 0.1 : 10 builds Web/PWA + 10 builds Android réussis ; persistance des 20 socles réussie.
- Prompt 0.2 : draft SQL exécuté sous PostgreSQL 17 éphémère ; 22 tables, 10 apps, scénario positif et trois rejets inter-périmètres réussis ; RLS activé, aucun GRANT/policy (default-deny) confirmé.
- **Verdict : Prompt 0.1 VERT BUILD DES 20 SOCLES ; Prompt 0.2 VERT TECHNIQUE POUR LE MODÈLE COMMUN ET LE DRAFT SQL ISOLÉ.**
- Cette clôture n'autorise aucune migration, exposition Data API, modification Replay/Production, configuration Auth, déploiement ou publication. Les policies RLS fonctionnelles et GRANT applicatifs restent dans le périmètre sécurité distinct ; aucun faux certificat de sécurité n'est émis.

## Exécution corrective — Prompt 0.1 (14 novembre 2026)

Le contrôle du générateur a révélé que la précédente preuve de 20 builds utilisait une pile différente de celle approuvée : AGP 8.6.1/Kotlin 2.0.20/compileSdk 35/Compose BOM 2024.10, Vite/React 18.3 et Gradle 8.7. Le run 43557643046 ne clôt donc pas la conformité du Prompt 0.1.

Le générateur a été remplacé pour produire dix modules Android natifs avec Kotlin 2.4.21, AGP 9.3.1, Gradle 9.5.0, JDK17, API37/min26 et dix applications Next.js 16.4.6/React 19.3.0/Serwist 9.5.13. pnpm 12.21.0 gère le workspace produit. Le workflow est renforcé avec builds, tests unitaires, tests Compose, E2E et axe-core.

Le statut reste EN VALIDATION CI ; ne déclarer VERT qu'après preuve intégrale sur ce nouvel environnement et persistance du wrapper et du lockfile. Aucune migration Supabase réelle, aucun déploiement ni publication APK.


## Arbitrages confirmés — Prompt 0.3 (14 novembre 2026)

- **Un seul Administrateur central** pour les dix plateformes, avec une identité Auth dédiée, hors memberships applicatifs.
- Son accès transversal est **métadonnées uniquement** : état des plateformes, comptes et rattachements administratifs, rôles, appareils/installations, abonnements, paramètres, journaux et agrégats autorisés. Il ne lit jamais les lignes de transactions métier détaillées, ni les profils personnels détaillés ou le contenu des tickets de support.
- Il peut effectuer les opérations d'administration autorisées ; toute mutation doit être auditée (acteur, action, cible, application/organisation/lieu si applicable, horodatage), sans stocker le contenu métier dans le journal.
- Les utilisateurs ordinaires ont **un compte distinct par plateforme**. Une identité Auth ordinaire ne peut être liée qu'à une seule application. Les données, rôles et memberships restent cloisonnés par application.
- Le compte de l'Administrateur central est distinct des dix comptes applicatifs et ne doit pas recevoir de memberships utilisateurs dans les applications.

### Correctifs candidats ajoutés
- supabase/drafts/0004_prompt_0_3_central_admin_identity_audit.sql : table d'habilitation centrale à un seul administrateur actif, sémantique globale de is_admin(), restriction des profils/tickets personnels, index d'unicité une plateforme par identité et trigger d'audit des mutations administratives.
- supabase/local-tests/0004_prompt_0_3_central_admin_assertions.sql : tests d'accès métadonnées sur les dix apps, refus des transactions détaillées, compte central sans claim applicatif, identité ordinaire limitée à une app et journalisation des mutations.
- Le test de contextualisation 0003 a été ajusté pour utiliser deux identités Auth distinctes Kiosko/Campus237.
- Le test RLS 0002 identifie désormais l'admin via l'habilitation centrale et non par un rôle platform_admin local.
- Workflow .github/workflows/prompt-03-rls.yml étendu pour appliquer la candidate 0004 et exécuter les nouveaux tests dans PostgreSQL 17 éphémère.

**Statut inchangé avant preuve CI :** ces fichiers sont des candidates de conception/test. Attendre le résultat du workflow déclenché par les commits récents ; corriger tout échec avant de considérer ces règles validées. Aucune migration n'est appliquée au Supabase NAXA réel.

### Durcissement de l'affectation applicative et de l'audit
- La candidate 0004 impose client_app_access.status='granted' et la concordance du claim signé dans les helpers de portée ; l'accès à une application ne repose donc plus sur le seul membership.
- Un index unique interdit plusieurs affectations applicatives à une même identité Auth ordinaire.
- Le rôle local platform_admin est neutralisé ; l'unique admin global vient de family_admins.
- Le journal audit_events est protégé contre UPDATE/DELETE ; les mutations administratives ciblées génèrent des événements de métadonnées.
- La CI PostgreSQL 17 doit encore confirmer ces derniers changements. L'index unique et les règles d'identité ne doivent pas être appliqués au backend réel avant inventaire des comptes existants et plan de correspondance.


## Mise à jour — audit global des sources et priorité de construction (20 novembre 2026)

- Le dépôt source historique `audreymendomo23-netizen/NAXA` a été réintégré dans la cartographie des actifs réutilisables. Il contient le système NAXA Security (passerelle locale, ONVIF, événements, accès vidéo, enregistrement local, horodatage et politiques de haute surveillance), mais plusieurs lots restent partiels/bloqués par matériel, Android natif et pilote physique.
- Les capacités NAXA existantes (identité, rôles, caisse, paiements/SMS, notifications, messagerie, comptabilité, BI/IA, prestations) sont des sources à auditer et adapter ; leurs tables et permissions liées à l'ancienne Pharmacie/aux partenaires ne doivent pas être copiées directement dans les applications Famille.
- Première application recommandée : **NAXA SERVICES**, avec J0 fondation puis J1 cœur opérationnel, J2 agenda/équipe, J3 pilotage/IA. Le cahier de charge et les prompts 4.1–4.7 sont disponibles dans le dépôt.
- JOBLY Partner, parrainage, KYC partenaire, attribution, commissions de referral et payout demeurent exclus.
- Rapport détaillé : `docs/audits/AUDIT_GLOBAL_SOURCES_NAXA_FAMILLE_ET_PRIORISATION_2026-11-20.md`.
- Aucune application métier, migration Supabase, configuration Production, publication APK ou déploiement n'a été modifié.
