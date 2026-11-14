# Audit transversal — Prompts 0.3 à 0.13

Date : 14 novembre 2026  
Dépôt : `audreymendomo23-netizen/FAMILLE-NAXA` — branche `main`  
Référence de départ : commit `72ac2b1a2f0ef058818425299ae22e336b4df521`

## 1. Périmètre et méthode

Source normative historique : `7 famille naxa/02-prompts/00-socle-commun.md`, sections PROMPT 0.3 à PROMPT 0.13. Les documents adaptés 0.3 et 0.4 sous `docs/architecture-360/` précisent les adaptations Famille.

L'audit est transversal : les prompts sont traités comme un programme commun cohérent, avec dépendances explicites, et non comme onze chantiers isolés. La preuve finale reste individualisée par critère et par prompt.

Décisions actuelles qui prévalent sur le texte historique :
- 10 applications : Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA Hotel, Campus237, NAXA Security, GrillaD (et non 7).
- Android natif Kotlin/Compose et Web responsive/PWA autonomes ; aucune WebView/Capacitor.
- Un backend Supabase NAXA commun, sans duplication des identités et organisations canoniques.
- GitHub Actions sont autorisées pour les contrôles et builds. L'ancienne interdiction CI du texte historique est obsolète.
- Aucun déploiement, migration réelle, publication APK ou modification Production sans autorisation distincte et explicite.
- Travail sur `main`, sans branche/PR ; pas de secret dans le dépôt public.

## 2. État observé du dépôt

### Structure
- Les dix répertoires `apps/<app>/` existent, mais les répertoires Android et Web/PWA attendus par le workflow `apps/android/<app>/build.gradle.kts` et `apps/web/<app>/package.json` sont absents.
- Vérification physique par le workflow : les 20 manifests manquent ; le job `app-build-readiness` échoue donc avant tout build.
- `packages/README.md` dit explicitement qu'aucun package commun n'est implémenté.
- `infra/README.md` est un emplacement réservé, sans infrastructure applicative.
- Le workflow GitHub Actions actuel ne couvre que le SQL 0001, les assertions 0.3 et l'inventaire des manifests ; aucun contrôle des prompts 0.4 à 0.13.
- Le répertoire `supabase/migrations/` ne contient que `0002_famille_core_rls.sql`; le socle 0001 reste dans `supabase/drafts/`, donc aucune séquence autonome de migrations candidates n'est constituée.
- Les dossiers des applications contiennent au minimum des README de cadrage ; aucun projet Android/Web compilable n'a été démontré par les contrôles disponibles.

### Base et tests
- Le SQL 0001/0002 et les assertions 0.3 ont été exécutés dans PostgreSQL 17 éphémère au run GitHub Actions `43545105030`.
- Cette preuve porte sur le jeu de tests existant, pas sur les tables métier réelles des dix applications ni sur le backend Supabase NAXA.
- L'audit de compatibilité a identifié que `famille_core` n'existe pas dans le projet Supabase NAXA partagé ; les migrations Famille n'y ont pas été appliquées.
- Les défauts RLS connus restent ouverts : contexte `app_id` absent dans `is_admin()`, `outlet_ids()` et `has_organization_access()`; portée inter-app non prouvée ; EXECUTE trop large à remplacer par une liste blanche ; duplication d'identités/organisations/lieux dans le draft ; tests inter-app/org/lieu insuffisants.
- Les tests 0.3 actuels n'instancient qu'un seul contexte applicatif Kiosko pour les scénarios décrits ; ils ne prouvent pas l'isolation entre deux applications.

## 3. Matrice de statut par prompt

| Prompt | Domaine | État prouvé au commit de départ | Écart déterminant avant VERT |
|---|---|---|---|
| 0.3 | Sécurité, RLS, accès métier et abonnement | PARTIEL / NON VERT | Corriger les helpers contextualisés, abandonner le modèle identitaire parallèle, définir la matrice app/org/lieu, couvrir les vrais objets et RPC, tests négatifs complets. |
| 0.4 | Provisioning, activation, récupération, appareils et sessions | AUDIT STRUCTUREL PARTIEL / NON VERT | Fonctions de limite de session stubs et non raccordées ; paramètres Auth non lus ; provisioning admin générique non implémenté ; flux d'invitation et registry appareils spécialisés à intégrer proprement ; Android/Web absents. |
| 0.5 | Stockage local, synchronisation, conflits et tolérance offline | NON IMPLÉMENTÉ / NON VERT | Pas de modules Android/Room, sync_queue opérationnelle, moteur de reprise, horloge fiable, résolution de conflit ni tests appareil/réseau. |
| 0.6 | Notifications locales, FCM, centre et santé de l'application | NON IMPLÉMENTÉ / NON VERT | Aucun client Android, token FCM, worker d'envoi, centre de notifications ni écran Santé ; le draft SQL seul ne vaut pas implémentation. |
| 0.7 | Liens WhatsApp et briefings | NON IMPLÉMENTÉ / NON VERT | Aucun générateur wa.me, filtre PIN/OTP testé, planificateur WorkManager ni interface de briefing constatés. |
| 0.8 | Abonnements, paiements, prorata et blocage | STRUCTURE SQL CANDIDATE SEULE / NON VERT | Pas de moteur de calcul testé, workflow de paiement/validation, ledger, application des règles offline ou parcours UI. Les règles historiques doivent être rapprochées des décisions métier NAXA actuelles avant implémentation. |
| 0.9 | Design system, thèmes et i18n | NON IMPLÉMENTÉ / NON VERT | Aucun package UI/i18n, jetons, thèmes Android/Web, polices, formats ni écrans de langue. Les 3 nouvelles apps n'ont pas de thème défini dans le prompt historique. |
| 0.10 | Administration Web | NON IMPLÉMENTÉ / NON VERT | Aucun projet Web/PWA admin, MFA, tableau de bord, file de paiement, actions administratives ni tests de permissions. |
| 0.11 | Signature APK, version minimale et exports | NON IMPLÉMENTÉ / NON VERT | Aucun projet Android/build, configuration R8, validation de signature côté serveur, gestion de versions ou génération PDF/XLSX démontrée. |
| 0.12 | IA locale et assistant de données | NON IMPLÉMENTÉ / NON VERT | Aucun moteur de règles, modèles statistiques, contrat d'anonymisation, assistant offline/online ou tests de fuite de données. |
| 0.13 | Page de téléchargement et mises à jour | NON IMPLÉMENTÉ / NON VERT | Aucun site de distribution, manifestes de version/empreinte, générateur de page ou vérification de mise à jour intégrée. |

Aucun des prompts 0.3 à 0.13 n'est VERT à la date de cet audit.

## 4. Contradictions à résoudre une seule fois pour tout le programme

1. **7 apps contre 10 apps** : le texte source 0.1–0.13 décrit sept applications et sept thèmes ; l'architecture actuelle en compte dix. Tous les schémas, contrats, catalogues, notifications, versions, thèmes, prix, droits et builds doivent porter les dix codes.
2. **Android uniquement contre Android + Web/PWA** : le texte historique ne décrit que les parcours Android ; les parcours Web/PWA doivent être définis sans prétendre réutiliser des garanties Android (Keystore, WorkManager, réception SMS).
3. **Anciennes règles financières contre règles NAXA actuelles** : les montants, promotions, essais, prorata, tolérances et délais du prompt 0.8 ne doivent pas être codés avant une table de décision conciliant les règles NAXA validées et les offres propres à chaque application.
4. **Une transaction issue d'un SMS immuable** : distinguer capture brute locale, événement financier déclaré, preuve vérifiée et correction compensatoire ; ne jamais transformer une donnée SMS en paiement confirmé par simple lecture.
5. **Conflit “premier enregistrement gagne”** : cette règle ne convient pas universellement aux ventes, paiements, inventaires ou opérations financières. Définir une politique par agrégat métier, avec idempotence, version/sequence et compensation ; aucune écriture financière ne doit être silencieusement écrasée.
6. **7/14 jours offline** : le serveur doit décider de l'état d'abonnement et fournir un temps signé/fiable ; l'horloge locale seule ne peut ni prolonger un droit ni détruire les données.
7. **Notifications haute priorité** : FCM n'est pas une garantie d'exécution ou de livraison immédiate. Le statut “reçu/lu/action faite” doit être distingué et mesuré côté client.
8. **WhatsApp** : génération de liens et partage volontaire seulement ; aucun envoi automatisé non autorisé, aucun PIN/OTP, aucun SMS sortant payant.
9. **MFA Admin** : choisir une méthode réellement supportée par Supabase Auth et le Web, vérifier les réglages et tester le niveau AAL ; ne pas appeler “double vérification” une simple confirmation par e-mail.
10. **Signature APK** : l'empreinte seule ne prouve pas l'intégrité si la valeur attendue est récupérée d'un canal contrôlé par le même client ; validation serveur et rotation des certificats doivent être conçues.
11. **IA “gratuite”** : aucune dépendance à une API gratuite non contractuelle ; mode local prioritaire, données minimisées et anonymisation testée, aucune décision financière ou opérationnelle autonome.
12. **Publication** : le prompt 0.13 prépare uniquement ; la page, les APK et les mises à jour restent non publiées tant qu'une autorisation distincte n'est pas donnée.

## 5. Stratégie de traitement simultané

Les domaines seront développés en pistes coordonnées sur les mêmes contrats, sans attendre la clôture complète d'un prompt pour commencer l'autre :

- **Piste A — identité, permissions, paiements et audit** : 0.3 + 0.4 + fondations 0.8 + contrôle d'accès 0.10 + validation de versions 0.11/0.13.
- **Piste B — noyau mobile et données** : contrats communs, Room/SQLite, journal immuable, synchronisation et conflits 0.5 ; intégration notifications/briefings 0.6/0.7.
- **Piste C — expérience multi-plateforme** : dix modules Android natifs, dix Web/PWA, design system et i18n 0.9 ; administration Web 0.10.
- **Piste D — sécurité et distribution** : signature, builds reproductibles, exports, catalogue de versions, page de distribution locale non publiée 0.11/0.13.
- **Piste E — intelligence** : moteur déterministe et explicable d'abord, assistant local puis connecteur externe strictement anonymisé 0.12.

Chaque piste partage un même modèle d'identité, d'événements, d'audit, de synchronisation et de versionnement. Les tests PostgreSQL 17 et les builds locaux/CI doivent couvrir l'intégration croisée.

## 6. Critère de vert global et règles de preuve

Un prompt est VERT seulement si :
- ses exigences sont reliées à des fichiers/contrats exacts ;
- l'implémentation existe dans les cibles applicables (Android natif et Web/PWA lorsque requis) ;
- tests positifs, négatifs, sécurité et non-régression sont exécutés et réussis ;
- les résultats sont reproductibles et attachés au commit ;
- aucun écart critique ou contradiction métier ne reste ouvert ;
- la documentation et la continuité reflètent exactement les preuves.

Le vert global 0.3–0.13 exige les onze statuts verts et les tests d'intégration entre pistes. Un manifeste présent, un SQL syntaxiquement valide, un build isolé ou un ancien run CI ne suffisent pas.

## 7. Limites d'autorisation

Ce travail documentaire et les modifications de fichiers du dépôt ne constituent pas une autorisation de :
- modifier le projet Supabase NAXA réel ;
- appliquer une migration ou du DDL/DML sur un environnement partagé ;
- modifier les paramètres Auth, les utilisateurs ou les sessions ;
- déployer une Edge Function, un site ou une API ;
- publier une APK ou une release.

Toute opération réelle sur le backend, toute publication et tout déploiement attendent une autorisation explicite distincte. Les tests sur PostgreSQL 17 éphémère et les builds locaux/CI sont autorisés selon les décisions actuelles du projet.

## 8. Point de reprise

Commencer immédiatement la correction coordonnée du socle 0.3–0.13 :
1. figer les contrats communs et la matrice des dix applications ;
2. refondre 0001/0002 en migrations candidates additives raccordées au backend NAXA, sans identité/organisation/lieu dupliqués ;
3. établir les contrats d'événements, audit, synchronisation, notifications, abonnements et versions ;
4. construire les dix squelettes Android natifs et dix Web/PWA compilables, puis les packages communs nécessaires ;
5. implémenter les flux transverses en parallèle sur ces contrats et couvrir chaque critère par test ;
6. mettre à jour ce rapport et `docs/CONTINUITE_FAMILLE_NAXA.md` après chaque lot vérifié.

État au départ : **0.3–0.13 : 0 VERT / 11**.