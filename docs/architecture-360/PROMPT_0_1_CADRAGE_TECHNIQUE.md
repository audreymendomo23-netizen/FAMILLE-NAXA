# PROMPT 0.1 — Cadrage technique et structure du projet

**État : PROPOSITION — NON VALIDÉE PAR LE PORTEUR DE PROJET**  
**Périmètre actuel : 10 applications autonomes, Android + Web/PWA**  
**Référence NAXA consultée : branche `main`, commit `09d194b56b3c93624cff6ee83e4d2a581457d0bb`  
**Règle : aucun code applicatif à cette étape.**

## 1. Rectification du prompt historique

Le prompt source du 31 octobre 2026 décrit initialement sept applications Android (Kiosko à NAXA Hotel), un seul compte client et un backend Supabase. Le périmètre Famille NAXA actuellement retenu comprend dix applications :

1. Kiosko — Mobile Money
2. Bootik — boutiques, commerces et dépôt de gaz
3. Zipple — bars et restaurants
4. NAXA Services — pressing et coiffure
5. CotiZ — tontines
6. Loyable — gestion locative
7. NAXA Hotel — hôtellerie
8. Campus237 — ERP scolaire
9. NAXA Security — sécurité des biens et des personnes
10. GrillaD — gestion spécialisée des vendeurs de grillades

Chaque application doit être autonome en identité, installation, parcours, permissions et données métier. Les cibles demandées sont Android (APK indépendante) et Web responsive/PWA installable séparément. La distribution Android se fera depuis le site NAXA, sans Play Store.

Les anciennes contraintes qui restent pertinentes sont conservées : fonctionnement hors connexion, synchronisation différée, sécurité, aucune lecture/stockage/transmission de PIN ou OTP, calculs financiers exacts, français/anglais, aucune dépense sans accord et aucune migration/diffusion/déploiement sans accord explicite.

## 2. Audit statique du modèle NAXA existant

### 2.1 Faits observés dans le dépôt

Dépôt examiné : `audreymendomo23-netizen/NAXA`, branche `main`, commit indiqué ci-dessus.

- Arborescence Git : 2 524 chemins recensés, dont environ 911 sous `src/`, 325 migrations Supabase, 327 fichiers de tests SQL et 80 chemins sous `android/`.
- Web : Next.js App Router, React, TypeScript strict, Tailwind et Serwist pour le service worker/PWA.
- Versions relevées dans `package.json` : Next.js 16.4.6, React 18.3.1, TypeScript 5.6.2, Supabase JS 2.45.4 et Serwist 9.5.13.
- Android principal : Kotlin, Jetpack Compose, Gradle, Android Keystore, ML Kit OCR, FCM et accès natif aux API Android.
- Versions relevées dans `android/build.gradle.kts` et `android/app/build.gradle.kts` : AGP 8.7.3, Kotlin 2.2.21, JDK 17, compileSdk 35 et minSdk 26.
- Un compagnon Android de paiement distinct existe avec des variantes Standard, Professionnelle et Admin. Il utilise des services Android natifs (SMS_RECEIVED et NotificationListener) et des contrôles de consentement/rôle.
- Le code web comporte une base locale IndexedDB, une file d'opérations, du chiffrement AES-GCM et des règles de synchronisation.
- Le service worker Serwist ne précache pas toutes les pages personnalisées : les règles observées limitent le cache à des ressources publiques définies et à un écran hors ligne.
- Le dépôt contient déjà des migrations et tests liés à l'idempotence, au mode hors ligne, aux appareils et à l'isolation des rôles.

### 2.2 Limites et contradictions constatées

- NAXA n'est pas une base prête à dupliquer telle quelle : ses écrans, ses rôles et ses règles métier sont propres à la pharmacie et à la marketplace santé.
- Le README Android indique explicitement que plusieurs parcours métier et le mode hors ligne complet restent à implémenter. La présence d'un projet Android ne prouve donc pas que dix applications complètes existent.
- Deux projets Android NAXA ont des configurations de compilation différentes (application principale et compagnon de paiement). Il faudra normaliser et tester la chaîne de build avant de la généraliser.
- Le service worker web ne prouve pas un mode ERP complet hors connexion. Les workflows offline doivent être conçus et testés par domaine.
- Les règles SMS ne doivent pas être activées globalement dans les dix applications. Le cahier historique indique Kiosko comme cas obligatoire et les autres applications comme cas facultatifs, sous permissions et règles propres. Les rôles et consentements doivent être vérifiés application par application.
- Le modèle historique « sept applications Android » est dépassé. Campus237, NAXA Security et GrillaD doivent être intégrés au référentiel d'architecture sans forcer leurs besoins dans le modèle initial.

### 2.3 Ressources à réutiliser après audit, pas à recopier aveuglément

- Modèle de séparation des rôles, appareils, permissions et sessions.
- Patterns Android natifs : Keystore, services de premier plan, récepteur SMS et NotificationListener lorsque le cas métier l'autorise.
- Patterns web : Next.js, TypeScript, Supabase SSR, Serwist et IndexedDB.
- Mécanismes de file hors ligne, idempotence, horodatage serveur, gestion des conflits et tests SQL.
- Logique métier JavaScript du kit de construction et ses vecteurs de référence, après audit et comparaison avec les cahiers actuels.

Aucun schéma, code, rôle, permission ou migration NAXA ne doit être repris sans vérifier sa pertinence pour les dix métiers.

## 3. Comparaison des options Android

| Critère | Kotlin natif | Flutter | Capacitor |
|---|---|---|---|
| Accès aux API Android SMS, notifications, BLE, alarmes et services | Direct, API officielle | Via plugins/bridges natifs | Via plugins/bridges natifs |
| Travail fiable en arrière-plan | Meilleur contrôle des services Android et WorkManager | Dépend du plugin natif et de son maintien | Dépend du plugin natif ; limites du cycle WebView |
| Offline local | Room, DataStore, WorkManager | Base locale et plugins | IndexedDB/SQLite via plugins |
| UI Android | Jetpack Compose | Flutter | UI Web dans WebView |
| Réutilisation UI Web | Faible | Faible à moyenne | Forte |
| Risque pour les fonctions système sensibles | Le plus faible des trois | Moyen : pont natif obligatoire | Plus élevé : plugin natif obligatoire |
| Maintenance de dix APK indépendantes | Modules Gradle et bibliothèques Kotlin communes | Flavors/packages Flutter | Builds et plugins natifs à maintenir |

### Arbitrage Android proposé

**Choix recommandé : Android natif Kotlin + Jetpack Compose.**

Justification :
1. Les cahiers prévoient un usage hors connexion et des traitements locaux continus.
2. Kiosko doit lire des SMS de transaction ; d'autres applications peuvent avoir des besoins facultatifs de SMS, Bluetooth, géolocalisation, alarmes ou notifications.
3. Les API Android natives donnent le contrôle direct sur les permissions, les services, WorkManager, Room et Android Keystore.
4. NAXA possède déjà un début de socle Kotlin/Compose et un compagnon natif de paiement ; cela réduit la réinvention.
5. Flutter ou Capacitor ne suppriment pas le besoin de code natif pour les fonctions sensibles : ils ajoutent une couche de plugin/bridge à auditer et maintenir.
6. Kotlin permet de produire dix APK distinctes, avec applicationId, manifeste, icônes, permissions et versions propres, tout en mutualisant des bibliothèques communes.
7. L'interface Web ne doit pas être embarquée dans une WebView pour remplacer une application Android métier native.

Limite assumée : l'interface Android et l'interface Web ne partageront pas tous leurs composants visuels. Elles partageront les contrats métier, règles, formats, schémas, API, jeux de tests et conventions, plutôt que de chercher une fausse base UI universelle.

## 4. Architecture Web et PWA proposée

**Choix recommandé : Next.js + React + TypeScript + Serwist**, aligné sur le modèle Web existant NAXA, sous réserve de validation des versions et dépendances.

- Dix expériences Web/PWA indépendantes, chacune avec son nom, son icône, son manifeste, son `start_url`, son `scope`, son thème et ses routes.
- Packages TypeScript partagés pour les contrats, la validation, les formats, l'internationalisation et les règles métier réellement communes.
- Le cache PWA ne doit jamais stocker automatiquement des pages privées ou des données sensibles.
- Les workflows hors ligne doivent disposer de stockage local, file d'attente, chiffrement adapté, identifiants idempotents, reprise et résolution de conflits.
- Une PWA ne remplace pas les fonctions Android qui nécessitent un service système, une permission spéciale ou un fonctionnement garanti lorsque le navigateur est fermé.

## 5. Monorepo ou dépôts séparés

### Option A — Dix dépôts distincts
Avantages : cloisonnement et cycle de livraison indépendants.  
Limites : duplication des règles, corrections répétées, versions divergentes, coût élevé de synchronisation du socle et des tests.

### Option B — Monorepo
Avantages : un historique commun, contrats partagés, tests de compatibilité, correction mutualisée, gouvernance et documentation unifiées. Les dix applications restent compilables et distribuables séparément.  
Limites : outillage plus exigeant, nécessité de contrôler les dépendances entre modules et de ne pas transformer le socle commun en dépendance obligatoire pour tout.

### Arbitrage proposé

**Choix recommandé : monorepo GitHub `FAMILLE-NAXA`.**

Structure cible indicative :

```text
apps/
  android/
    kiosko/ bootik/ zipple/ naxa-services/ cotiz/
    loyable/ naxa-hotel/ campus237/ naxa-security/ grillad/
  web/
    kiosko/ bootik/ zipple/ naxa-services/ cotiz/
    loyable/ naxa-hotel/ campus237/ naxa-security/ grillad/
packages/
  android-core/
  web-core/
  domain-contracts/
  business-rules/
  localization/
  test-vectors/
  design-tokens/
supabase/
  migrations/
  functions/
  tests/
docs/
  architecture-360/
  apps/
  decisions/
  audits/
```

Cette structure est une cible proposée, pas une structure déjà construite. Chaque application doit pouvoir être compilée, testée, versionnée et distribuée sans embarquer les neuf autres.

## 6. Socle technique partagé proposé

| Domaine | Android | Web/PWA | Licence / coût indicatif |
|---|---|---|---|
| UI | Jetpack Compose | React / Next.js | Apache 2.0 côté AndroidX ; licences React/Next à vérifier à l'épinglage |
| Base locale | Room / SQLite | IndexedDB, éventuellement SQLite WASM selon besoin | AndroidX Apache 2.0 ; API navigateur |
| Synchronisation différée | WorkManager | file locale + reprise contrôlée | AndroidX Apache 2.0 ; code projet |
| Secrets locaux | Android Keystore | WebCrypto, clé liée à la session et au contexte local | API plateforme |
| Codes-barres/QR | ZXing ou ML Kit Barcode | ZXing Browser | ZXing Apache 2.0 ; ML Kit gratuit sous conditions Google |
| OCR | ML Kit embarqué sur l'appareil ou Tesseract | Tesseract.js | ML Kit sans frais d'usage annoncé mais SDK propriétaire ; Tesseract Apache 2.0 |
| PDF | PdfRenderer / PdfDocument Android | PDF.js pour lecture, pdf-lib pour génération | API plateforme ; PDF.js Apache 2.0 ; pdf-lib MIT |
| Voix | SpeechRecognizer système ; Vosk si vrai besoin hors ligne | Web Speech API si disponible | API plateforme ; Vosk Apache 2.0, modèles à vérifier séparément |
| Graphiques | Vico pour Compose | Recharts | Apache 2.0 ; MIT |
| Notifications | Notifications Android + FCM | Web Push + centre de notifications | FCM sans frais d'usage standard, sous conditions du service |
| Backend | Supabase Auth/Postgres/Storage/Edge Functions selon audit | Même backend via accès serveur sécurisé | Réutilisation du projet Supabase existant, coûts à surveiller |

**Précaution licences :** les bibliothèques ne seront pas ajoutées avant vérification de leur version, licence exacte, dépendances transitives, taille, compatibilité Android et fonctionnement hors connexion. Un SDK gratuit n'est pas nécessairement open source. Les modèles OCR/voix peuvent avoir une licence distincte de celle du moteur.

## 7. Conventions proposées

- Identifiants Android provisoires (à confirmer avant création des projets) :
  - Kiosko : `cm.naxa.famille.kiosko`
  - Bootik : `cm.naxa.famille.bootik`
  - Zipple : `cm.naxa.famille.zipple`
  - NAXA Services : `cm.naxa.famille.services`
  - CotiZ : `cm.naxa.famille.cotiz`
  - Loyable : `cm.naxa.famille.loyable`
  - NAXA Hotel : `cm.naxa.famille.hotel`
  - Campus237 : `cm.naxa.famille.campus237`
  - NAXA Security : `cm.naxa.famille.security`
  - GrillaD : `cm.naxa.famille.grillad`
- Identifiants Web/PWA indépendants, avec manifeste et périmètre d'installation par application.
- Nommage : identifiants techniques en anglais, libellés traduits, noms métier français conservés lorsque pertinents.
- Internationalisation : fichiers FR/EN, aucune chaîne utilisateur codée en dur.
- Design : jetons communs de base, thèmes et logos distincts par application.
- Erreurs : codes stables, message utilisateur traduit, détail technique journalisé sans secret.
- Journaux : horodatage serveur, identifiant de corrélation, acteur, application, appareil, résultat ; minimisation des données personnelles.
- Versions : version propre à chaque APK/PWA ; table centrale de disponibilité/minimum uniquement après audit du schéma existant.
- Argent : entiers en FCFA, calculs exacts au franc, aucune conversion flottante pour les montants.
- Synchronisation : opérations idempotentes, séquences appareil, ancrage horaire serveur, règles de conflits explicites par domaine.
- Permissions : minimales, demandées au moment du besoin, consentement explicite et contrôle serveur/RLS.
- SMS : aucun PIN/OTP lu, conservé, transmis ou affiché ; tout SMS qui en contient est rejeté. Lecture en arrière-plan limitée aux applications, rôles et cas métier expressément autorisés ; partage manuel comme solution de secours.

## 8. Questions restant ouvertes

1. **Validation de l'architecture :** confirmer Kotlin natif pour les dix APK, Next.js/React/Serwist pour les dix PWA, monorepo unique et backend Supabase NAXA partagé sous réserve d'audit.
2. Confirmer si les dix applications doivent partager un compte d'identité central tout en gardant des profils, permissions et données cloisonnés par application.
3. Fixer la version Android minimale et la liste des téléphones de référence après étude des utilisateurs cibles.
4. Confirmer si chaque application doit disposer d'un site/PWA et d'un domaine distincts ou si certains domaines peuvent partager une origine technique tout en gardant des PWA séparées.
5. Valider les identifiants Android proposés avant création des modules.
6. Décider quelles applications et quels rôles ont réellement besoin de lecture SMS, Bluetooth, GPS, caméra et notifications en arrière-plan.

## 9. Contrôles et état de cette étape

- Comparaison Kotlin / Flutter / Capacitor : réalisée au niveau architectural.
- Audit statique du dépôt NAXA : réalisé sur l'arborescence et les fichiers de configuration/fondation consultés ; ce n'est pas un audit exhaustif du code.
- Structure cible du monorepo : proposée, pas créée.
- Bibliothèques : shortlist et licences indicatives ; vérification finale avant ajout.
- Code applicatif : aucun.
- Dépendances installées : aucune.
- Migration SQL : aucune.
- Supabase Production modifié : non.
- Build/test/CI : non exécutés.
- Déploiement ou publication APK : aucun.
- **Statut : PARTIEL — proposition technique prête pour arbitrage, non validée.**

## 10. Fichier de passation

**FICHIER DE PASSATION — Famille NAXA — Prompt 0.1 — 14 novembre 2026**

1. Fait : prompt source retrouvé ; périmètre actualisé de 7 à 10 applications ; audit statique NAXA ; comparaison des options ; architecture recommandée rédigée.
2. Fichier créé : `docs/architecture-360/PROMPT_0_1_CADRAGE_TECHNIQUE.md`.
3. Tables, fonctions et écrans créés : aucun.
4. Décisions proposées : Kotlin natif + Jetpack Compose pour Android ; Next.js + React + TypeScript + Serwist pour Web/PWA ; monorepo unique ; Supabase partagé après audit.
5. Points ouverts : compte d'identité central, minimum Android, séparation des domaines/PWA, identifiants d'application et matrice des permissions.
6. Prochain prompt : 0.2 — Schéma de données commun, uniquement après validation du 0.1 et audit des ressources Supabase existantes.
7. Accord explicite requis : toute migration appliquée, modification Production, déploiement, publication APK ou dépense.

**Étape terminée. J'attends ton accord avant de passer à la suivante.**
