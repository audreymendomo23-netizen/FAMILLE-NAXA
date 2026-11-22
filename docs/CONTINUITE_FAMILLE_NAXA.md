# Continuité — Famille NAXA
Dernière mise à jour : 22 novembre 2026 — complément NAXA HOTEL
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


## Mise à jour — démarrage NAXA SERVICES et authentification sans OTP/e-mail (20 novembre 2026)

- Le premier produit à construire reste **NAXA SERVICES**. Le premier sous-chantier J0 est le parcours de création, activation, connexion, appareil, session, révocation et récupération.
- Objectif demandé : aucun OTP, SMS d'authentification, e-mail, boîte mail, magic link ou inscription libre.
- Option recommandée à tester : identifiant d'accès généré propre à NAXA Services + mot de passe ; alias Auth technique opaque et créé/confirmé par le backend Admin ; Supabase Auth conserve la vérification de mot de passe et les sessions/JWT.
- Le téléphone reste une coordonnée de contact, pas la clé Auth primaire, afin de maintenir des identités d'accès séparées par application et d'éviter la contrainte de recyclage des numéros.
- Récupération sans e-mail/OTP : procédure interne contrôlée par administration, preuve d'identité hors bande, reset côté serveur, révocation des sessions à risque et audit. La récupération autonome sans canal de confiance n'est pas promise.
- À prouver localement : création Admin/confirmation sans message, compatibilité de l'alias avec GoTrue, login par mot de passe, prévention d'énumération/force brute, séparation par application et révocation des sessions/appareils.
- Contradiction repérée : Prompt 0.2 indique une identité Auth partagée ; l'arbitrage ultérieur demande des identités séparées. Harmonisation documentaire à réaliser après preuve locale ; pas de SSO transversal par défaut.
- Le cahier NAXA Services et Prompt 0.4 mentionnent encore récupération e-mail/WhatsApp et téléphone comme identifiant. Ils ne sont pas réécrits avant le test et la validation du schéma cible.
- Design détaillé : `docs/architecture-360/DECISION_AUTHENTIFICATION_INTERNE_SANS_OTP_EMAIL.md`.
- Aucun code applicatif, configuration Auth réelle, migration, session de production, déploiement ou APK n'a été modifié.


## Mise à jour — première construction NAXA SERVICES (20 novembre 2026)
- Architecture documentée pour PME autonome, responsable multi-emplacements dans un site et Promoteur multi-sites autonomes.
- Source Android Kotlin/Compose : connexion interne, récupération administrée, changement initial, « rester connecté » avec coffre Android Keystore et navigation ERP.
- Source Web/PWA : tableau de bord, 16 modules ERP, pages structure/réseau et formulaires d'aperçu en mémoire de session.
- Source Edge Function Auth, contrat API, draft SQL et contrat RLS préparés sans déploiement ni application de migration.
- « Rester connecté » est décoché par défaut ; les jetons sont chiffrés uniquement si l'utilisateur l'active. Le mot de passe n'est jamais sauvegardé.
- Statut non vert complet : builds locaux non exécutés (résolution réseau indisponible), alias GoTrue non prouvé, fonction non déployée, provisioning/reset Admin incomplets, policies RLS détaillées et recettes métier non exécutées. Les opérations ERP restent à connecter aux repositories et à la synchronisation.
- Logo : SVG reconstruit depuis la spécification écrite ; original binaire spécifique non vérifié dans cette passe.
- Aucun changement de Supabase Replay/Production, aucun déploiement ni APK publiée.


### Complément Auth / RLS — 20 novembre 2026
- L'Edge Function source gère désormais aussi l'enrôlement d'un membre dans un scope autorisé, la finalisation d'une récupération après contrôle d'identité et la révocation d'un appareil.
- Les refresh tokens sont liés côté serveur à leur hash SHA-256, à l'installation et au session_id du JWT ; aucun refresh token en clair n'est stocké en base.
- Le draft SQL comprend maintenant les helpers et policies RLS par organisation, site et poste, ainsi que l'exigence d'une session d'appareil active pour ns_current_account_id().
- Limites inchangées : alias GoTrue non prouvé, fonction non déployée, SQL non appliqué, tests RLS/session non exécutés, écrans de provisioning et de traitement de recovery à intégrer à l'interface responsable.


---

## Complément de continuité — NAXA HOTEL 360°, portail QR, marketplace et tarification
**Mise à jour : 22 novembre 2026**  
**Référence du cahier :** 7 famille naxa/01-cahiers-des-charges/07-naxa-hotel.md  
**Statut :** cadrage fonctionnel ajouté ; grille tarifaire proposée [P] ; aucun développement ou déploiement certifié par cette mise à jour documentaire.

### 1. Baseline fonctionnelle conservée

Le projet NAXA HOTEL conserve le périmètre 360° de 18 domaines (administration, PMS, commercial/groupes/événements, distribution/revenue management, CRM/expérience, housekeeping, restauration/bar/room service via ZIPPLE, services via NAXA SERVICES, économat/stocks, maintenance/patrimoine, RH, finance/comptabilité, caisse/paiements, conformité/audit, sécurité NAXA SECURITY, portail de séjour, énergie/eau/environnement, direction/BI/IA). Les deux ajouts précédemment identifiés restent inclus : module 19 Livechat/communication professionnelle et module 20 Support Client NAXA HOTEL.

Aucun module antérieur n'est supprimé. Le détail opérationnel et la recette sont consignés dans l'addendum du cahier hôtel.

### 2. Portail client par QR code — aucun téléchargement d'application

Décision fonctionnelle : les clients d'un hôtel ne sont pas utilisateurs de l'application NAXA HOTEL. Ils n'installent aucune application et ne créent aucun compte. Un QR code par chambre ouvre un portail Web de séjour limité à exactement quatre entrées :

1. catalogue des services proposés par l'hôtel ;
2. catalogues des utilisateurs professionnels ZIPPLE et NAXA SERVICES, uniquement pour les services que l'hôtel n'offre pas ;
3. lien vers la page publique Marketplace LOYABLE ;
4. lien vers la page publique de la pharmacie NAXA pour rechercher un médicament et consulter sa disponibilité.

Aucun autre menu, chat client, fidélité, avis, publicité, réservation dans le portail QR, caméra, tableau de bord, profil ou espace client ne doit être ajouté. Les modules Livechat et Support restent des fonctions professionnelles hors du portail QR.

Le QR doit être lié côté serveur à l'hôtel et à la chambre via un identifiant opaque/révocable. Aucune identité, date de séjour, réservation, folio ou donnée personnelle n'est encodée directement dans le QR. Les liens LOYABLE et pharmacie NAXA sont des liens externes vers leurs pages publiques réelles, à configurer ; ne pas inventer leurs URL.

### 3. Restaurant/bar : commande client par QR avec ZIPPLE

Si l'hôtel exploite un restaurant, un bar ou les deux, la commande par QR est intégrée, sans application client :
- QR de chambre pour room service si activé ;
- QR sur table restaurant ;
- QR dans les espaces/tables du bar ;
- menus, prix, disponibilités et tickets possédés par ZIPPLE ;
- commandes du restaurant et du bar séparées et routées vers les équipes/cuisines correspondantes ;
- références de commande et statuts consultables par le client via une page Web légère ;
- paiement dans ZIPPLE ou demande d'imputation au folio NAXA HOTEL selon les droits et validations de l'établissement ;
- aucune imputation automatique sur chambre à partir d'un QR partagé ; séjour ouvert, validation et idempotence serveur obligatoires.

ZIPPLE reste source de vérité pour catalogue, recettes, stock, préparation, caisse et paiement. NAXA HOTEL reste source de vérité pour séjours, chambres et folios. L'échange est réalisé par API/événements versionnés ; aucune écriture directe inter-applications. Le moteur QR de commande restaurant/bar est inclus dans les deux formules hôtelières proposées ; aucun supplément QR distinct n'est proposé dans cette grille.

### 4. Marketplace LOYABLE — hôtellerie et réservations

Une catégorie publique « Hébergements et établissements hôteliers » est distincte de la location résidentielle.

- Hôtel client NAXA HOTEL : publication et accès à la réservation hôtelière LOYABLE gratuits si l'abonnement NAXA HOTEL est actif. Les annonces sont créées/synchronisées à partir des données autorisées du PMS. NAXA HOTEL est l'autorité pour tarifs, inventaire, disponibilités et confirmation ; LOYABLE est l'autorité pour publication et découverte publique.
- Hôtel externe qui n'utilise pas NAXA HOTEL : 10 000 FCFA par mois pour l'accès à la publication et à la réservation sur LOYABLE. L'intégration, la vérification, la création et la gestion de l'annonce passent par l'administration centrale de l'entreprise ; pas d'auto-inscription ni d'auto-publication pour ce segment. Les demandes de réservation doivent être vérifiées et confirmées par l'hôtel. En absence de connecteur PMS, les disponibilités sont administrées manuellement/déclarées et horodatées.

Ce tarif hôtel externe ne s'applique pas par annonce et ne remplace pas le modèle LOYABLE classique bailleur (1 000 FCFA × chambres actives/en gestion/mois). Le tarif annuel et les SLA d'administration des hôtels externes restent à préciser.

### 5. Intégration NAXA SECURITY dans les deux offres hôtelières

Le socle NAXA SECURITY est inclus dans Essentiel et Premium. Premium étend les capacités, quotas, périmètres et analyses. L'hôtel ne perd pas les fonctions de sécurité de base en Essentiel. Les intégrations dépendent des caméras, capteurs, centrales, appareils et réseaux réellement compatibles. NAXA ne fournit aucun matériel, câblage, installation physique ou service humain de télésurveillance. Les systèmes locaux certifiés d'alarme et de protection incendie doivent continuer à fonctionner indépendamment du cloud.

### 6. Grille NAXA HOTEL proposée — modèle LOYABLE [P]

La proposition est calculée par organisation/promoteur sur la quantité réelle de chambres actives/en gestion, avec une facture détaillée et un minimum de facturation :

| Formule | Prix par chambre active et par mois | Minimum par organisation et par mois |
|---|---:|---:|
| Essentiel | 800 FCFA | 10 000 FCFA |
| Premium | 1 000 FCFA | 18 000 FCFA |

Formule :
- Essentiel = max(10 000, 800 × chambres actives)
- Premium = max(18 000, 1 000 × chambres actives)

Pour les deux formules, paiement annuel proposé = dix mensualités pour douze mois de service, conformément à FAM-020. Aucune formule de trois ou six mois. Exemples : pour 20 chambres, Essentiel 16 000 F/mois et 160 000 F/an ; Premium 20 000 F/mois et 200 000 F/an. Pour 50 chambres, Essentiel 40 000 F/mois et 400 000 F/an ; Premium 50 000 F/mois et 500 000 F/an.

Le benchmark public consulté le 22 novembre 2026 affiche notamment : Hotelia à partir de 16 200 F/mois pour l'hébergement et 27 000 F/mois pour le tout-en-un ; The African Hotelier à 25 000 F/mois (1–20 chambres) et 50 000 F/mois (21–50) ; 1412 PMS à 29 000, 39 000 et 69 000 F/mois. Ces offres ont des quotas et périmètres différents ; ces prix servent au positionnement et non à certifier une équivalence technique. Sources : https://www.hotelia.cloud/ ; https://theafricanhotelier.com/pms-hotelier/ ; https://1412pms.com/.

**Différenciation proposée :**
- Essentiel : un établissement, PMS opérationnel complet, fonctions quotidiennes, gestion de base des équipes, stocks, caisse et pilotage, QR services clients (4 entrées uniquement), QR commandes restaurant/bar via ZIPPLE, sécurité NAXA SECURITY de base, publication LOYABLE gratuite si abonnement actif.
- Premium : tout Essentiel, gestion multi-hôtels/organisation, consolidation, droits et reporting avancés, revenue management/IA supervisée, fonctionnalités ZIPPLE avancées et capacités NAXA SECURITY étendues, support prioritaire à SLA publié.

Les deux formules préservent les fonctions essentielles à l'activité et à la sécurité. Les quotas numériques, notamment chambres, utilisateurs, sites, appareils, caméras, stockage, rétention, flux et points de service, restent à chiffrer selon les coûts et capacités réels. Les frais uniques de mise en service/formation/migration et le matériel ne sont pas inclus dans le tarif mensuel proposé.

**État [P] :** tarifs à arbitrer ; les tarifs historiques du cahier NAXA HOTEL du 31 octobre ne deviennent pas des prix actuels validés. Le traitement des chambres ajoutées/retirées pendant la période (prorata immédiat ou renouvellement suivant) reste ouvert, à l'image du point ouvert dans LOYABLE.

### 7. Points ouverts et prochaines vérifications

1. Arbitrage des tarifs 800/1 000 FCFA par chambre et minima 10 000/18 000 F.
2. Confirmation de Premium multi-hôtels et du périmètre de quantité facturable à l'échelle du groupe.
3. Règle d'effet des variations du nombre de chambres en cours de période.
4. Quotas publiés et coût des capacités NAXA SECURITY/ZIPPLE.
5. SLA et horaires du support standard/prioritaire ; SLA de gestion administrative des hôtels externes LOYABLE.
6. Tarif annuel éventuel du forfait externe LOYABLE de 10 000 F/mois.
7. Tests E2E des contrats NAXA HOTEL ↔ ZIPPLE ↔ LOYABLE, des QR révoqués, des commandes répétées, de la confirmation des réservations et de l'imputation au folio.

### 8. Statut de réalisation

Cette mise à jour est documentaire. Elle ne prouve pas que le portail QR, les contrats d'API, le catalogue de prestataires, les commandes ZIPPLE, les liaisons LOYABLE, les entitlements, NAXA SECURITY ou les écrans NAXA HOTEL sont implémentés, compilés, testés ou déployés. Les applications Android/Web NAXA HOTEL restent à auditer et à construire selon les preuves techniques du dépôt. Aucune migration Supabase, publication APK ou mise en production n'est autorisée par ce document.


---

## Addendum de continuité — arbitrage tarifaire NAXA HOTEL v2.1
**Date : 22 novembre 2026**  
**Source de vérité :** `7 famille naxa/01-cahiers-des-charges/07-naxa-hotel.md`, section 24.  
**Statut :** grille tarifaire acceptée ; intégration documentaire effectuée ; aucune implémentation technique certifiée.

### 1. Décision retenue

NAXA HOTEL passe à **un abonnement unique mensuel**, sans formule Essentiel/Premium et sans paiement annuel. Cette règle est une exception propre à NAXA HOTEL par rapport à FAM-020. Les barèmes sont choisis selon le nombre de chambres actives/gérées et la présence d'un service de restauration exploité.

**Sans restaurant :**
- 1–10 : 1 500 FCFA × chambres ;
- 11–20 : max(15 000 ; 1 000 × chambres) ;
- 21–30 : max(20 000 ; 800 × chambres) ;
- 31–49 : max(24 000 ; 500 × chambres) ;
- 50 et plus : devis mensuel négocié.

**Avec restaurant/service de restauration exploité :**
- 1–10 : 2 000 FCFA × chambres ;
- 11–20 : min(24 000 ; max(20 000 ; 1 500 × chambres)) ;
- 21–30 : min(25 000 ; max(24 000 ; 1 000 × chambres)) ;
- 31–49 : forfait mensuel fixe de 26 000 FCFA ;
- 50 et plus : devis mensuel négocié.

Les montants sont en FCFA. Les planchers et plafonds empêchent une baisse de facture au changement de tranche. À partir de 50 chambres, aucun tarif automatique de 30 000 ou 40 000 FCFA ne subsiste. Les groupes multi-hôtels sont également traités sur devis mensuel consolidé.

### 2. Règles d'application

- La restauration est considérée active si l'hôtel exploite un restaurant, espace de restauration, snack ou bar avec menu/carte, commandes et caisse gérés via ZIPPLE. Un minibar simple ou un petit-déjeuner inclus sans point de vente ne suffit pas à déclencher le barème restauration.
- La quantité de chambres est déterminée au début du cycle mensuel. Les changements durables prennent effet au renouvellement suivant, sans rétroactivité.
- Le devis 50+ reste un abonnement mensuel unique ; les capacités hors standard peuvent être chiffrées séparément.
- Le socle fonctionnel, les QR client et restaurant/bar, les fonctions de base NAXA SECURITY et les conditions LOYABLE déjà définies sont conservés dans cet abonnement unique.

### 3. Références marché

Le benchmark public consulté le 22 novembre 2026 indique notamment Hotelia à partir de 16 200 FCFA/mois pour l'hébergement et 27 000 FCFA/mois pour le tout-en-un ; The African Hotelier à 25 000 FCFA/mois pour 1–20 chambres et 50 000 FCFA/mois pour 21–50 ; 1412 PMS à 29 000, 39 000 et 69 000 FCFA/mois. Sources : https://www.hotelia.cloud/ ; https://theafricanhotelier.com/pms-hotelier/ ; https://1412pms.com/. Ces offres ne sont pas strictement équivalentes ; ne pas présenter NAXA HOTEL comme systématiquement le moins cher de chaque catégorie. Le barème restauration NAXA (maximum 26 000 FCFA avant le devis 50+) se place sous les prix tout-en-un comparables cités.

### 4. Éléments toujours non réalisés ou à vérifier

La grille est une décision documentaire, pas une preuve de développement. Le calcul de facture, la photographie des chambres, l'application de l'abonnement mensuel, les paiements, les entitlements et les contrôles d'administration restent à implémenter et tester. La marge réelle et le coût de service doivent être vérifiés avant commercialisation générale. Les quotas techniques, SLA, frais de mise en service et tarifs des extensions restent à formaliser.
