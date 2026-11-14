# Audit Prompt 0.6 — Notifications

Date : 14 novembre 2026
Dépôt : audreymendomo23-netizen/FAMILLE-NAXA, branche main
Source historique : audreymendomo23-netizen/NAXA/7 famille naxa/02-prompts/00-socle-commun.md, section PROMPT 0.6.
Nature : lecture GitHub du code et des documents disponibles. Aucun changement Supabase, aucune migration, aucun déploiement ou publication.

## 1. Conclusion

**Prompt 0.6 : AUDIT INITIAL PARTIEL — NON VERT.**

Des briques Android de notifications locales existent déjà dans le package commun : cinq canaux Android, permission POST_NOTIFICATIONS déclarée dans le manifeste de la bibliothèque, fonction de publication locale et planification de briefings par WorkManager.

Une fonction Web prépare des liens WhatsApp wa.me en filtrant PIN/OTP et séquences numériques suspectes.

Mais aucun élément inspecté ne prouve le système complet :
- aucun service FCM, enregistrement/rotation/révocation de jeton ou fonction serveur d'envoi identifié ;
- aucun centre persistant lu/non lu avec actions rejouables identifié ;
- anti-doublon métier, heures calmes, préférences, réarmement d'alertes non démontrés ;
- écran Santé de l'application et assistant de configuration non démontrés ;
- statuts fournisseur/livraison/lecture/action non démontrés ;
- tests de notification ciblés non identifiés dans les chemins inspectés.

## 2. Preuves de code positives

### Android — module partagé

Fichiers lus :
- packages/core-android/src/main/java/cm/naxa/core/notifications/NotificationChannels.kt
- packages/core-android/src/main/java/cm/naxa/core/notifications/BriefingScheduler.kt
- packages/core-android/src/main/java/cm/naxa/core/notifications/BriefingWorker.kt
- packages/core-android/src/main/AndroidManifest.xml
- packages/core-android/build.gradle.kts

Constats :
- NotificationChannels.kt définit critical, operations, subscription, information, ai_coaching.
- create(context) crée les cinq canaux Android O+ avec importances HIGH/DEFAULT/LOW.
- post(...) vérifie POST_NOTIFICATIONS sur Android 13+ et capture SecurityException.
- BriefingScheduler planifie un briefing avec WorkManager et un travail unique par canal.
- BriefingWorker publie localement puis reprogramme le prochain briefing.
- Le manifeste de la bibliothèque déclare android.permission.POST_NOTIFICATIONS.
- Dépendances Android incluent WorkManager 2.9.1 et androidx.core 1.15.0.

Limites et points à tester :
- les libellés de canaux sont actuellement codés en dur en français dans le Kotlin ; cela contredit la règle FR/EN sans texte utilisateur en dur ;
- la permission est déclarée dans le manifeste de la bibliothèque, mais le manifeste final fusionné de chacune des dix applications et le parcours de demande runtime ne sont pas prouvés ;
- aucun stockage de préférences/heures calmes, déduplication par clé métier ou état de réarmement n'est visible dans ces fichiers ;
- le worker de briefing ne constitue pas un moteur de notification métier ou un transport push ;
- aucun test Android de ces comportements n'a été identifié dans les chemins inspectés.

### Android — intégration application

Le manifeste Kiosko inspecté :
apps/android/kiosko/src/main/AndroidManifest.xml

Il déclare une activité Launcher et le label d'application, sans déclaration locale visible de POST_NOTIFICATIONS. La permission peut être fusionnée depuis la bibliothèque ; le manifeste fusionné et le comportement runtime restent à vérifier. Ne pas conclure à une absence effective de permission avant cette vérification.

### Web — WhatsApp préparé

Fichier lu :
packages/core-web/src/whatsapp/safeMessage.js

- isSafeMessage rejette les messages vides, mentions PIN/OTP/codes secrets et séquences numériques de 4 à 8 chiffres.
- buildWaMeUrl valide un numéro E.164 en chiffres et construit un lien wa.me avec texte encodé.
- C'est une préparation de message initiée par l'utilisateur, pas un envoi WhatsApp automatique.
- Le filtrage numérique est volontairement conservateur ; il peut rejeter certains contenus métier légitimes et doit être testé avec des cas FR/EN. Ne pas l'affaiblir au point de laisser passer PIN/OTP.

## 3. Composants non démontrés

| Exigence | État |
|---|---|
| Notifications locales | Partiel : API locale présente |
| 5 canaux Android | Présents, localisation à corriger |
| Push FCM data | Non trouvé dans les chemins inspectés |
| Jeton FCM par appareil | Non démontré |
| Rotation et révocation du jeton | Non démontrées |
| Fonction serveur d'envoi | Non démontrée |
| Statuts création/envoi/réception/lecture/action | Non démontrés |
| Centre de notifications lu/non lu | Non trouvé |
| Actions rejouables idempotentes | Non démontrées |
| Anti-doublon événement | Non démontré |
| Heures calmes et préférences | Non démontrées |
| Réarmement seuils | Non démontré |
| Écran Santé de l'appli | Non trouvé |
| Assistant configuration premier lancement | Non trouvé |
| Messages WhatsApp préparés | Présents côté Web |
| Tests locaux Prompt 0.6 | Non identifiés |

« Non démontré » signifie que le composant n'a pas été prouvé par les chemins lus ; ce n'est pas une preuve universelle d'absence dans tout le dépôt.

## 4. Risques et causes racines probables à confirmer

1. Les canaux Android et briefings ont été construits avant le système de notifications complet : confusion entre affichage local et cycle de vie d'une notification.
2. Le push n'est pas raccordé à un registre de jetons et à un destinataire autorisé démontrés.
3. L'absence de centre persistant sépare l'alerte système de son historique et de ses actions métier.
4. La logique anti-doublon/réarmement n'a pas de contrat partagé démontré.
5. Les permissions Android sont déclarées au niveau bibliothèque, mais le parcours de consentement et la santé par appareil ne sont pas prouvés.
6. Les libellés des canaux codés en dur empêchent une localisation cohérente FR/EN.

## 5. Règles de correction

- Préserver les canaux, la publication locale, WorkManager et le helper WhatsApp existants.
- Ajouter un moteur commun et des adaptateurs, pas dix implémentations indépendantes.
- FCM reste un transport ; Supabase NAXA reste l'autorité pour les droits, le contenu, le centre et les actions.
- Ne jamais embarquer de secret serveur dans les applications.
- Une notification n'accorde aucun droit ; revalider l'action côté serveur.
- Ne jamais confondre acceptation FCM, réception sur appareil, lecture et action.
- Le paiement, l'abonnement ou un solde ne peuvent jamais être modifiés par une notification ou par l'IA seule.
- Respecter les règles de confidentialité : aucun PIN/OTP, SMS brut ou secret dans le push.
- Modifier le générateur scripts/bootstrap-foundations.mjs si des fichiers Android générés changent.

## 6. Prochaine passe précise

1. Inventorier le dépôt entier pour rechercher FCM, jetons, notifications Web, centre, préférences et tests ; vérifier les manifestes fusionnés et le bootstrap.
2. Cartographier les ressources backend NAXA existantes (appareils, notifications, préférences, tokens, journaux) en lecture seule, sans créer de tables concurrentes.
3. Définir le contrat partagé événement/notification, clé d'idempotence, états et actions.
4. Construire la matrice des cinq canaux, préférences, heures calmes et exceptions critiques.
5. Concevoir le stockage et la fonction d'envoi en SQL candidat, puis tester PostgreSQL 17 éphémère ; aucune migration Production.
6. Implémenter ensuite le centre, FCM et l'écran Santé, avec tests Android/Web et dix applications.

## 7. État global

- Prompt 0.6 : audit initial PARTIEL / NON VERT.
- Prompt 0.5 : PARTIEL / NON VERT.
- Prompt 0.4 : PARTIEL / NON VERT.
- Prompt 0.3 : PARTIEL / NON CLOS.
- Aucun DDL/DML, changement ACL, configuration FCM, migration Supabase, déploiement ou publication effectué.
