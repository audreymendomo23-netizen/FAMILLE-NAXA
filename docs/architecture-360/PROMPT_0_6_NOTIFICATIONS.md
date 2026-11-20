# PROMPT 0.6 — Notifications — Famille NAXA

> Adaptation du Prompt 0.6 historique « Notifications ».
> Source : [NAXA — 00-socle-commun.md](https://github.com/audreymendomo23-netizen/NAXA/blob/main/7%20famille%20naxa/02-prompts/00-socle-commun.md), version 1.0 du 31 octobre 2026.
> Statut : cadrage adapté et audit initial partiel ; système complet non implémenté. Ce document n'autorise aucune migration Production ni aucun déploiement.

## 1. Objectif et périmètre

Construire un système de notifications partagé par les dix applications Famille NAXA : Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA Hotel, Campus237, NAXA Security et GrillaD.

Cibles : Android natif Kotlin/Compose et Web responsive/PWA. Un seul backend Supabase NAXA existant ; réutiliser les identités, appareils, organisations, lieux, abonnements, journaux et mécanismes déjà présents. Ne pas créer un backend ni un registre d'appareils parallèle.

## 2. Canaux fonctionnels

Quatre voies gratuites ou sans coût d'envoi NAXA :
1. Notifications locales Android/Web quand le contexte et les permissions le permettent.
2. Push FCM via messages de données, avec traitement applicatif contrôlé.
3. Messages WhatsApp préparés sous forme de lien explicite wa.me ; aucun envoi automatique ni service WhatsApp payant.
4. Centre de notifications intégré : lu/non lu, historique, actions disponibles et rejouables de façon idempotente.

Aucun SMS sortant payant.

## 3. Canaux Android

Créer ou préserver les cinq canaux système :
- Critique ;
- Opérations ;
- Abonnement ;
- Information ;
- Coaching IA.

Règles :
- l'utilisateur peut configurer les préférences par type, mais ne peut pas neutraliser les alertes critiques obligatoires ;
- heures calmes pour les notifications non critiques ;
- anti-doublon par clé d'événement stable ;
- une alerte de seuil est réarmée uniquement après retour confirmé à un état normal, puis peut se déclencher à nouveau lors d'un nouveau franchissement ;
- les niveaux de priorité et l'importance Android sont documentés par catégorie ;
- gérer explicitement les permissions Android 13+, refus, révocation et paramètres constructeur ;
- aucun contournement des réglages de l'utilisateur ni promesse de livraison garantie par Android/FCM.

## 4. Jetons FCM et service serveur

- Enregistrer un jeton FCM par installation/appareil et application, lié à l'identité et au périmètre autorisés côté serveur.
- Traiter automatiquement la rotation du jeton et invalider l'ancien.
- Supprimer/désactiver le jeton à la déconnexion, à la révocation de l'appareil ou à la fermeture de session selon la politique retenue.
- Ne jamais placer de clé serveur FCM, secret Supabase ou service_role dans une application.
- Préparer une fonction serveur d'envoi non déployée, autorisée côté serveur, qui vérifie app_id, organisation, lieu, destinataire, consentement/préférences et statut de l'appareil.
- Statuts d'une notification : créée, envoyée au fournisseur, acceptée/reçue lorsque le fournisseur le confirme, lue dans l'application, action effectuée, échec/réessai. Ne jamais présenter un accusé fournisseur comme une preuve de lecture humaine.
- Retry borné, backoff, expiration, idempotence et gestion des jetons invalides.
- Les messages FCM ne contiennent que le minimum nécessaire ; charger le détail sensible après authentification.

## 5. Centre de notifications

Le centre est persistant côté serveur et consultable sur les appareils autorisés :
- liste paginée, filtres et états lu/non lu ;
- clé d'événement unique et déduplication ;
- actions explicites, autorisées et rejouables sans double effet ;
- journal d'exécution des actions et résultat ;
- synchronisation hors connexion avec l'architecture du Prompt 0.5 ;
- séparation stricte application/organisation/lieu/utilisateur ;
- rétention et suppression documentées ; ne pas supprimer les notifications critiques ou preuves d'audit sans politique approuvée.

Une notification ne confère jamais un droit. Toute action rejouée revalide les permissions et l'état métier côté serveur.

## 6. Santé de l'application et configuration initiale

Écran « Santé de l'appli » :
- permission de notifications et état effectif ;
- restrictions batterie / arrière-plan pertinentes ;
- disponibilité du push et dernier jeton enregistré, sans afficher le jeton brut ;
- dernière synchronisation connue ;
- état réseau et paramètres système utiles.

Assistant de premier lancement :
- expliquer chaque permission avant la demande système ;
- proposer les étapes adaptées à la version Android et, si vérifiable, à la marque ;
- permettre de terminer sans permission non indispensable ;
- ne pas prétendre qu'un réglage constructeur est activé sans vérification ;
- offrir un accès ultérieur aux instructions.

## 7. Sécurité, confidentialité et règles NAXA

- Aucun PIN, OTP, code secret ou contenu de SMS contenant ces secrets ne doit être lu, stocké, transmis ou affiché.
- Aucun SMS brut ni numéro complet n'est transmis à une IA ou à un service externe.
- Les notifications d'abonnement/paiement ne valident jamais un paiement et ne modifient jamais un solde. Elles signalent un état vérifié par les mécanismes métier existants.
- L'IA peut proposer une explication ou un coaching ; l'humain ou le workflow métier autorisé décide.
- Minimiser les données sur écran verrouillé ; préférer un message neutre pour les contenus sensibles.
- RLS et autorisation serveur s'appliquent à chaque lecture, envoi et action.
- Ne pas réutiliser public.appareils hors de son périmètre métier sans compatibilité démontrée ; ne pas réutiliser suivi_user_devices comme registre générique.
- Pas de clé privilégiée dans les bundles Android/Web.

## 8. Tests obligatoires

Tests locaux et PostgreSQL 17 éphémère, plus tests Android ciblés :
1. même événement reçu deux fois : une seule notification visible et une seule entrée centre ;
2. même identifiant avec contenu différent : rejet ;
3. permission accordée, refusée puis révoquée ;
4. retour réseau et notifications locales hors connexion ;
5. rotation et invalidation jeton FCM ;
6. déconnexion/révocation d'appareil ;
7. statut fournisseur distinct de la lecture humaine ;
8. action rejouée plusieurs fois : un seul effet métier ;
9. action devenue interdite entre notification et clic : refus côté serveur ;
10. heures calmes et exceptions critiques ;
11. préférence utilisateur respectée, sauf alertes critiques obligatoires ;
12. retour à la normale puis nouveau franchissement : alerte réarmée ;
13. isolation inter-app, inter-organisation, inter-lieu et inter-utilisateur ;
14. charge utile push sans donnée sensible ;
15. centre accessible hors connexion avec synchronisation ultérieure ;
16. Android 13+ et versions supportées antérieures ;
17. absence de clé privilégiée dans les APK et bundles Web.

Chaque test doit préciser préconditions, scénario, résultat attendu et preuve. Tout test non exécuté reste NON EXÉCUTÉ.

## 9. Architecture et livrables

- Contrats partagés d'événement et de notification dans packages/contracts.
- Module Android partagé dans packages/core-android, sans duplication dans les dix apps ; le générateur scripts/bootstrap-foundations.mjs doit rester la source de vérité de tout fichier généré.
- Centre et adaptateurs Web/PWA dans les packages communs Web existants.
- Schéma SQL et fonctions serveur proposés sous forme de migrations ordonnées non appliquées.
- FR/EN dans les fichiers de langue, aucun texte utilisateur en dur.
- Tests automatisés, guide d'intégration et fichier de passation.
- Réutiliser NotificationChannels.kt, BriefingScheduler.kt, BriefingWorker.kt et le générateur existants après audit ; ne pas écraser les briques existantes.

## 10. Gouvernance

Méthode : audit → contradiction → cause racine → correction → test/preuve → documentation → état.

Travailler sur main uniquement, sans branche ni PR. GitHub Actions autorisées. Aucun déploiement, publication APK, migration appliquée, modification du Supabase réel, configuration FCM Production ou déploiement Edge Function sans autorisation explicite distincte.

Ne jamais déclarer le Prompt 0.6 vert avant la couverture des dix applications, les tests, les preuves d'isolation et la vérification des parcours Android/Web.
