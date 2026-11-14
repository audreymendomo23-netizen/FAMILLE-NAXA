# PROMPT 0.1 — Cadrage technique et structure du projet

**État : IMPLÉMENTATION CONFORME AU CADRAGE ; VALIDATION CI FINALE EN COURS.**

## 1. Architecture produit

Dix produits, chacun avec deux réalisations indépendantes : application Android 100 % native Kotlin/Jetpack Compose et application Web responsive Next.js installable comme PWA. Aucun WebView-wrapper ni Capacitor ; seuls les contrats, validations, règles partagées, traductions et tests sont mutualisés.

Produits : Kiosko, Bootik, Zipple, NAXA Services, CotiZ, Loyable, NAXA Hotel, Campus237, NAXA Security et GrillaD.

## 2. Baseline Android verrouillée

| Élément | Version / règle |
|---|---|
| Kotlin / KGP | 2.4.21 |
| Android Gradle Plugin | 9.3.1 |
| Gradle Wrapper | 9.5.0 avec SHA-256 officiel |
| JDK | 17 |
| compileSdk / targetSdk / minSdk | 37 / 37 / 26 |
| Compose | BOM 2026.09.00 + Material 3 |
| Persistance | Room 2.8.5 ; DataStore |
| Tâches différées | WorkManager 2.12.0 |
| Sécurité | Android Keystore ; PIN local ; biométrie facultative |
| Réseau / backend | Ktor Client 3.0.3 ; supabase-kt BOM 3.5.0 isolé derrière adaptateur |
| Média / push | CameraX, ML Kit local, FCM selon besoin confirmé |
| Tests | JUnit, Compose UI instrumentés, builds debug et release |

Le Kotlin intégré d'AGP 9.3.1 est temporairement désactivé dans gradle.properties pour utiliser explicitement KGP 2.4.21 (android.builtInKotlin=false, android.newDsl=false). Cette transition est documentée et devra être migrée avant AGP 10.

Chaque app a son applicationId, son manifeste, ses ressources, sa file Room et ses tests. Les écrans et données métier restent indépendants.

## 3. Baseline Web/PWA verrouillée

| Élément | Version / règle |
|---|---|
| Framework | Next.js 16.4.6 |
| UI | React / React DOM 19.3.0 |
| Langage | TypeScript strict |
| PWA / service worker | Serwist 9.5.13 en configurator mode |
| Workspace | pnpm 12.21.0 et lockfile unique |
| Tests | Playwright 1.65.0 et axe-core/playwright 4.14.0 |

Dix PWA ont un nom, un manifeste, une icône, un scope et un service worker indépendants. Le pré-cache des pages pré-rendues est désactivé et le cache runtime est vide : aucune page privée, réponse métier ou donnée d'authentification n'est mise en cache par le socle.

La console d'administration historique Vite est conservée hors du workspace des dix produits ; elle n'est ni convertie ni comptée comme l'une des dix PWA.

## 4. Monorepo et automatisation

- Dépôt de référence : audreymendomo23-netizen/FAMILLE-NAXA, branche main uniquement.
- Dix projets Android Gradle indépendants et dix applications Next.js autonomes.
- Catalogue Gradle centralisé ; pnpm workspace et lockfile unique ; Gradle Wrapper 9.5.0 et somme SHA-256 officielle.
- Générateur unique : scripts/bootstrap-foundations.mjs.
- CI : tests des contrats, builds des dix PWA, tests E2E/accessibilité, builds Android debug/release, tests unitaires, tests Compose instrumentés sur émulateur.

## 5. Backend, identité et sécurité

Le backend Supabase NAXA reste partagé sous réserve de l'audit de compatibilité. Aucune identité, table, migration, rôle ou donnée pharmacie n'est dupliquée sans décision. Les autorisations Famille restent contextualisées par application, organisation et lieu.

Aucune clé service_role ou secret côté client. Ce prompt n'autorise aucune migration, modification Auth, déploiement ni publication APK. Aucun workflow de ce prompt n'effectue ces opérations.

## 6. Conventions

- Montants FCFA stockés en entiers ou NUMERIC exact, jamais FLOAT.
- Horodatages UTC (timestamptz) ; fuseau de présentation Africa/Douala par défaut.
- Ressources UI FR/EN, aucune chaîne utilisateur codée en dur dans les shells natifs.
- Identifiants techniques anglais ; journalisation sans PIN, OTP, secret ni SMS brut.
- Dépendances versionnées ; lockfiles ; build output ignoré par Git.

## 7. Preuves et statut

La preuve antérieure run 43557643046 avait compilé des squelettes Vite/React 18 avec Gradle 8.7 et AGP 8.6.1 ; elle prouvait l'existence des vingt squelettes mais pas la conformité au stack Prompt 0.1. Elle n'est donc pas retenue comme preuve de conformité finale.

Le présent changement remplace le générateur et le workflow. Les critères de sortie restent conditionnés au passage de la CI sur les versions fixées :

- dix builds Next.js + Serwist ;
- tests TypeScript, contrats, E2E et accessibilité ;
- dix builds Android debug et release ;
- dix suites de tests unitaires et dix suites Compose instrumentées ;
- wrapper Gradle, pnpm-lock.yaml et manifests persistés sur main.

**Statut à la date de ce commit : implémentation et configuration prêtes ; VERT technique non déclaré avant preuve CI complète.**
